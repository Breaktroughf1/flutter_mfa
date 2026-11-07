package com.breaktroughf1.flutter_mfa

import android.hardware.biometrics.BiometricPrompt
import kotlin.test.Test
import kotlin.test.assertEquals

internal class BiometricErrorTest {
    @Test
    fun promptErrorsMapToVaultErrors() {
        val cancelled = listOf(
            BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
            BiometricPrompt.BIOMETRIC_ERROR_CANCELED,
            BiometricPrompt.BIOMETRIC_ERROR_TIMEOUT,
        )
        for (code in cancelled) {
            assertEquals(VaultErrorCode.USER_CANCELLED, KeystoreProtectedKeys.errorFor(code))
        }
        assertEquals(
            VaultErrorCode.BIOMETRICS_NOT_ENROLLED,
            KeystoreProtectedKeys.errorFor(BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS),
        )
        for (code in listOf(
            BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
            BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT,
            BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE,
            BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT,
        )) {
            assertEquals(VaultErrorCode.BIOMETRICS_UNAVAILABLE, KeystoreProtectedKeys.errorFor(code))
        }
    }

    @Test
    fun aliasesRevealOnlyTheRandomId() {
        assertEquals(
            "flutter_mfa.bio.00ff10ab00000001",
            KeystoreProtectedKeys.alias(byteArrayOf(0, -1, 16, -85, 0, 0, 0, 1)),
        )
    }
}
