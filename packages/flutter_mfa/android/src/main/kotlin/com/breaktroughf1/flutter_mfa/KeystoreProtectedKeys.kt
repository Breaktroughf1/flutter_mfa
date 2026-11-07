package com.breaktroughf1.flutter_mfa

import android.app.Activity
import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.annotation.TargetApi
import java.security.GeneralSecurityException
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.SecureRandom
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.IllegalBlockSizeException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/**
 * [ProtectedKeys] in Android Keystore with the framework BiometricPrompt
 * (API 30+): RSA-2048 keys that require a strong (Class 3) biometric for every
 * use (`setUserAuthenticationParameters(0, BIOMETRIC_STRONG)`) and are
 * invalidated when a biometric is enrolled. The private key is used only
 * through a `CryptoObject`, so there is no boolean to hook (S5). Works with any
 * host Activity. Nothing is logged.
 */
@TargetApi(Build.VERSION_CODES.R)
internal class KeystoreProtectedKeys(
    private val context: Context,
    private val strongBoxAvailable: Boolean,
    private val activity: () -> Activity?,
) : ProtectedKeys {

    override fun available(): Boolean = enrollment() == BiometricManager.BIOMETRIC_SUCCESS

    override fun create(hardwareBound: Boolean): Pair<ByteArray, PublicKey> = guard {
        when (enrollment()) {
            BiometricManager.BIOMETRIC_SUCCESS -> Unit
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED ->
                throw VaultFailure(VaultErrorCode.BIOMETRICS_NOT_ENROLLED)
            else -> throw VaultFailure(VaultErrorCode.BIOMETRICS_UNAVAILABLE)
        }
        val id = ByteArray(ProtectedKeys.ID_SIZE).also { SecureRandom().nextBytes(it) }
        val alias = alias(id)
        val pair = generate(alias, strongBox = hardwareBound && strongBoxAvailable)
        if (!insideSecureHardware(pair.private)) {
            keyStore().deleteEntry(alias)
            throw VaultFailure(VaultErrorCode.STRONG_BOX_UNAVAILABLE)
        }
        id to pair.public
    }

    override suspend fun unwrap(id: ByteArray, wrapped: ByteArray, prompt: PromptMessage?): ByteArray {
        val shown = prompt ?: throw VaultFailure(VaultErrorCode.BIOMETRICS_UNAVAILABLE)
        val cipher = guard {
            val key = keyStore().getKey(alias(id), null) as PrivateKey?
                ?: throw VaultFailure(VaultErrorCode.KEY_INVALIDATED)
            Cipher.getInstance(RsaEnvelope.TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, key, RsaEnvelope.OAEP)
            }
        }
        val unlocked = authenticate(cipher, shown)
        return guard { unlocked.doFinal(wrapped) }
    }

    override fun delete(id: ByteArray) {
        guard { keyStore().deleteEntry(alias(id)) }
    }

    override fun deleteAll() {
        guard {
            val store = keyStore()
            for (alias in store.aliases().toList()) {
                if (alias.startsWith(ALIAS_PREFIX)) store.deleteEntry(alias)
            }
        }
    }

    private fun enrollment(): Int {
        val manager = context.getSystemService(BiometricManager::class.java)
            ?: return BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE
        return try {
            manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        } catch (e: SecurityException) {
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE
        }
    }

    private fun generate(alias: String, strongBox: Boolean): KeyPair {
        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(RsaEnvelope.KEY_BITS)
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            .setInvalidatedByBiometricEnrollment(true)
        if (strongBox) builder.setIsStrongBoxBacked(true)
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, KEYSTORE)
        return try {
            generator.initialize(builder.build())
            generator.generateKeyPair()
        } catch (e: StrongBoxUnavailableException) {
            generate(alias, strongBox = false)
        }
    }

    private fun insideSecureHardware(key: PrivateKey): Boolean {
        val info = KeyFactory.getInstance(key.algorithm, KEYSTORE)
            .getKeySpec(key, KeyInfo::class.java)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            info.securityLevel != KeyProperties.SECURITY_LEVEL_SOFTWARE
        } else {
            @Suppress("DEPRECATION")
            info.isInsideSecureHardware
        }
    }

    private suspend fun authenticate(cipher: Cipher, prompt: PromptMessage): Cipher =
        withContext(Dispatchers.Main) {
            val host = activity() ?: throw VaultFailure(VaultErrorCode.BIOMETRICS_UNAVAILABLE)
            suspendCancellableCoroutine { cont ->
                val signal = CancellationSignal()
                cont.invokeOnCancellation { signal.cancel() }
                fun fail(code: VaultErrorCode) {
                    if (cont.isActive) cont.resumeWithException(VaultFailure(code))
                }
                val executor = host.mainExecutor
                val builder = BiometricPrompt.Builder(host)
                    .setTitle(prompt.title)
                    .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                    .setNegativeButton(prompt.cancelLabel, executor) { _, _ ->
                        fail(VaultErrorCode.USER_CANCELLED)
                    }
                prompt.subtitle?.let { builder.setSubtitle(it) }
                builder.build().authenticate(
                    BiometricPrompt.CryptoObject(cipher),
                    signal,
                    executor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                            val unlocked = result.cryptoObject?.cipher
                            if (unlocked == null) {
                                fail(VaultErrorCode.CORRUPTED)
                            } else if (cont.isActive) {
                                cont.resume(unlocked)
                            }
                        }

                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                            fail(errorFor(errorCode))
                        }
                    },
                )
            }
        }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private inline fun <T> guard(block: () -> T): T =
        try {
            block()
        } catch (e: VaultFailure) {
            throw e
        } catch (e: KeyPermanentlyInvalidatedException) {
            throw VaultFailure(VaultErrorCode.KEY_INVALIDATED)
        } catch (e: BadPaddingException) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        } catch (e: IllegalBlockSizeException) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        } catch (e: GeneralSecurityException) {
            throw VaultFailure(VaultErrorCode.STORAGE_UNAVAILABLE)
        }

    internal companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val ALIAS_PREFIX = "flutter_mfa.bio."

        fun alias(id: ByteArray): String = ALIAS_PREFIX + id.joinToString("") { "%02x".format(it) }

        /** BiometricPrompt error code to the vault error the app sees. */
        fun errorFor(code: Int): VaultErrorCode = when (code) {
            BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
            BiometricPrompt.BIOMETRIC_ERROR_CANCELED,
            BiometricPrompt.BIOMETRIC_ERROR_TIMEOUT,
            -> VaultErrorCode.USER_CANCELLED
            BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS -> VaultErrorCode.BIOMETRICS_NOT_ENROLLED
            else -> VaultErrorCode.BIOMETRICS_UNAVAILABLE
        }
    }
}
