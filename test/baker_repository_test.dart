import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bakequote_mobile/features/baker/data/baker_repository.dart';
import 'support/baker_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late SupabaseBakerRepository repo;
  final userId = '60000000-0000-4000-8000-000000000001';
  var rejectUpload = false,
      rejectPointer = false,
      commitThenLoseResponse = false,
      failDelete = false;
  String? pointer;
  var uploaded = '', deletes = 0, requests = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    rejectUpload = false;
    rejectPointer = false;
    commitThenLoseResponse = false;
    failDelete = false;
    pointer = null;
    uploaded = '';
    deletes = 0;
    requests = 0;
    client = SupabaseClient(
      'https://example.invalid',
      'test-anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        http.Response reply(
          String body,
          int status, {
          Map<String, String>? headers,
        }) => http.Response(
          body,
          status,
          request: r,
          headers: {'content-type': 'application/json', ...?headers},
        );
        requests++;
        final path = r.url.path;
        if (path.endsWith('/token')) {
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({
                    'sub': userId,
                    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                  }),
                ),
              )
              .replaceAll('=', '');
          return reply(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
              'refresh_token': 'test',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': userId,
                'aud': 'authenticated',
                'email': 'owner@example.test',
                'created_at': '2026-10-26T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            }),
            200,
          );
        }
        if (path.startsWith('/storage/v1/object/') && r.method == 'POST') {
          uploaded = path.split('/product-images/').last;
          return reply(
            rejectUpload ? '{}' : '{"Key":"uploaded"}',
            rejectUpload ? 400 : 200,
          );
        }
        if (path.endsWith('/rpc/set_baker_image')) {
          if (commitThenLoseResponse) pointer = jsonDecode(r.body)['p_path'];
          if (rejectPointer || commitThenLoseResponse) {
            return reply('{"code":"40001","message":"conflict"}', 409);
          }
          pointer = jsonDecode(r.body)['p_path'];
          return reply('1', 200);
        }
        if (path.endsWith('/businesses')) {
          return reply(
            jsonEncode(fixture().business),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/products')) {
          final list = r.url.queryParameters.containsKey('image_path')
              ? (pointer != null &&
                        r.url.queryParameters['image_path'] == 'eq.$pointer'
                    ? [
                        {'image_path': pointer},
                      ]
                    : [])
              : [
                  {...fixture().products[0], 'image_path': pointer},
                ];
          return reply(
            jsonEncode(list),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/delivery_zones')) {
          return reply(
            jsonEncode(fixture().zones),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.method == 'DELETE') {
          deletes++;
          return reply(failDelete ? '{}' : '[]', failDelete ? 500 : 200);
        }
        return reply('{}', 200);
      }),
    );
    await client.auth.signInWithPassword(
      email: 'owner@example.test',
      password: 'password',
    );
    repo = SupabaseBakerRepository(
      client,
      await SharedPreferences.getInstance(),
      userId,
      fixture().id,
    );
  });
  tearDown(() async => client.dispose());
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  test(
    'Failed upload cannot change image pointer and cleanup remains retryable',
    () async {
      rejectUpload = true;
      await expectLater(
        repo.image(fixture(), 'product', productId, bytes, (_) {}),
        throwsA(isA<StorageException>()),
      );
      expect(pointer, null);
      rejectUpload = false;
      expect(await repo.retryCleanup(), 0);
      expect(deletes, 1);
    },
  );
  test('Pointer conflict cleans only newly uploaded object', () async {
    rejectPointer = true;
    await expectLater(
      repo.image(fixture(), 'product', productId, bytes, (_) {}),
      throwsA(isA<PostgrestException>()),
    );
    expect(pointer, null);
    expect(uploaded, startsWith('${fixture().id}/$productId/'));
    expect(deletes, 1);
    expect(await repo.retryCleanup(), 0);
  });
  test(
    'Lost response after pointer commit never deletes referenced new image',
    () async {
      commitThenLoseResponse = true;
      await expectLater(
        repo.image(fixture(), 'product', productId, bytes, (_) {}),
        throwsA(isA<PostgrestException>()),
      );
      expect(pointer, uploaded);
      expect(deletes, 0);
      expect(await repo.retryCleanup(), 0);
    },
  );
  test(
    'Replaced image cleanup retries after failure and removal clears pointer',
    () async {
      final w = fixture();
      w.products[0]['image_path'] =
          '${w.id}/$productId/70000000-0000-4000-8000-000000000001.png';
      failDelete = true;
      final result = await repo.image(w, 'product', productId, bytes, (_) {});
      expect(result.products[0]['image_path'], uploaded);
      failDelete = false;
      expect(await repo.retryCleanup(), 0);
      expect(deletes, 2);
      await repo.image(result, 'product', productId, null, (_) {});
      expect(pointer, null);
    },
  );
  test(
    'Changed session stops stale account repository before HTTP access',
    () async {
      await client.auth.signOut(scope: SignOutScope.local);
      final before = requests;
      await expectLater(repo.load(), throwsFormatException);
      expect(requests, before);
    },
  );
}
