package com.breaktroughf1.flutter_mfa

import java.security.KeyFactory
import java.security.PublicKey
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

/**
 * RSA-OAEP key wrapping for biometric entries (ADR-0004, 04 §6): a random
 * AES-256 data key is wrapped with the entry's Keystore public key, which needs
 * no authentication, and unwrapped only by the private key inside a
 * BiometricPrompt `CryptoObject`.
 *
 * OAEP uses SHA-256 with MGF1-SHA-1, the only MGF1 digest Android Keystore
 * accepts before API 34. (`RSA/ECB/...` is the JCA name; RSA has no block mode.)
 */
internal object RsaEnvelope {
    const val TRANSFORMATION = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"
    const val KEY_BITS = 2048
    const val WRAPPED_SIZE = KEY_BITS / 8

    val OAEP: OAEPParameterSpec =
        OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT)

    /** Wraps [dataKey] with [publicKey] (in software: public-key use needs no auth). */
    fun wrap(publicKey: PublicKey, dataKey: ByteArray): ByteArray {
        // A software copy of the public key avoids Keystore's purpose checks.
        val soft = KeyFactory.getInstance(publicKey.algorithm)
            .generatePublic(X509EncodedKeySpec(publicKey.encoded))
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, soft, OAEP)
        return cipher.doFinal(dataKey)
    }
}
