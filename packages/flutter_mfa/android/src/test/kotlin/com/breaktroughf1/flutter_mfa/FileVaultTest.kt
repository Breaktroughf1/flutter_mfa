package com.breaktroughf1.flutter_mfa

import java.io.File
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.PublicKey
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
import kotlinx.coroutines.runBlocking

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

/**
 * Software RSA standing in for the biometric-gated Keystore keys: the same
 * OAEP parameters, so [RsaEnvelope.wrap] is checked against a real decrypt.
 */
private class SoftwareProtectedKeys : ProtectedKeys {
    val pairs = mutableMapOf<String, KeyPair>()
    val created = mutableListOf<Pair<String, Boolean>>()
    val prompts = mutableListOf<PromptMessage?>()
    var available = true
    var nextFailure: VaultErrorCode? = null
    var deletedAll = false

    private fun hex(id: ByteArray) = id.joinToString("") { "%02x".format(it) }

    override fun available() = available

    override fun create(hardwareBound: Boolean): Pair<ByteArray, PublicKey> {
        if (!available) throw VaultFailure(VaultErrorCode.BIOMETRICS_NOT_ENROLLED)
        val id = ByteArray(ProtectedKeys.ID_SIZE).also { SecureRandom().nextBytes(it) }
        val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(RsaEnvelope.KEY_BITS) }.generateKeyPair()
        pairs[hex(id)] = pair
        created += hex(id) to hardwareBound
        return id to pair.public
    }

    override suspend fun unwrap(id: ByteArray, wrapped: ByteArray, prompt: PromptMessage?): ByteArray {
        prompts += prompt
        nextFailure?.let { nextFailure = null; throw VaultFailure(it) }
        val pair = pairs[hex(id)] ?: throw VaultFailure(VaultErrorCode.KEY_INVALIDATED)
        val cipher = Cipher.getInstance(RsaEnvelope.TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, pair.private, RsaEnvelope.OAEP)
        return try {
            cipher.doFinal(wrapped)
        } catch (e: javax.crypto.BadPaddingException) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        }
    }

    override fun delete(id: ByteArray) {
        pairs.remove(hex(id))
    }

    override fun deleteAll() {
        pairs.clear()
        deletedAll = true
    }
}

internal class FileVaultTest {
    private lateinit var dir: File
    private lateinit var crypto: SoftwareCrypto
    private lateinit var keys: SoftwareProtectedKeys
    private lateinit var vault: FileVault
    private val prompt = PromptMessage(title = "Unlock", cancelLabel = "Cancel")

    @BeforeTest
    fun setUp() {
        dir = File(createTempDirectory("fmfa").toFile(), "flutter_mfa")
        crypto = SoftwareCrypto()
        keys = SoftwareProtectedKeys()
        vault = FileVault(dir, crypto, keys)
    }

    @AfterTest
    fun tearDown() {
        dir.parentFile.deleteRecursively()
    }

    private fun failure(block: suspend () -> Unit): VaultErrorCode =
        assertFailsWith<VaultFailure> { runBlocking { block() } }.code

    private fun read(key: String, p: PromptMessage? = null) = runBlocking { vault.read(key, p) }

    private fun fileOf(key: String) = File(dir, key.toByteArray().joinToString("") { "%02x".format(it) } + ".bin")

    @Test
    fun roundTripsAndOverwrites() {
        vault.write("acct_1", byteArrayOf(1, 2, 3), ProtectionLevelMessage.STANDARD)
        assertContentEquals(byteArrayOf(1, 2, 3), read("acct_1"))
        vault.write("acct_1", byteArrayOf(9), ProtectionLevelMessage.STANDARD)
        assertContentEquals(byteArrayOf(9), read("acct_1"))
        vault.write("empty", ByteArray(0), ProtectionLevelMessage.STANDARD)
        assertContentEquals(ByteArray(0), read("empty"))
    }

    @Test
    fun missingKeysReadAsNullAndDeleteIsIdempotent() {
        assertNull(read("nope"))
        vault.delete("nope")
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        vault.delete("a")
        assertNull(read("a"))
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
        assertTrue(keys.deletedAll)
    }

    @Test
    fun protectedEntriesRoundTripAndAskForABiometricOnlyWhenRead() {
        val secret = "12345678901234567890".toByteArray()
        for ((name, level) in listOf(
            "bio" to ProtectionLevelMessage.BIOMETRIC,
            "hw" to ProtectionLevelMessage.HARDWARE_BOUND,
        )) {
            val promptsBefore = keys.prompts.size
            vault.write(name, secret, level)
            assertEquals(promptsBefore, keys.prompts.size, "writing never prompts")
            val bytes = fileOf(name).readBytes()
            assertEquals(level.raw, bytes[1].toInt())
            assertEquals(2 + 8 + 256 + 12 + secret.size + 16, bytes.size)
            assertFalse(String(bytes, Charsets.ISO_8859_1).contains("1234567890"), "no plaintext on disk")
            assertContentEquals(secret, read(name, prompt))
        }
        assertEquals(listOf(false, true), keys.created.map { it.second }, "hardwareBound asks for StrongBox")
        assertEquals(listOf<PromptMessage?>(prompt, prompt), keys.prompts)
    }

