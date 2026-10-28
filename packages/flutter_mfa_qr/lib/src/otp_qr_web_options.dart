import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// How `OtpQrScanner` decodes QR codes in a browser (FR-QR-03, ADR-0005).
///
/// By default only the browser's built-in `BarcodeDetector` is used and no
/// script is loaded, so a strict Content-Security-Policy keeps working.
/// Browsers without it (Firefox at the time of writing) then report
/// `OtpQrScannerStatus.unsupportedBrowser` without asking for the camera;
/// offer manual entry, or opt in to a JavaScript decoder:
///
/// * [decoderScriptUrl]: load the pure-JavaScript `@zxing/library` UMD build
///   (version 0.23.0 is the one mobile_scanner targets) from a URL you host.
///   It needs no other files. Takes precedence over [allowRemoteDecoder].
/// * [allowRemoteDecoder]: fall back to the `zxing-wasm` decoder, whose
///   script and WebAssembly binary are fetched from `cdn.jsdelivr.net`. The
///   page then runs third-party code it does not control.
///
/// These settings are page-wide: the decoder script is loaded at most once,
/// so use the same options for every scanner in an app.
@immutable
final class OtpQrWebOptions {
  /// Creates web decoding options; the defaults load no script.
  const OtpQrWebOptions({
    this.allowRemoteDecoder = false,
    this.decoderScriptUrl,
  });

  /// Whether browsers without `BarcodeDetector` may load the zxing-wasm
  /// decoder from a public CDN.
  final bool allowRemoteDecoder;

  /// A self-hosted `@zxing/library` UMD script: an `https` URL or a path on
  /// the app's own origin (for example `zxing/index.min.js`).
  final Uri? decoderScriptUrl;

  @override
  bool operator ==(Object other) =>
      other is OtpQrWebOptions &&
      other.allowRemoteDecoder == allowRemoteDecoder &&
      other.decoderScriptUrl == decoderScriptUrl;

  @override
  int get hashCode => Object.hash(allowRemoteDecoder, decoderScriptUrl);
}

/// The mobile_scanner web reader and script URL for [options].
///
/// Throws [ArgumentError] if `decoderScriptUrl` is neither `https` nor a
/// same-origin path, so a script is never loaded over plain HTTP or from a
/// `data:` or `javascript:` URL.
(WebBarcodeReader, String?) webDecoderFor(OtpQrWebOptions options) {
  final url = options.decoderScriptUrl;
  if (url != null) {
    final sameOrigin = !url.hasScheme && !url.hasAuthority && url.path != '';
    if (!(url.isScheme('https') && url.host.isNotEmpty) && !sameOrigin) {
      throw ArgumentError(
        'must be an https URL or a same-origin path',
        'decoderScriptUrl',
      );
    }
    return (WebBarcodeReader.zxingJs, url.toString());
  }
  return options.allowRemoteDecoder
      ? (WebBarcodeReader.auto, null)
      : (WebBarcodeReader.barcodeDetector, null);
}
