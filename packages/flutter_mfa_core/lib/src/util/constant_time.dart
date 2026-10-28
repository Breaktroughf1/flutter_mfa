/// Compares two byte sequences in time that depends only on their lengths.
///
/// Every position of the longer input is read and XOR-accumulated, so the
/// running time does not reveal where the first difference is (S9, FR-VER-04).
/// Only the low 8 bits of each element are compared. This protects code and
/// secret comparisons against remote timing attacks; it cannot hide the input
/// lengths, which are public for OTP codes.
bool constantTimeEquals(List<int> a, List<int> b) => _equals(a, b, 0xff);

/// Compares two strings by UTF-16 code unit in constant time for their length.
///
/// Used for submitted OTP codes; see [constantTimeEquals].
bool constantTimeStringEquals(String a, String b) =>
    _equals(a.codeUnits, b.codeUnits, 0xffff);

bool _equals(List<int> a, List<int> b, int mask) {
  final n = a.length > b.length ? a.length : b.length;
  var diff = a.length ^ b.length;
  for (var i = 0; i < n; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    diff |= (x ^ y) & mask;
  }
  return diff == 0;
}
