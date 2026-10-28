package com.breaktroughf1.flutter_mfa

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Android entry point of flutter_mfa: a thin byte vault behind the Pigeon
 * [MfaHostApi]. No OTP logic, JSON or validation lives here (CLAUDE.md rule 1).
 */
class FlutterMfaPlugin : FlutterPlugin, ActivityAware, MfaHostApi {
    private var context: Context? = null
    private var crypto: KeystoreCrypto? = null
    private var vault: FileVault? = null
    private var clipboard: SensitiveClipboard? = null
    private var activity: Activity? = null
    private var screenCaptureProtected = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val ctx = binding.applicationContext
        context = ctx
        val keystore = KeystoreCrypto(strongBoxAvailable = hasStrongBox(ctx))
        crypto = keystore
        vault = FileVault(File(ctx.noBackupFilesDir, VAULT_DIR), keystore)
        clipboard = SensitiveClipboard(ctx)
        MfaHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MfaHostApi.setUp(binding.binaryMessenger, null)
        vault = null
        crypto = null
        clipboard = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        applyScreenCapture()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun capabilities(): CapabilitiesMessage = vaultCall {
        val ctx = requireNotNull(context)
        CapabilitiesMessage(
            hardwareBacked = crypto?.isHardwareBacked() ?: false,
            strongBox = hasStrongBox(ctx),
            secureEnclave = false,
            biometricsEnrolled = biometricsEnrolled(ctx),
            persistentStorage = true,
            screenCaptureProtection = true,
            // Biometric and hardware-bound levels arrive in M3-05 (fail closed until then).
            supportedLevels = listOf(ProtectionLevelMessage.STANDARD),
        )
    }

    override suspend fun write(key: String, value: ByteArray, level: ProtectionLevelMessage) =
        withContext(Dispatchers.IO) { vaultCall { requireVault().write(key, value, level) } }

    override suspend fun read(key: String, prompt: PromptMessage?): ByteArray? =
        withContext(Dispatchers.IO) { vaultCall { requireVault().read(key) } }

    override fun delete(key: String) = vaultCall { requireVault().delete(key) }

    override fun keys(): List<String> = vaultCall { requireVault().keys() }

    override fun wipe() = vaultCall { requireVault().wipe() }

    override fun copySensitive(text: String, expiryMillis: Long) {
        requireNotNull(clipboard).copy(text, expiryMillis)
    }

    override fun setScreenCaptureProtection(enabled: Boolean) {
        screenCaptureProtected = enabled
        applyScreenCapture()
    }

    private fun applyScreenCapture() {
        val window = activity?.window ?: return
        if (screenCaptureProtected) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun requireVault(): FileVault =
        vault ?: throw VaultFailure(VaultErrorCode.STORAGE_UNAVAILABLE)

    private inline fun <T> vaultCall(block: () -> T): T =
        try {
            block()
        } catch (e: VaultFailure) {
            throw e.toFlutterError()
        }

    internal companion object {
        const val VAULT_DIR = "flutter_mfa"

        fun hasStrongBox(ctx: Context): Boolean =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)

        /**
         * Whether strong biometrics are enrolled. Querying needs the app to hold
         * `USE_BIOMETRIC` (the plugin declares it with biometric gating, M3-05);
         * without it the answer is `false` rather than a `SecurityException`.
         */
        fun biometricsEnrolled(ctx: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
            if (ctx.checkSelfPermission(Manifest.permission.USE_BIOMETRIC) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return false
            }
            val manager = ctx.getSystemService(android.hardware.biometrics.BiometricManager::class.java)
                ?: return false
            return try {
                manager.canAuthenticate(
                    android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG,
                ) == android.hardware.biometrics.BiometricManager.BIOMETRIC_SUCCESS
            } catch (e: SecurityException) {
                false
            }
        }
    }
}
