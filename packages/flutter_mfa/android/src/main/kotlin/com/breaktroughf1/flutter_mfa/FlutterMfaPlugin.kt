package com.breaktroughf1.flutter_mfa

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Android entry point of flutter_mfa.
 *
 * The Keystore-backed vault (Pigeon host API) is added in M1-12.
 */
class FlutterMfaPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