    @Test
    fun aCancelledOrInvalidatedBiometricIsReportedAndNothingIsReturned() {
        vault.write("bio", byteArrayOf(1), ProtectionLevelMessage.BIOMETRIC)
        for (code in listOf(VaultErrorCode.USER_CANCELLED, VaultErrorCode.KEY_INVALIDATED)) {
            keys.nextFailure = code
            assertEquals(code, failure { vault.read("bio", prompt) })
        }
        keys.pairs.clear() // a new fingerprint enrolment deleted the key
        assertEquals(VaultErrorCode.KEY_INVALIDATED, failure { vault.read("bio", prompt) })
    }

    @Test
    fun replacingOrDeletingAProtectedEntryDeletesItsKeyAfterTheNewFileIsWritten() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.BIOMETRIC)
        vault.write("a", byteArrayOf(2), ProtectionLevelMessage.BIOMETRIC)
        assertEquals(1, keys.pairs.size, "the first key is gone")
        assertContentEquals(byteArrayOf(2), read("a", prompt))
        vault.write("a", byteArrayOf(3), ProtectionLevelMessage.STANDARD)
        assertEquals(0, keys.pairs.size)
        vault.write("b", byteArrayOf(4), ProtectionLevelMessage.HARDWARE_BOUND)
        vault.delete("b")
        assertEquals(0, keys.pairs.size)
        assertNull(read("b"))
    }

    @Test
    fun aFailedProtectedWriteKeepsTheOldEntryAndDeletesTheNewKey() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.BIOMETRIC)
        val oldFile = fileOf("a").readBytes()
        File(dir, fileOf("a").name + ".tmp").mkdirs() // the temp file cannot be created
        assertEquals(
            VaultErrorCode.STORAGE_UNAVAILABLE,
            failure { vault.write("a", byteArrayOf(2), ProtectionLevelMessage.BIOMETRIC) },
        )
        assertEquals(1, keys.pairs.size, "only the old entry's key remains")
        assertContentEquals(oldFile, fileOf("a").readBytes())
        assertContentEquals(byteArrayOf(1), read("a", prompt))
    }

    @Test
    fun protectedLevelsAreRefusedNotDowngradedWhenUnavailable() {
        keys.available = false
        assertEquals(
            VaultErrorCode.BIOMETRICS_NOT_ENROLLED,
            failure { vault.write("a", byteArrayOf(1), ProtectionLevelMessage.BIOMETRIC) },
        )
        val unsupported = FileVault(dir, crypto, UnsupportedProtectedKeys)
        for (level in listOf(ProtectionLevelMessage.BIOMETRIC, ProtectionLevelMessage.HARDWARE_BOUND)) {
            assertEquals(VaultErrorCode.UNSUPPORTED_ON_PLATFORM, failure { unsupported.write("a", byteArrayOf(1), level) })
        }
        assertEquals(emptyList(), vault.keys())
    }

    @Test
    fun tamperedProtectedEntriesAreCorrupted() {
        val secret = byteArrayOf(1, 2, 3)
        // [offset into the file, what it changes]
        for (offset in listOf(2 + 8 + 10, 2 + 8 + 256 + 3, -1)) {
            vault.write("a", secret, ProtectionLevelMessage.BIOMETRIC)
            val bytes = fileOf("a").readBytes()
            val at = if (offset < 0) bytes.size - 1 else offset
            bytes[at] = (bytes[at].toInt() xor 1).toByte()
            fileOf("a").writeBytes(bytes)
            assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("a", prompt) }, "offset $offset")
        }
        vault.write("victim", secret, ProtectionLevelMessage.BIOMETRIC)
        vault.write("other", secret, ProtectionLevelMessage.BIOMETRIC)
        fileOf("victim").copyTo(fileOf("other"), overwrite = true)
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("other", prompt) })
        val relabelled = fileOf("victim").readBytes().also { it[1] = 2 }
        fileOf("victim").writeBytes(relabelled)
        assertEquals(VaultErrorCode.CORRUPTED, failure { vault.read("victim", prompt) })
    }

    @Test
    fun tamperedCiphertextIsCorrupted() {
        vault.write("a", byteArrayOf(1, 2, 3), ProtectionLevelMessage.STANDARD)
        val file = fileOf("a")
        val bytes = file.readBytes()
        bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 1).toByte()
        file.writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { read("a") })
    }

    @Test
    fun aFileMovedToAnotherKeyIsCorrupted() {
        vault.write("acct_victim", byteArrayOf(7), ProtectionLevelMessage.STANDARD)
        vault.write("acct_other", byteArrayOf(8), ProtectionLevelMessage.STANDARD)
        fileOf("acct_victim").copyTo(fileOf("acct_other"), overwrite = true)
        assertEquals(VaultErrorCode.CORRUPTED, failure { read("acct_other") })
    }

    @Test
    fun aRelabelledProtectionLevelIsCorrupted() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        val bytes = fileOf("a").readBytes()
        bytes[1] = 1 // claim "biometric"
        fileOf("a").writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { read("a") })
        bytes[1] = 9 // unknown level
        fileOf("a").writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { read("a") })
    }

    @Test
    fun truncatedOrUnknownVersionFilesAreCorrupted() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        val bytes = fileOf("a").readBytes()
        fileOf("a").writeBytes(bytes.copyOf(20))
        assertEquals(VaultErrorCode.CORRUPTED, failure { read("a") })
        bytes[0] = 2
        fileOf("a").writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, failure { read("a") })
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
        assertFailsWith<IllegalArgumentException> { read("") }
        assertFailsWith<IllegalArgumentException> { read("x".repeat(121)) }
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
