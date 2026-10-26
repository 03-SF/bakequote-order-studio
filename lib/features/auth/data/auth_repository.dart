import 'dart:typed_data';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Stream<SessionChange> get changes;
  Future<Identity?> restore();
  Future<Identity> login(String email, String password);
  Future<Identity?> register(String email, String password, String name);
  Future<void> resend(String email);
  Future<void> requestReset(String email);
  Future<Identity> completeCallback(Uri uri, CallbackFlow flow);
  Future<bool> isRecovering(String userId);
  Future<void> updatePassword(String password);
  Future<void> logout();
  Future<AccountProfile> profile(String userId);
  Future<void> completeIdentity(
    String experience,
    String name,
    String phone,
    String businessName,
  );
  Future<void> saveProfile(
    String userId,
    String name,
    String phone,
    String locale,
  );
  Future<void> uploadImage(
    AccountProfile profile,
    Uint8List bytes, {
    required bool business,
  });
  Future<String> imageUrl(AccountProfile profile, {required bool business});
}

class ImageKind {
  const ImageKind(this.extension, this.mime);
  final String extension, mime;
}

ImageKind validateImage(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const UserFacingFailure('Choose an image up to 5 MB');
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
  throw const UserFacingFailure('Choose a JPEG, PNG or WebP image');
}
