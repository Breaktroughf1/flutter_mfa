package com.breaktroughf1.flutter_mfa

import java.io.File
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * The protected byte map on Android (02_ARCHITECTURE §4.1, FR-VLT-02).
 *
 * Each entry is one file in [dir] (inside `noBackupFilesDir`, so it is excluded
 * from cloud and device-transfer backups) named by the hex of its UTF-8 key.
 * File format: `version(1) ‖ protection(1) ‖ body`, where the body is
 *
 * * `standard`: `nonce(12) ‖ ciphertext ‖ tag(16)` under the Keystore master key;
 * * `biometric` / `hardwareBound`: `keyId(8) ‖ wrappedKey(256) ‖ nonce(12) ‖
 *   ciphertext ‖ tag(16)`: AES-256-GCM under a random data key that is
 *   wrapped with the entry's own biometric-gated RSA key ([ProtectedKeys],
 *   ADR-0004), so reading needs a strong biometric and writing needs none.
 *
 * The AAD binds the header, the key name and (for protected entries) the key
 * id and wrapped key, so a file cannot be moved to another key or relabelled
 * with a different protection level. Writes are atomic (temp file + rename);
 * the key of a replaced protected entry is deleted only once the new file is in
 * place. No value is ever logged or interpreted.
 */
internal class FileVault(
    private val dir: File,
    private val crypto: VaultCrypto,
    private val protectedKeys: ProtectedKeys,
) {
    private val lock = Any()

    /** Stores [value] under [key] at [level], replacing any existing entry. */
    fun write(key: String, value: ByteArray, level: ProtectionLevelMessage) = synchronized(lock) {
        val target = fileFor(key)
        val previousId = protectedIdOf(target)
        val header = byteArrayOf(FORMAT_VERSION, level.raw.toByte())
        if (level == ProtectionLevelMessage.STANDARD) {
            val sealed = crypto.seal(value, aad(header, key))
            store(target, header, sealed.nonce, sealed.ciphertext)
        } else {
            val (id, publicKey) = protectedKeys.create(level == ProtectionLevelMessage.HARDWARE_BOUND)
            try {
                val dataKey = ByteArray(DATA_KEY_SIZE).also { random.nextBytes(it) }
                try {
                    val wrapped = cryptoCall { RsaEnvelope.wrap(publicKey, dataKey) }
                    val body = id + wrapped
                    val nonce = ByteArray(NONCE_SIZE).also { random.nextBytes(it) }
                    val ciphertext = gcm(Cipher.ENCRYPT_MODE, dataKey, nonce, aad(header, key) + body, value)
                    store(target, header, body + nonce, ciphertext)
                } finally {
                    dataKey.fill(0)
                }
            } catch (e: VaultFailure) {
                protectedKeys.delete(id)
                throw e
            }
        }
        if (previousId != null) protectedKeys.delete(previousId)
    }

    /**
     * The bytes under [key], or null if there is no entry. A protected entry
     * shows [prompt] and is decrypted only after a strong biometric.
     */
    suspend fun read(key: String, prompt: PromptMessage? = null): ByteArray? {
        val file = fileFor(key)
        val data = synchronized(lock) {
            if (!file.exists()) return null
            io { file.readBytes() }
        }
        val level = levelOf(data)
        val header = data.copyOfRange(0, HEADER_SIZE)
        if (level == ProtectionLevelMessage.STANDARD) {
            val nonce = data.copyOfRange(HEADER_SIZE, HEADER_SIZE + NONCE_SIZE)
            val ciphertext = data.copyOfRange(HEADER_SIZE + NONCE_SIZE, data.size)
            return crypto.open(Sealed(nonce, ciphertext), aad(header, key))
        }
        if (data.size < PROTECTED_MIN_SIZE) throw VaultFailure(VaultErrorCode.CORRUPTED)
        val bodyEnd = HEADER_SIZE + ProtectedKeys.ID_SIZE + RsaEnvelope.WRAPPED_SIZE
        val id = data.copyOfRange(HEADER_SIZE, HEADER_SIZE + ProtectedKeys.ID_SIZE)
        val wrapped = data.copyOfRange(HEADER_SIZE + ProtectedKeys.ID_SIZE, bodyEnd)
        val nonce = data.copyOfRange(bodyEnd, bodyEnd + NONCE_SIZE)
        val ciphertext = data.copyOfRange(bodyEnd + NONCE_SIZE, data.size)
        val dataKey = protectedKeys.unwrap(id, wrapped, prompt)
        try {
            if (dataKey.size != DATA_KEY_SIZE) throw VaultFailure(VaultErrorCode.CORRUPTED)
            return gcm(Cipher.DECRYPT_MODE, dataKey, nonce, aad(header, key) + id + wrapped, ciphertext)
        } finally {
            dataKey.fill(0)
        }
    }

    /** Removes [key] (and the biometric key of a protected entry); absent keys are ignored. */
    fun delete(key: String) = synchronized(lock) {
        val file = fileFor(key)
        val id = protectedIdOf(file)
        io { if (file.exists() && !file.delete()) throw IOException() }
        if (id != null) protectedKeys.delete(id)
    }

    /** All keys with an entry. */
    fun keys(): List<String> = synchronized(lock) {
        val names = io { dir.list()?.toList() ?: emptyList() }
        names.mapNotNull { name ->
            if (!name.endsWith(FILE_SUFFIX)) return@mapNotNull null
            decodeKey(name.removeSuffix(FILE_SUFFIX))
        }.sorted()
    }

    /** Removes every entry and destroys every key. */
    fun wipe() = synchronized(lock) {
        io { dir.listFiles()?.forEach { if (!it.delete()) throw IOException() } }
        crypto.destroy()
        protectedKeys.deleteAll()
    }

    private fun store(target: File, header: ByteArray, prefix: ByteArray, ciphertext: ByteArray) {
        val temp = File(dir, target.name + TEMP_SUFFIX)
        io {
            ensureDir()
            temp.outputStream().use { out ->
                out.write(header)
                out.write(prefix)
                out.write(ciphertext)
                out.fd.sync()
            }
            if (!temp.renameTo(target)) {
                temp.delete()
                throw IOException()
            }
        }
    }

    /** The protection level of a stored file; anything malformed is corrupted. */
    private fun levelOf(data: ByteArray): ProtectionLevelMessage {
        if (data.size < HEADER_SIZE + NONCE_SIZE + TAG_SIZE || data[0] != FORMAT_VERSION) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        }
        return ProtectionLevelMessage.ofRaw(data[1].toInt())
            ?: throw VaultFailure(VaultErrorCode.CORRUPTED)
    }

    /** The biometric key id of an existing protected entry in [file], else null. */
    private fun protectedIdOf(file: File): ByteArray? {
        if (!file.exists()) return null
        val data = try {
            file.readBytes()
        } catch (e: IOException) {
            return null
        }
        if (data.size < PROTECTED_MIN_SIZE || data[0] != FORMAT_VERSION) return null
        val level = ProtectionLevelMessage.ofRaw(data[1].toInt()) ?: return null
        if (level == ProtectionLevelMessage.STANDARD) return null
        return data.copyOfRange(HEADER_SIZE, HEADER_SIZE + ProtectedKeys.ID_SIZE)
    }

    private fun gcm(mode: Int, key: ByteArray, nonce: ByteArray, aad: ByteArray, input: ByteArray): ByteArray =
        cryptoCall {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(mode, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_SIZE * 8, nonce))
            cipher.updateAAD(aad)
            cipher.doFinal(input)
        }

    private inline fun <T> cryptoCall(block: () -> T): T =
        try {
            block()
        } catch (e: AEADBadTagException) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        } catch (e: GeneralSecurityException) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        }

    private fun fileFor(key: String): File {
        val bytes = key.toByteArray(Charsets.UTF_8)
        if (bytes.isEmpty() || bytes.size > MAX_KEY_BYTES) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        }
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
        const val DATA_KEY_SIZE = 32
        const val PROTECTED_MIN_SIZE =
            HEADER_SIZE + ProtectedKeys.ID_SIZE + RsaEnvelope.WRAPPED_SIZE + NONCE_SIZE + TAG_SIZE
        private val random = SecureRandom()
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
