package com.breaktroughf1.flutter_mfa

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class VaultFailureTest {
    @Test
    fun codesUseTheDartEnumNames() {
        // Must match `VaultErrorCode` in pigeons/messages.dart exactly: Dart maps by name.
        assertEquals(
            listOf(
                "notFound", "userCancelled", "keyInvalidated", "secureEnclaveUnavailable",
                "strongBoxUnavailable", "biometricsNotEnrolled", "biometricsUnavailable",
                "unsupportedOnPlatform", "hostActivityNotFragmentActivity", "storageUnavailable",
                "deviceLocked", "corrupted",
            ),
            VaultErrorCode.values().map { it.dartName() },
        )
    }

    @Test
    fun flutterErrorCarriesOnlyTheCode() {
        val error = VaultFailure(VaultErrorCode.KEY_INVALIDATED).toFlutterError()
        assertEquals("keyInvalidated", error.code)
        assertNull(error.message)
        assertNull(error.details)
    }
}
