import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';

/// A short label for [level], used wherever the example offers protection.
String protectionLabel(ProtectionLevel level) => switch (level) {
  ProtectionLevel.standard => 'Standard',
  ProtectionLevel.biometric => 'Fingerprint or face for every code',
  ProtectionLevel.hardwareBound => 'Fingerprint or face, secure hardware',
};

/// The protection levels this device offers, in order. Only these are ever
/// shown, so the user never picks a level the vault would refuse (and the
/// vault never silently stores a weaker one).
Future<List<ProtectionLevel>> supportedProtection(MfaClient client) async {
  final caps = await client.capabilities;
  return ProtectionLevel.values.where(caps.supportedLevels.contains).toList();
}

/// Asks how to protect the account named [accountLabel] when the device
/// offers more than one level; otherwise returns [ProtectionLevel.standard]
/// without asking. Returns `null` if the user cancels.
Future<ProtectionLevel?> pickProtection(
  BuildContext context,
  MfaClient client, {
  required String accountLabel,
}) async {
  final levels = await supportedProtection(client);
  if (levels.length < 2) return ProtectionLevel.standard;
  if (!context.mounted) return null;
  return showDialog<ProtectionLevel>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('Protect $accountLabel'),
      children: [
        for (final level in levels)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(level),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(protectionLabel(level)),
            ),
          ),
      ],
    ),
  );
}
