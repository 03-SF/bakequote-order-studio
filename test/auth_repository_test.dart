import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bakequote_mobile/features/auth/data/supabase_auth_repository.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_models.dart';
import 'support/fake_auth_repository.dart';

class MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late SupabaseAuthRepository repository;
  var rejectUser = false;
  var requests = 0;
  final user = {
    'id': '10000000-0000-0000-0000-000000000001',
    'email': 'alice@example.test',
    'aud': 'authenticated',
    'email_confirmed_at': '2026-10-26T00:00:00Z',
    'created_at': '2026-10-26T00:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  };
  setUp(() async {
    requests = 0;
    rejectUser = false;
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient(
      'https://example.invalid',
      'test-anon',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryPkceStorage(),
      ),
      httpClient: MockClient((request) async {
        requests++;
        if (request.url.path.endsWith('/token')) {
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({
                    'sub': user['id'],
                    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                  }),
                ),
              )
              .replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': user,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/signup')) {
          return http.Response(jsonEncode(user), 200);
        }
        if (request.url.path.endsWith('/user')) {
          return http.Response(
            jsonEncode(
              rejectUser ? {'msg': 'invalid JWT', 'code': 'bad_jwt'} : user,
            ),
            rejectUser ? 401 : 200,
          );
        }
        return http.Response('{}', 200);
      }),
    );
    repository = SupabaseAuthRepository(
      client,
      testLiveConfig,
      await SharedPreferences.getInstance(),
    );
  });
  tearDown(() async {
    await client.dispose();
  });
  test(
    'SDK PKCE recovery exchange sets recovery marker, not ordinary sign-in',
    () async {
      await repository.requestReset('alice@example.test');
      final identity = await repository.completeCallback(
        Uri.parse('dev.bakequote.mobile://auth/reset?code=valid'),
        CallbackFlow.reset,
      );
      expect(identity.verified, isTrue);
      expect(await repository.isRecovering(identity.id), isTrue);
    },
  );
  test(
    'Recovery code arriving on verification path is rejected and signed out',
    () async {
      await repository.requestReset('alice@example.test');
      await expectLater(
        repository.completeCallback(
          Uri.parse('dev.bakequote.mobile://auth/verify?code=valid'),
          CallbackFlow.verify,
        ),
        throwsA(isA<UserFacingFailure>()),
      );
      expect(client.auth.currentSession, isNull);
    },
  );
  test(
    'Signup code cannot become recovery through URL query parameters',
    () async {
      await repository.register('alice@example.test', 'password', 'Alice');
      await expectLater(
        repository.completeCallback(
          Uri.parse(
            'dev.bakequote.mobile://auth/reset?code=valid&type=recovery',
          ),
          CallbackFlow.reset,
        ),
        throwsA(isA<UserFacingFailure>()),
      );
      expect(client.auth.currentSession, isNull);
    },
  );
  test(
    'Verification remains verification even with spoofed recovery query',
    () async {
      await repository.register('alice@example.test', 'password', 'Alice');
      final identity = await repository.completeCallback(
        Uri.parse(
          'dev.bakequote.mobile://auth/verify?code=valid&type=recovery',
        ),
        CallbackFlow.verify,
      );
      expect(await repository.isRecovering(identity.id), isFalse);
    },
  );
  test('Malformed callbacks fail before any HTTP exchange', () async {
    await expectLater(
      repository.completeCallback(
        Uri.parse('dev.bakequote.mobile://auth/reset?error=expired'),
        CallbackFlow.reset,
      ),
      throwsA(isA<UserFacingFailure>()),
    );
    expect(requests, 0);
  });
  test(
    'Missing signup verifier offers sign-in recovery without a token request',
    () async {
      await expectLater(
        repository.completeCallback(
          Uri.parse('dev.bakequote.mobile://auth/verify?code=valid'),
          CallbackFlow.verify,
        ),
        throwsA(
          isA<UserFacingFailure>().having(
            (e) => e.key,
            'message',
            contains('If your email was confirmed, sign in'),
          ),
        ),
      );
      expect(requests, 0);
    },
  );
  test('Missing recovery verifier asks for a new recovery link', () async {
    await expectLater(
      repository.completeCallback(
        Uri.parse('dev.bakequote.mobile://auth/reset?code=valid'),
        CallbackFlow.reset,
      ),
      throwsA(
        isA<UserFacingFailure>().having(
          (e) => e.key,
          'message',
          contains('Request a new recovery email'),
        ),
      ),
    );
    expect(requests, 0);
  });
  test(
    'Invalid server session clears the SDK session during restoration',
    () async {
      await repository.register('alice@example.test', 'password', 'Alice');
      await repository.completeCallback(
        Uri.parse('dev.bakequote.mobile://auth/verify?code=valid'),
        CallbackFlow.verify,
      );
      rejectUser = true;
      expect(await repository.restore(), isNull);
      expect(client.auth.currentSession, isNull);
    },
  );
}
