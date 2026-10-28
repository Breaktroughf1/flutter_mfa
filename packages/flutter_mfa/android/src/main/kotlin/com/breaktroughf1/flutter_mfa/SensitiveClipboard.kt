package com.breaktroughf1.flutter_mfa

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle

/**
 * Copies a code marked sensitive and clears it after the expiry (FR-FAC-05).
 *
 * On Android 13+ `EXTRA_IS_SENSITIVE` hides the content from the clipboard
 * preview and keyboard suggestions; older releases honour the same extra on
 * some OEMs. The clip is cleared only if it is still ours (same timestamp on
 * API 26+, same text below that), so a later copy by the user is never wiped. Apps targeting older releases can still read the
 * clipboard while the code is on it (documented residual risk S6).
 */
internal class SensitiveClipboard(context: Context) {
    private val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    private val handler = Handler(Looper.getMainLooper())

    fun copy(text: String, expiryMillis: Long) {
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean(SENSITIVE_EXTRA, true)
        }
        clipboard.setPrimaryClip(clip)
        val stamp = currentStamp()
        handler.postDelayed({ clearIfOurs(stamp, text) }, expiryMillis.coerceAtLeast(0))
    }

    private fun currentStamp(): Long? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) clipboard.primaryClipDescription?.timestamp else null

    private fun clearIfOurs(stamp: Long?, text: String) {
        val stillOurs =
            if (stamp != null) {
                currentStamp() == stamp
            } else {
                // No clip timestamps before API 26: compare the content instead.
                clipboard.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString() == text
            }
        if (!stillOurs) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    private companion object {
        /** `ClipDescription.EXTRA_IS_SENSITIVE`, spelled out so it also applies below API 33. */
        val SENSITIVE_EXTRA: String =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) ClipDescription.EXTRA_IS_SENSITIVE
            else "android.content.extra.IS_SENSITIVE"
    }
}
