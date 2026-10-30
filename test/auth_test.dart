import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bakequote_mobile/core/config/backend_config.dart';
import 'package:bakequote_mobile/features/auth/application/auth_controller.dart';
import 'package:bakequote_mobile/core/media/image_validation.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_models.dart';
import 'support/fake_auth_repository.dart';

void main() {
  test(
    'Authentication, database and network errors have distinct safe guidance',
    () {
      expect(
        authErrorKey(const AuthException('private', code: 'bad_code_verifier')),
        contains('invalid or expired'),
      );
      expect(
        authErrorKey(const AuthException('private', code: 'unexpected')),
        contains('Authentication'),
      );
      expect(
        authErrorKey(const PostgrestException(message: 'private SQL')),
        contains('account data'),
      );
      expect(authErrorKey(TimeoutException('private')), contains('connection'));
    },
  );
  test('Shared image failures map to safe authentication copy', () {
    expect(
      authErrorKey(
        const ImageValidationFailure('Choose a JPEG, PNG or WebP image'),
      ),
      'Choose a JPEG, PNG or WebP image',
    );
  });
  test(
    'Session expiry during a profile write cannot resurrect private data',
    () async {
      final repo = FakeAuthRepository()
        ..restored = alice
        ..saveGate = Completer<void>();
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      final controller = c.read(authControllerProvider.notifier);
      await settleAuth();
      final saving = controller.saveProfile('Alice', '123', 'en');
      await settleAuth();
      repo.events.add(const SessionChange(null));
      await settleAuth();
      expect(c.read(authControllerProvider).profile, isNull);
      repo.saveGate!.complete();
      await saving;
      await settleAuth();
      expect(c.read(authControllerProvider).phase, AuthPhase.signedOut);
      expect(c.read(authControllerProvider).profile, isNull);
    },
  );
  test(
    'Guards wait for initialization and segregate preview, recovery and roles',
    () {
      expect(
        authRedirect(
          const AuthViewState(),
          '/live/customer/home',
          preview: false,
        ),
        '/auth/loading',
      );
      expect(
        authRedirect(
          const AuthViewState(phase: AuthPhase.signedOut),
          '/live/baker/today',
          preview: false,
        ),
        '/auth/login',
      );
      expect(
        authRedirect(
          const AuthViewState(phase: AuthPhase.recovery),
          '/auth/verify',
          preview: false,
        ),
        '/auth/reset',
      );
      expect(
        authRedirect(
          AuthViewState(
            phase: AuthPhase.signedIn,
            profile: profileFor('alice'),
          ),
          '/live/baker/today',
          preview: false,
        ),
        '/live/customer/home',
      );
      expect(
        authRedirect(
          const AuthViewState(phase: AuthPhase.signedOut),
          '/auth/login',
          preview: true,
        ),
        '/',
      );
      expect(
        authRedirect(
          AuthViewState(
            phase: AuthPhase.signedIn,
            profile: profileFor('alice'),
          ),
          '/baker/today',
          preview: false,
        ),
        '/live/customer/home',
      );
    },
  );
  test(
    'Registration waits for verification and supports resend without fake identity',
    () async {
      final repo = FakeAuthRepository();
      final container = authContainer(repo);
      addTearDown(container.dispose);
      addTearDown(repo.events.close);
      final controller = container.read(authControllerProvider.notifier);
      await settleAuth();
      await controller.register('alice@example.test', 'password', 'Alice');
      expect(
        container.read(authControllerProvider).phase,
        AuthPhase.verifyEmail,
      );
      expect(container.read(authControllerProvider).identity, isNull);
      await controller.resend('alice@example.test');
      expect(repo.resends, 1);
      await controller.leaveVerification();
      expect(container.read(authControllerProvider).phase, AuthPhase.signedOut);
    },
  );
  test(
    'Duplicate login is blocked, and profile is cleared on logout',
    () async {
      final repo = FakeAuthRepository()..loginGate = Completer<Identity>();
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      final controller = c.read(authControllerProvider.notifier);
      await settleAuth();
      final login = controller.login('alice@example.test', 'password');
      await settleAuth();
      await controller.login('alice@example.test', 'password');
      expect(repo.logins, 1);
      repo.loginGate!.complete(alice);
      await login;
      expect(c.read(authControllerProvider).profile?.id, 'alice');
      await controller.logout();
      expect(c.read(authControllerProvider).profile, isNull);
      expect(c.read(authControllerProvider).phase, AuthPhase.signedOut);
    },
  );
  test(
    'Restoration gate holds private data until session is checked',
    () async {
      final repo = FakeAuthRepository()..restoreGate = Completer<Identity?>();
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      c.read(authControllerProvider);
      await settleAuth();
      expect(c.read(authControllerProvider).phase, AuthPhase.initializing);
      repo.restoreGate!.complete(alice);
      await settleAuth();
      expect(c.read(authControllerProvider).profile?.id, 'alice');
    },
  );
  test(
    'Late profile fetch cannot restore a logged-out or switched account',
    () async {
      final repo = FakeAuthRepository()..restored = alice;
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      final controller = c.read(authControllerProvider.notifier);
      await settleAuth();
      repo.profileGates['bob'] = Completer<AccountProfile>();
      repo.events.add(const SessionChange(bob));
      await settleAuth();
      expect(c.read(authControllerProvider).profile, isNull);
      await controller.logout();
      repo.profileGates['bob']!.complete(profileFor('bob'));
      await settleAuth();
      expect(c.read(authControllerProvider).phase, AuthPhase.signedOut);
      expect(c.read(authControllerProvider).profile, isNull);
    },
  );
  test(
    'Recovery survives restoration and cannot silently route into the app',
    () async {
      final repo = FakeAuthRepository()
        ..restored = alice
        ..recovering = true;
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      final controller = c.read(authControllerProvider.notifier);
      await settleAuth();
      expect(c.read(authControllerProvider).phase, AuthPhase.recovery);
      repo.events.add(const SessionChange(bob));
      await settleAuth();
      expect(c.read(authControllerProvider).phase, AuthPhase.signedIn);
      repo.events.add(const SessionChange(alice, recovery: true));
      await settleAuth();
      await controller.resetPassword('newpassword');
      expect(repo.passwordChanges, 1);
      expect(c.read(authControllerProvider).phase, AuthPhase.signedOut);
    },
  );
  test(
    'Initial recovery callback takes precedence over a restored session',
    () async {
      final repo = FakeAuthRepository()..restored = bob;
      final c = authContainer(
        repo,
        initial: Future.value(
          Uri.parse('dev.bakequote.mobile://auth/reset?code=valid'),
        ),
      );
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      c.read(authControllerProvider);
      await settleAuth();
      expect(c.read(authControllerProvider).phase, AuthPhase.recovery);
      expect(c.read(authControllerProvider).profile, isNull);
    },
  );
  test(
    'Invalid callbacks and expired sessions never expose an old profile',
    () async {
      final repo = FakeAuthRepository()..restored = alice;
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      final controller = c.read(authControllerProvider.notifier);
      await settleAuth();
      await controller.handleCallback(
        Uri.parse('dev.bakequote.mobile://auth/reset?code=invalid'),
      );
      expect(c.read(authControllerProvider).phase, AuthPhase.signedOut);
      expect(c.read(authControllerProvider).profile, isNull);
      repo.events.add(const SessionChange(null));
      await settleAuth();
      expect(c.read(authControllerProvider).identity, isNull);
    },
  );
  test(
    'Backend failures hide account data and do not reveal internals',
    () async {
      final repo = FakeAuthRepository()
        ..restored = alice
        ..failProfile = true;
      final c = authContainer(repo);
      addTearDown(c.dispose);
      addTearDown(repo.events.close);
      c.read(authControllerProvider);
      await settleAuth();
      expect(c.read(authControllerProvider).phase, AuthPhase.failure);
      expect(c.read(authControllerProvider).profile, isNull);
      expect(
        c.read(authControllerProvider).message,
        isNot(contains('internals')),
      );
    },
  );
  test('Configuration rejects privileged keys and insecure remote URLs', () {
    expect(
      const BackendConfig(
        mode: 'live',
        url: 'https://example.test',
        publishableKey: 'sb_secret_forbidden',
      ).isConfigured,
      isFalse,
    );
    expect(
      const BackendConfig(
        mode: 'live',
        url: 'http://example.test',
        publishableKey: 'sb_publishable_test',
      ).isConfigured,
      isFalse,
    );
    expect(const BackendConfig(mode: 'live').isConfigured, isFalse);
    expect(testLiveConfig.isConfigured, isTrue);
  });
  test('Callback paths and upload bytes are strictly validated', () {
    final base = Uri.parse('dev.bakequote.mobile://auth');
    expect(
      callbackFlow(
        Uri.parse('dev.bakequote.mobile://other/reset?type=recovery'),
        base,
      ),
      isNull,
    );
    expect(
      callbackFlow(
        Uri.parse('dev.bakequote.mobile://auth/verify?type=recovery'),
        base,
      ),
      CallbackFlow.verify,
    );
    expect(
      () => validateImage(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ImageValidationFailure>()),
    );
    expect(
      () => validateImage(Uint8List(5 * 1024 * 1024 + 1)),
      throwsA(isA<ImageValidationFailure>()),
    );
    expect(
      validateImage(Uint8List.fromList([255, 216, 255, 0])).mime,
      'image/jpeg',
    );
  });
}
