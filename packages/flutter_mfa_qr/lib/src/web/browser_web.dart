import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Whether the page is a secure context; `false` if it cannot be read, so
/// the camera is never requested in an unknown context (fail closed).
bool get isSecureContext {
  final value = globalContext['isSecureContext'];
  return value.isA<JSBoolean>() && (value! as JSBoolean).toDart;
}

/// Whether the browser's `BarcodeDetector` can decode QR codes; `false` if
/// it is missing or cannot be queried.
Future<bool> supportsNativeQrDecoding() async {
  if (!globalContext.has('BarcodeDetector')) return false;
  try {
    final formats = await _BarcodeDetector.getSupportedFormats().toDart;
    return formats.toDart.any((format) => format.toDart == 'qr_code');
  } on Object {
    return false;
  }
}

@JS('BarcodeDetector')
extension type _BarcodeDetector._(JSObject _) implements JSObject {
  external static JSPromise<JSArray<JSString>> getSupportedFormats();
}
