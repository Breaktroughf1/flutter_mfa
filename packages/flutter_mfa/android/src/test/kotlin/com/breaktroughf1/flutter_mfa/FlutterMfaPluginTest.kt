package com.breaktroughf1.flutter_mfa

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

/** JVM unit tests for the plugin entry point. */
internal class FlutterMfaPluginTest {
    @Test
    fun pluginImplementsFlutterPlugin() {
        assertIs<io.flutter.embedding.engine.plugins.FlutterPlugin>(FlutterMfaPlugin())
    }

    @Test
    fun capabilitiesOfferHardwareBoundOnlyWhenStrongBoxIsAvailable() {
        assertEquals(
            listOf(ProtectionLevelMessage.STANDARD),
            FlutterMfaPlugin.supportedLevels(hardwareBacked = false, biometricsAvailable = true, strongBox = true),
        )
        assertEquals(
            listOf(ProtectionLevelMessage.STANDARD),
            FlutterMfaPlugin.supportedLevels(hardwareBacked = true, biometricsAvailable = false, strongBox = true),
        )
        assertEquals(
            listOf(ProtectionLevelMessage.STANDARD, ProtectionLevelMessage.BIOMETRIC),
            FlutterMfaPlugin.supportedLevels(hardwareBacked = true, biometricsAvailable = true, strongBox = false),
        )
        assertEquals(
            listOf(
                ProtectionLevelMessage.STANDARD,
                ProtectionLevelMessage.BIOMETRIC,
                ProtectionLevelMessage.HARDWARE_BOUND,
            ),
            FlutterMfaPlugin.supportedLevels(hardwareBacked = true, biometricsAvailable = true, strongBox = true),
        )
    }
}
