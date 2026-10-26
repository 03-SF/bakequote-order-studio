import 'dart:typed_data';

import 'auth_models.dart';

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
