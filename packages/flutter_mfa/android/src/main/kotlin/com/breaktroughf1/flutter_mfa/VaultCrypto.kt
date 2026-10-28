package com.breaktroughf1.flutter_mfa

/** Ciphertext with the nonce it was produced with. */
internal class Sealed(val nonce: ByteArray, val ciphertext: ByteArray)

/**
 * Authenticated encryption used by [FileVault]: AES-256-GCM, 96-bit nonce,
 * 128-bit tag. Production uses a non-exportable Keystore key ([KeystoreCrypto]).
 */
internal interface VaultCrypto {
    /** Encrypts [plaintext] bound to [aad] with a fresh random nonce. */
    fun seal(plaintext: ByteArray, aad: ByteArray): Sealed

    /**
     * Decrypts and authenticates. Throws [VaultFailure] with
     * [VaultErrorCode.CORRUPTED] if the data or [aad] were modified.
     */
    fun open(sealed: Sealed, aad: ByteArray): ByteArray

    /** Whether the key lives in secure hardware (TEE or StrongBox). */
    fun isHardwareBacked(): Boolean

    /** Destroys the key; existing ciphertext becomes unreadable. */
    fun destroy()
}
