/// Native apps have no web security context; the camera is always allowed.
bool get isSecureContext => true;

/// Native apps always decode QR codes on the device.
Future<bool> supportsNativeQrDecoding() async => true;
