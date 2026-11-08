package com.breaktroughf1.flutter_mfa

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import javax.crypto.Cipher
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Real Android Keystore checks for biometric entries (M3-05) that an emulator
 * without fingerprints can run. The biometric prompt itself is covered by the
 * manual device pass (ADR-0004).
 */
@RunWith(AndroidJUnit4::class)
class ProtectedKeysInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun aWrappedDataKeyOpensWithAKeystoreRsaOaepKey() {
        // Same parameters as KeystoreProtectedKeys except user authentication,
        // so the OAEP digest choices are checked against this device's Keystore.
        val alias = KeystoreProtectedKeys.ALIAS_PREFIX + "test"
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
        generator.initialize(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(RsaEnvelope.KEY_BITS)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
                .build(),
        )
        val pair = generator.generateKeyPair()
        try {
            val dataKey = ByteArray(32) { it.toByte() }
            val wrapped = RsaEnvelope.wrap(pair.public, dataKey)
            assertEquals(RsaEnvelope.WRAPPED_SIZE, wrapped.size)
            val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val cipher = Cipher.getInstance(RsaEnvelope.TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, store.getKey(alias, null) as PrivateKey, RsaEnvelope.OAEP)
            assertContentEquals(dataKey, cipher.doFinal(wrapped))
        } finally {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(alias)
        }
    }

    @Test
    fun withoutEnrolledBiometricsOrStrongBoxProtectedKeysFailClosed() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            assertFailsWith<VaultFailure> { UnsupportedProtectedKeys.create(hardwareBound = false) }
            return
        }
        val noStrongBox = KeystoreProtectedKeys(context, strongBoxAvailable = false) { null }
        assertEquals(
            VaultErrorCode.STRONG_BOX_UNAVAILABLE,
            assertFailsWith<VaultFailure> { noStrongBox.create(hardwareBound = true) }.code,
        )
        val keys = KeystoreProtectedKeys(context, FlutterMfaPlugin.hasStrongBox(context)) { null }
        assertFalse(keys.available())
        val failure = assertFailsWith<VaultFailure> { keys.create(hardwareBound = false) }
        assertEquals(VaultErrorCode.BIOMETRICS_NOT_ENROLLED, failure.code)
        keys.deleteAll()
    }
}
