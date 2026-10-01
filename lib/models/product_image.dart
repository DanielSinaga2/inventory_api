import 'dart:typed_data';

class ProductImage {
  ProductImage._(this.bytes, this.filename, this.mimeType);

  static const maxBytes = 5 * 1024 * 1024;
  final Uint8List bytes;
  final String filename;
  final String mimeType;

  factory ProductImage.fromBytes(Uint8List bytes, String filename) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Pilih gambar berukuran maksimal 5 MB.');
    }
    bool startsWith(List<int> signature) =>
        bytes.length >= signature.length &&
        signature.asMap().entries.every((e) => bytes[e.key] == e.value);
    final String mime;
    if (startsWith([137, 80, 78, 71, 13, 10, 26, 10])) {
      mime = 'image/png';
    } else if (startsWith([255, 216, 255])) {
      mime = 'image/jpeg';
    } else if (bytes.length >= 12 &&
        startsWith([82, 73, 70, 70]) &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      mime = 'image/webp';
    } else {
      throw const FormatException('Gunakan gambar JPG, PNG, atau WebP.');
    }
    return ProductImage._(bytes, filename, mime);
  }
}
