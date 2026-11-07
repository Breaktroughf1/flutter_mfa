package com.breaktroughf1.flutter_mfa

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.security.KeyStore
import javax.crypto.SecretKey
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Real Android Keystore round trip on the emulator (FR-VLT-02 AC3; API 24 and 36 in CI). */
@RunWith(AndroidJUnit4::class)
class KeystoreVaultInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private lateinit var dir: File
    private lateinit var vault: FileVault

    @Before
    fun setUp() {
        dir = File(context.noBackupFilesDir, "flutter_mfa_test")
        vault = FileVault(dir, KeystoreCrypto(strongBoxAvailable = false))
        vault.wipe()
    }

    @After
    fun tearDown() {
        vault.wipe()
        dir.deleteRecursively()
    }

    @Test
    fun roundTripsThroughTheKeystore() {
        vault.write("acct_1", "12345678901234567890".toByteArray(), ProtectionLevelMessage.STANDARD)
        assertContentEquals("12345678901234567890".toByteArray(), vault.read("acct_1"))
        assertEquals(listOf("acct_1"), vault.keys())
    }

    @Test
    fun dataLivesInNoBackupFilesDir() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        val stored = dir.listFiles()!!.single()
        assertEquals(context.noBackupFilesDir.canonicalPath, stored.parentFile!!.parentFile!!.canonicalPath)
    }

    @Test
    fun theKeyIsNonExportable() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        val key = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            .getKey("flutter_mfa.master.v1", null) as SecretKey
        assertNull(key.encoded, "Keystore keys never expose their material")
    }

    @Test
    fun tamperingIsDetectedByGcm() {
        vault.write("a", byteArrayOf(1, 2, 3), ProtectionLevelMessage.STANDARD)
        val file = dir.listFiles()!!.single()
        val bytes = file.readBytes()
        bytes[bytes.size - 1] = (bytes[bytes.size - 1].toInt() xor 1).toByte()
        file.writeBytes(bytes)
        assertEquals(VaultErrorCode.CORRUPTED, assertFailsWith<VaultFailure> { vault.read("a") }.code)
    }

    @Test
    fun dataIsUnreadableAfterWipe() {
        vault.write("a", byteArrayOf(1), ProtectionLevelMessage.STANDARD)
        val copy = dir.listFiles()!!.single().readBytes()
        vault.wipe()
        dir.mkdirs()
        File(dir, "61.bin").writeBytes(copy) // restore the old ciphertext
        assertEquals(VaultErrorCode.CORRUPTED, assertFailsWith<VaultFailure> { vault.read("a") }.code)
    }

    @Test
    fun reportsHardwareBackingWithoutThrowing() {
        KeystoreCrypto(strongBoxAvailable = false).isHardwareBacked()
    }
}
