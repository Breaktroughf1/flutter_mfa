package com.breaktroughf1.flutter_mfa

import java.io.File
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlin.io.path.createTempDirectory
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Software AES-256-GCM standing in for the Keystore on the JVM (same contract). */
private class SoftwareCrypto : VaultCrypto {
    private var key: SecretKey = newKey()
    var destroyed = false

    private fun newKey(): SecretKey = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    override fun seal(plaintext: ByteArray, aad: ByteArray): Sealed {
        val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(128, nonce))
        cipher.updateAAD(aad)
        return Sealed(nonce, cipher.doFinal(plaintext))
    }

    override fun open(sealed: Sealed, aad: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, sealed.nonce))
        cipher.updateAAD(aad)
        return try {
            cipher.doFinal(sealed.ciphertext)
        } catch (e: AEADBadTagException) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        }
    }

    override fun isHardwareBacked() = false

    override fun destroy() {
        destroyed = true
        key = newKey()
    }
}

internal class FileVaultTest {
    private lateinit var dir: File
    private lateinit var crypto: SoftwareCrypto
    private lateinit var vault: FileVault

    @BeforeTest
    fun setUp() {
        dir = File(createTempDirectory("fmfa").toFile(), "flutter_mfa")
        crypto = SoftwareCrypto()
        vault = FileVault(dir, crypto)
    }

    @AfterTest
    fun tearDown() {
        dir.parentFile.deleteRecursively()
    }

    private fun failure(block: () -> Unit): VaultErrorCode = assertFailsWith<VaultFailure> { block() }.code

    private fun fileOf(key: String) = File(dir, key.toByteArray().joinToString("") { "%02x".format(it) } + ".bin")

    @Test
    fun roundTripsAndOverwrites() {
        vault.write("acct_1", byteArrayOf(1, 2, 3), ProtectionLevelMessage.STANDARD)
        assertContentEquals(byteArrayOf(1, 2, 3), vault.read("acct_1"))
        vault.write("acct_1", byteArrayOf(9), ProtectionLevelMessage.STANDARD)
        assertContentEquals(byteArrayOf(9), vault.read("acct_1"))
        vault.write("empty", ByteArray(0), ProtectionLevelMessage.STANDARD)
        assertContentEquals(ByteArray(0), vault.read("empty"))
    }

    @Test
    fun missingKeysReadAsNullAndDeleteIsIdempotent() {
        assertNull(vault.read("nope"))
        vault.delete("nope")
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        vault.delete("a")
        assertNull(vault.read("a"))
    }

    @Test
    fun filesHoldOnlyCiphertextWithTheVersionedHeader() {
        val secret = "12345678901234567890".toByteArray()
        vault.write("acct_x", secret, ProtectionLevelMessage.STANDARD)
        val bytes = fileOf("acct_x").readBytes()
        assertEquals(1, bytes[0].toInt(), "format version")
        assertEquals(0, bytes[1].toInt(), "protection standard")
        assertEquals(2 + 12 + secret.size + 16, bytes.size)
        assertFalse(String(bytes, Charsets.ISO_8859_1).contains("1234567890"), "no plaintext on disk")
        assertFalse(File(dir, fileOf("acct_x").name + ".tmp").exists(), "temp file renamed away")
    }

    @Test
    fun keysListsOnlyEntriesWeWroteInOrder() {
        vault.write("b", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        vault.write("__index_v1__", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        vault.write("acct_é", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        File(dir, "foreign.txt").writeText("x")
        File(dir, "zz.bin").writeText("x") // not valid hex
        File(dir, "6162.bin.tmp").writeText("x") // interrupted write
        assertEquals(listOf("__index_v1__", "acct_é", "b"), vault.keys())
    }

    @Test
    fun keysOfMissingDirectoryIsEmpty() {
        assertEquals(emptyList(), vault.keys())
    }

    @Test
    fun wipeRemovesEveryFileAndDestroysTheKey() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        vault.write("b", byteArrayOf(2), ProtectionLevelMessage.STANDARD)
        vault.wipe()
        assertEquals(emptyList(), vault.keys())
        assertTrue(crypto.destroyed)
    }

    @Test
    fun protectedLevelsAreRefusedNotDowngraded() {
        for (level in listOf(ProtectionLevelMessage.BIOMETRIC, ProtectionLevelMessage.HARDWARE_BOUND)) {
            assertEquals(VaultErrorCode.UNSUPPORTED_ON_PLATFORM, failure { vault.write("a", byteArrayOf(1), level) })
        }
        assertEquals(emptyList(), vault.keys())
    }

    @Test
    fun tamperedCiphertextIsCorrupted() {
        vault.write("a", byteArrayOf(1, 2, 3), ProtectionLevelMessage.STANDARD)
        val file = fileOf("a")
        val bytes = file.readBytes()
        bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 1).toByte()
        file.writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("a") })
    }

    @Test
    fun aFileMovedToAnotherKeyIsCorrupted() {
        vault.write("acct_victim", byteArrayOf(7), ProtectionLevelMessage.STANDARD)
        vault.write("acct_other", byteArrayOf(8), ProtectionLevelMessage.STANDARD)
        fileOf("acct_victim").copyTo(fileOf("acct_other"), overwrite = true)
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("acct_other") })
    }

    @Test
    fun aRelabelledProtectionLevelIsCorrupted() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        val bytes = fileOf("a").readBytes()
        bytes[1] = 1 // claim "biometric"
        fileOf("a").writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("a") })
        bytes[1] = 9 // unknown level
        fileOf("a").writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("a") })
    }

    @Test
    fun truncatedOrUnknownVersionFilesAreCorrupted() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        val bytes = fileOf("a").readBytes()
        fileOf("a").writeBytes(bytes.copyOf(20))
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("a") })
        bytes[0] = 2
        fileOf("a").writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("a") })
    }

    @Test
    fun anUnusableStorageDirectoryIsStorageUnavailable() {
        dir.parentFile.mkdirs()
        dir.writeText("not a directory")
        assertEquals(
            VaultErrorCode.STORAGE_UNAVAILABLE,
            failure { vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD) },
        )
    }

    @Test
    fun invalidKeyLengthsAreRejected() {
        assertFailsWith<IllegalArgumentException> { vault.read("") }
        assertFailsWith<IllegalArgumentException> { vault.read("x".repeat(121)) }
        vault.write("x".repeat(120), byteArrayOf(1), ProtectionLevelMessage.STANDARD)
    }

    @Test
    fun decodeKeyRejectsAnythingWeDidNotWrite() {
        assertEquals("ab", FileVault.decodeKey("6162"))
        assertNull(FileVault.decodeKey(""))
        assertNull(FileVault.decodeKey("616"))
        assertNull(FileVault.decodeKey("6G62"))
        assertNull(FileVault.decodeKey("ABCD"))
    }
}
