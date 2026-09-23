import 'dart:math';

/// Generates UUID v4 values locally so inserts can use a known ID without
/// requesting a row representation before its ownership link exists.
class UuidGenerator {
  UuidGenerator._();

  static final Random _random = Random.secure();
  static const String _hex = '0123456789abcdef';

  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final value = bytes.map((byte) {
      return _hex[byte >> 4] + _hex[byte & 0x0f];
    }).join();

    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20, 32)}';
  }
}
