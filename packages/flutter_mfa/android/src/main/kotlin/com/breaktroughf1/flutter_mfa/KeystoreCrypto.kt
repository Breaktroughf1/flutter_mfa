package com.breaktroughf1.flutter_mfa

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.security.keystore.UserNotAuthenticatedException
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

/**
 * [VaultCrypto] backed by a non-exportable AES-256-GCM key in Android Keystore.
 *
 * The key is created on first use with StrongBox when the device has it
 * (falling back to the TEE, which is still hardware-backed: this is the
 * `standard` level, which does not promise StrongBox), and on API 28+ it can
 * only be used while the device is unlocked. The key material never enters
 * app memory. Nothing is logged.
 */
internal class KeystoreCrypto(private val strongBoxAvailable: Boolean) : VaultCrypto {

    override fun seal(plaintext: ByteArray, aad: ByteArray): Sealed = guard {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key()) // Keystore generates a random 96-bit IV
        cipher.updateAAD(aad)
        val ciphertext = cipher.doFinal(plaintext)
        Sealed(cipher.iv, ciphertext)
    }

    override fun open(sealed: Sealed, aad: ByteArray): ByteArray = guard {
        val existing = existingKey() ?: throw VaultFailure(VaultErrorCode.CORRUPTED)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, existing, GCMParameterSpec(TAG_BITS, sealed.nonce))
        cipher.updateAAD(aad)
        cipher.doFinal(sealed.ciphertext)
    }

    override fun isHardwareBacked(): Boolean = guard {
        val info = SecretKeyFactory.getInstance(key().algorithm, KEYSTORE)
            .getKeySpec(key(), KeyInfo::class.java) as KeyInfo
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            info.securityLevel != KeyProperties.SECURITY_LEVEL_SOFTWARE
        } else {
            @Suppress("DEPRECATION")
            info.isInsideSecureHardware
        }
    }

    override fun destroy() {
        guard { keyStore().deleteEntry(ALIAS) }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    private fun existingKey(): SecretKey? = keyStore().getKey(ALIAS, null) as SecretKey?

    @Synchronized
    private fun key(): SecretKey = existingKey() ?: create(strongBoxAvailable)

    private fun create(strongBox: Boolean): SecretKey {
        val builder = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(KEY_BITS)
            .setRandomizedEncryptionRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setUnlockedDeviceRequired(true)
            if (strongBox) builder.setIsStrongBoxBacked(true)
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        return try {
            generator.init(builder.build())
            generator.generateKey()
        } catch (e: StrongBoxUnavailableException) {
            create(strongBox = false)
        }
    }

    private inline fun <T> guard(block: () -> T): T =
        try {
            block()
        } catch (e: VaultFailure) {
            throw e
        } catch (e: KeyPermanentlyInvalidatedException) {
            throw VaultFailure(VaultErrorCode.KEY_INVALIDATED)
        } catch (e: UserNotAuthenticatedException) {
            throw VaultFailure(VaultErrorCode.DEVICE_LOCKED)
        } catch (e: AEADBadTagException) {
            throw VaultFailure(VaultErrorCode.CORRUPTED)
        } catch (e: GeneralSecurityException) {
            throw VaultFailure(VaultErrorCode.STORAGE_UNAVAILABLE)
        }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val ALIAS = "flutter_mfa.master.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_BITS = 256
        const val TAG_BITS = 128
    }
}
