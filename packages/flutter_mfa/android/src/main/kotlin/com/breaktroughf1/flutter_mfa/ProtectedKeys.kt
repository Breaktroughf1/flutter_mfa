package com.breaktroughf1.flutter_mfa

import java.security.PublicKey

/**
 * The per-entry RSA key pairs behind `biometric` and `hardwareBound` entries
 * (02 §4.1, ADR-0004). Each entry has its own random [ID_SIZE]-byte id, so
 * aliases reveal nothing about key names and an overwrite never touches the
 * key of the entry it replaces until the new file is in place.
 */
internal interface ProtectedKeys {
    /** Whether protected levels can be offered now (capabilities). */
    fun available(): Boolean

    /**
     * Creates a key pair that only a strong biometric can unlock, in StrongBox
     * when [hardwareBound] (failing with `STRONG_BOX_UNAVAILABLE` if absent)
     * and in the TEE otherwise; never in software. Returns its id and public key.
     */
    fun create(hardwareBound: Boolean): Pair<ByteArray, PublicKey>

    /**
     * Shows [prompt] and, after a strong biometric, unwraps [wrapped] with the
     * private key [id]. Throws [VaultFailure] (`USER_CANCELLED`,
     * `KEY_INVALIDATED`, `BIOMETRICS_UNAVAILABLE`, `CORRUPTED`, ...).
     */
    suspend fun unwrap(id: ByteArray, wrapped: ByteArray, prompt: PromptMessage?): ByteArray

    /** Deletes key [id]; absent ids are ignored. */
    fun delete(id: ByteArray)

    /** Deletes every key this plugin created. */
    fun deleteAll()

    companion object {
        const val ID_SIZE = 8
    }
}

/** Devices without per-operation strong-biometric keys (API < 30): fail closed. */
internal object UnsupportedProtectedKeys : ProtectedKeys {
    override fun available() = false

    override fun create(hardwareBound: Boolean): Pair<ByteArray, PublicKey> =
        throw VaultFailure(VaultErrorCode.UNSUPPORTED_ON_PLATFORM)

    override suspend fun unwrap(id: ByteArray, wrapped: ByteArray, prompt: PromptMessage?): ByteArray =
        throw VaultFailure(VaultErrorCode.UNSUPPORTED_ON_PLATFORM)

    override fun delete(id: ByteArray) = Unit

    override fun deleteAll() = Unit
}
