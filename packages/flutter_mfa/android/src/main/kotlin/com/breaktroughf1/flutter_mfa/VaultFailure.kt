package com.breaktroughf1.flutter_mfa

/**
 * A vault failure with a schema error [code]. Carries no message: native
 * errors must never leak values (CLAUDE.md rule 2), and Dart maps only the code.
 */
internal class VaultFailure(val code: VaultErrorCode) : Exception() {
    /** The platform error sent over the channel: the Dart enum name of [code]. */
    fun toFlutterError(): FlutterError = FlutterError(code.dartName())
}

/** `NOT_FOUND` -> `notFound`: the name of the same value in the Dart and Swift enums. */
internal fun VaultErrorCode.dartName(): String =
    name.lowercase().split('_').mapIndexed { i, part ->
        if (i == 0) part else part.replaceFirstChar { it.uppercaseChar() }
    }.joinToString("")
