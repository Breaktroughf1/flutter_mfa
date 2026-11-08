package com.breaktroughf1.flutter_mfa

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlin.test.assertFalse
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The capability probes behind `capabilities()` must answer, never throw, on a
 * real device (API 24 and 36 in CI). The emulators have no enrolled
 * fingerprints, so protected levels are not offered there.
 */
@RunWith(AndroidJUnit4::class)
class CapabilitiesInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun biometricsAreReportedAsNotEnrolledWithoutFingerprints() {
        assertFalse(FlutterMfaPlugin.biometricsEnrolled(context))
    }

    @Test
    fun strongBoxAndHardwareBackingAreQueryable() {
        FlutterMfaPlugin.hasStrongBox(context)
        FlutterMfaPlugin.isDeviceSecure(context)
        val crypto = KeystoreCrypto(strongBoxAvailable = false)
        try {
            crypto.isHardwareBacked()
        } finally {
            crypto.destroy()
        }
    }
}
