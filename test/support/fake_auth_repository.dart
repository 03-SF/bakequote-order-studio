import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bakequote_mobile/core/media/image_validation.dart';
import 'package:bakequote_mobile/core/config/backend_config.dart';
import 'package:bakequote_mobile/features/auth/application/auth_controller.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_models.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_repository.dart';

const testLiveConfig = BackendConfig(
  mode: 'live',
  url: 'https://example.invalid',
  publishableKey: 'sb_publishable_test_only',
);
const alice = Identity('alice', 'alice@example.test', verified: true);
const bob = Identity('bob', 'bob@example.test', verified: true);
AccountProfile profileFor(String id) => AccountProfile(
  id: id,
  name: id,
  phone: '',
  experience: id == 'bob' ? 'baker' : 'customer',
  businessId: id == 'bob' ? 'bakery-b' : null,
);

class FakeAuthRepository implements AuthRepository {
  final events = StreamController<SessionChange>.broadcast();
  Identity? restored;
  bool recovering = false, failProfile = false;
  int logins = 0,
      registrations = 0,
      resends = 0,
      logouts = 0,
      passwordChanges = 0;
  Completer<Identity?>? restoreGate;
  Completer<Identity>? loginGate;
  Completer<void>? saveGate;
  final profileGates = <String, Completer<AccountProfile>>{};
  @override
  Stream<SessionChange> get changes => events.stream;
  @override
  Future<Identity?> restore() async =>
      restoreGate == null ? restored : restoreGate!.future;
  @override
  Future<Identity> login(String email, String password) async {
    logins++;
    return loginGate == null ? alice : loginGate!.future;
  }

  @override
  Future<Identity?> register(String email, String password, String name) async {
    registrations++;
    return null;
  }

  @override
  Future<void> resend(String email) async {
    resends++;
  }

  @override
  Future<void> requestReset(String email) async {}
  @override
  Future<Identity> completeCallback(Uri uri, CallbackFlow flow) async {
    if (uri.queryParameters['code'] == 'invalid') {
      throw const UserFacingFailure(
        'This link is invalid or expired. Request a new email.',
      );
    }
    recovering = flow == CallbackFlow.reset;
    return alice;
  }

  @override
  Future<bool> isRecovering(String userId) async =>
      recovering && userId == 'alice';
  @override
  Future<void> updatePassword(String password) async {
    passwordChanges++;
    recovering = false;
    restored = null;
  }

  @override
  Future<void> logout() async {
    logouts++;
    restored = null;
    recovering = false;
  }

  @override
  Future<AccountProfile> profile(String id) async {
    if (failProfile) throw StateError('Do not leak server internals');
    return profileGates[id]?.future ?? profileFor(id);
  }

  @override
  Future<void> completeIdentity(
    String experience,
    String name,
    String phone,
    String businessName,
  ) async {}
  @override
  Future<void> saveProfile(
    String userId,
    String name,
    String phone,
    String locale,
  ) async {
    await saveGate?.future;
  }

  @override
  Future<void> uploadImage(
    AccountProfile profile,
    Uint8List bytes, {
    required bool business,
  }) async {
    validateImage(bytes);
  }

  @override
  Future<String> imageUrl(
    AccountProfile profile, {
    required bool business,
  }) async => '';
}

ProviderContainer authContainer(
  FakeAuthRepository repo, {
  Future<Uri?>? initial,
}) => ProviderContainer(
  overrides: [
    backendConfigProvider.overrideWithValue(testLiveConfig),
    authRepositoryProvider.overrideWith((ref) async => repo),
    incomingAuthLinksProvider.overrideWithValue(const Stream.empty()),
    initialAuthLinkProvider.overrideWithValue(initial ?? Future.value(null)),
  ],
);
Future<void> settleAuth() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
