package com.breaktroughf1.flutter_mfa

import kotlin.test.Test
import kotlin.test.assertIs

/** JVM unit tests for the plugin entry point. Vault tests are added in M1-12. */
internal class FlutterMfaPluginTest {
    @Test
    fun pluginImplementsFlutterPlugin() {
        assertIs<io.flutter.embedding.engine.plugins.FlutterPlugin>(FlutterMfaPlugin())
    }
}
