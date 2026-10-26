import 'dart:typed_data';

class ImageKind {
  const ImageKind(this.extension, this.mime);
  final String extension;
  final String mime;
}

class ImageValidationFailure implements Exception {
  const ImageValidationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

ImageKind validateImage(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const ImageValidationFailure('Choose an image up to 5 MB');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    return const ImageKind('jpg', 'image/jpeg');
  }
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= 8 &&
      List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
    return const ImageKind('png', 'image/png');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return const ImageKind('webp', 'image/webp');
  }
  throw const ImageValidationFailure('Choose a JPEG, PNG or WebP image');
}
