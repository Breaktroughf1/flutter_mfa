package com.breaktroughf1.flutter_mfa

import java.io.File
import java.io.IOException

/**
 * The protected byte map on Android (02_ARCHITECTURE §4.1, FR-VLT-02).
 *
 * Each entry is one file in [dir] (inside `noBackupFilesDir`, so it is excluded
 * from cloud and device-transfer backups) named by the hex of its UTF-8 key.
 * File format: `version(1) ‖ protection(1) ‖ nonce(12) ‖ ciphertext ‖ tag(16)`.
 * The AAD binds the header and the key name, so a file cannot be moved to
 * another key or relabelled with a different protection level. Writes are
 * atomic (temp file + rename). No value is ever logged or interpreted.
 */
internal class FileVault(private val dir: File, private val crypto: VaultCrypto) {

    /** Stores [value] under [key] at [level], replacing any existing entry. */
    fun write(key: String, value: ByteArray, level: ProtectionLevelMessage) {
        if (level != ProtectionLevelMessage.STANDARD) {
            // Biometric and hardware-bound levels arrive in M3-05; never downgrade.
            throw VaultFailure(VaultErrorCode.UNSUPPORTED_ON_PLATFORM)
        }
        val header = byteArrayOf(FORMAT_VERSION, level.raw.toByte())
        val sealed = crypto.seal(value, aad(header, key))
        val target = fileFor(key)
        val temp = File(dir, target.name + TEMP_SUFFIX)
        io {
            ensureDir()
            temp.outputStream().use { out ->
                out.write(header)
                out.write(sealed.nonce)
                out.write(sealed.ciphertext)
                out.fd.sync()
            }
            if (!temp.renameTo(target)) {
                temp.delete()
                throw IOException()
            }
        }
    }

    /** The bytes under [key], or null if there is no entry. */
    fun read(key: String): ByteArray? {
        val file = fileFor(key)
        if (!file.exists()) return null
        val data = io { file.readBytes() }
        if (data.size < HEADER_SIZE + NONCE_SIZE + TAG_SIZE || data[0] != FORMAT_VERSION) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        }
        val level = ProtectionLevelMessage.ofRaw(data[1].toInt())
            ?: throw VaultFailure(VaultErrorCode.CORRUPTED)
        if (level != ProtectionLevelMessage.STANDARD) throw VaultFailure(VaultErrorCode.CORRUPTED)
        val header = data.copyOfRange(0, HEADER_SIZE)
        val nonce = data.copyOfRange(HEADER_SIZE, HEADER_SIZE + NONCE_SIZE)
        val ciphertext = data.copyOfRange(HEADER_SIZE + NONCE_SIZE, data.size)
        return crypto.open(Sealed(nonce, ciphertext), aad(header, key))
    }

    /** Removes [key]; absent keys are ignored. */
    fun delete(key: String) {
        val file = fileFor(key)
        io { if (file.exists() && !file.delete()) throw IOException() }
    }

    /** All keys with an entry. */
    fun keys(): List<String> {
        val names = io { dir.list()?.toList() ?: emptyList() }
        return names.mapNotNull { name ->
            if (!name.endsWith(FILE_SUFFIX)) return@mapNotNull null
            decodeKey(name.removeSuffix(FILE_SUFFIX))
        }.sorted()
    }

    /** Removes every entry and destroys the key. */
    fun wipe() {
        io { dir.listFiles()?.forEach { if (!it.delete()) throw IOException() } }
        crypto.destroy()
    }

    private fun fileFor(key: String): File {
        val bytes = key.toByteArray(Charsets.UTF_8)
        require(bytes.isNotEmpty() && bytes.size <= MAX_KEY_BYTES) { "invalid key length" }
        return File(dir, bytes.joinToString("") { "%02x".format(it) } + FILE_SUFFIX)
    }

    private fun ensureDir() {
        if (!dir.isDirectory && !dir.mkdirs()) throw IOException()
    }

    private fun aad(header: ByteArray, key: String): ByteArray =
        AAD_PREFIX + header + key.toByteArray(Charsets.UTF_8)

    private inline fun <T> io(block: () -> T): T =
        try {
            block()
        } catch (e: IOException) {
            throw VaultFailure(VaultErrorCode.STORAGE_UNAVAILABLE)
        } catch (e: SecurityException) {
            throw VaultFailure(VaultErrorCode.STORAGE_UNAVAILABLE)
        }

    internal companion object {
        const val FORMAT_VERSION: Byte = 1
        const val HEADER_SIZE = 2
        const val NONCE_SIZE = 12
        const val TAG_SIZE = 16
        const val MAX_KEY_BYTES = 120
        const val FILE_SUFFIX = ".bin"
        const val TEMP_SUFFIX = ".tmp"
        val AAD_PREFIX = "flutter_mfa.v1:".toByteArray(Charsets.UTF_8)

        /** Hex file stem back to the key, or null for anything we did not write. */
        fun decodeKey(stem: String): String? {
            if (stem.isEmpty() || stem.length % 2 != 0 || stem.length / 2 > MAX_KEY_BYTES) return null
            if (stem.any { it !in '0'..'9' && it !in 'a'..'f' }) return null
            val bytes = ByteArray(stem.length / 2) { i -> stem.substring(2 * i, 2 * i + 2).toInt(16).toByte() }
            return String(bytes, Charsets.UTF_8)
        }
    }
}
