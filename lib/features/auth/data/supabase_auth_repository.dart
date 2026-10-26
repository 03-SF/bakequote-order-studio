import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/backend_config.dart';
import '../domain/auth_models.dart';
import 'auth_repository.dart';

final authRepositoryProvider = FutureProvider<AuthRepository?>((ref) async {
  final config = ref.watch(backendConfigProvider);
  if (config.isPreview) return null;
  if (config.validationError != null) {
    throw UserFacingFailure(config.validationError!);
  }
  // One SDK-owned persistence/refresh lifecycle; our controller owns callbacks.
  {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: false,
      ),
    );
  }
  return SupabaseAuthRepository(
    ref.read(supabaseClientProvider),
    config,
    await SharedPreferences.getInstance(),
  );
}, retry: (retryCount, error) => null);

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, this.config, this.preferences);
  final SupabaseClient client;
  final BackendConfig config;
  final SharedPreferences preferences;
  String get _recoveryKey => 'bakequote.recovery.${Uri.parse(config.url).host}';
  Identity _identity(User u) =>
      Identity(u.id, u.email ?? '', verified: u.emailConfirmedAt != null);
  @override
  Stream<SessionChange> get changes => client.auth.onAuthStateChange.map(
    (event) => SessionChange(
      event.session == null ? null : _identity(event.session!.user),
      recovery: event.event == AuthChangeEvent.passwordRecovery,
    ),
  );
  @override
  Future<Identity?> restore() async {
    if (client.auth.currentSession == null) return null;
    try {
      if (client.auth.currentSession!.isExpired) {
        await client.auth.refreshSession();
      }
      final user = (await client.auth.getUser()).user;
      return user == null ? null : _identity(user);
    } on AuthException catch (e) {
      if (e.statusCode == '401' ||
          e.statusCode == '403' ||
          e.code == 'refresh_token_not_found' ||
          e.code == 'session_not_found') {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Identity> login(String email, String password) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await preferences.remove(_recoveryKey);
    return _identity(response.user!);
  }

  @override
  Future<Identity?> register(String email, String password, String name) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
      emailRedirectTo: config.callback('verify').toString(),
    );
    return response.session == null ? null : _identity(response.user!);
  }

  @override
  Future<void> resend(String email) => client.auth.resend(
    type: OtpType.signup,
    email: email,
    emailRedirectTo: config.callback('verify').toString(),
  );
  @override
  Future<void> requestReset(String email) => client.auth.resetPasswordForEmail(
    email,
    redirectTo: config.callback('reset').toString(),
  );
  @override
  Future<Identity> completeCallback(Uri uri, CallbackFlow flow) async {
    if (callbackFlow(uri, Uri.parse(config.callbackBase)) != flow ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters['code']?.isNotEmpty != true ||
        uri.fragment.isNotEmpty) {
      throw const UserFacingFailure(
        'This link is invalid or expired. Request a new email.',
      );
    }
    final response = await client.auth.exchangeCodeForSession(
      uri.queryParameters['code']!,
    );
    final recovery =
        response.redirectType == AuthChangeEvent.passwordRecovery.name;
    if (recovery != (flow == CallbackFlow.reset)) {
      await logout();
      throw const UserFacingFailure(
        'This link belongs to a different authentication flow.',
      );
    }
    final identity = _identity(response.session.user);
    if (recovery) {
      await preferences.setString(_recoveryKey, identity.id);
    } else {
      await preferences.remove(_recoveryKey);
    }
    return identity;
  }

  @override
  Future<bool> isRecovering(String userId) async =>
      preferences.getString(_recoveryKey) == userId;
  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
    // Require a fresh password sign-in; recovery never silently enters the app.
    await logout();
  }

  @override
  Future<void> logout() async {
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } finally {
      await preferences.remove(_recoveryKey);
    }
  }

  @override
  Future<AccountProfile> profile(String userId) async {
    final p = await client.from('profiles').select().eq('id', userId).single();
    Map<String, dynamic>? b;
    if (p['initial_experience'] == 'baker') {
      b = await client
          .from('businesses')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();
    }
    return AccountProfile(
      id: userId,
      name: p['display_name'] as String,
      phone: p['phone'] as String,
      locale: p['locale'] as String,
      experience: p['initial_experience'] as String?,
      businessId: b?['id'] as String?,
      businessName: b?['name'] as String?,
      profileImage: p['image_path'] as String?,
      businessImage: b?['image_path'] as String?,
    );
  }

  @override
  Future<void> completeIdentity(
    String experience,
    String name,
    String phone,
    String businessName,
  ) => client.rpc(
    'complete_identity',
    params: {
      'p_experience': experience,
      'p_name': name,
      'p_phone': phone,
      'p_business_name': businessName,
    },
  );
  @override
  Future<void> saveProfile(
    String userId,
    String name,
    String phone,
    String locale,
  ) async {
    await client
        .from('profiles')
        .update({'display_name': name, 'phone': phone, 'locale': locale})
        .eq('id', userId)
        .select('id')
        .single();
  }

  @override
  Future<void> uploadImage(
    AccountProfile profile,
    Uint8List bytes, {
    required bool business,
  }) async {
    final kind = validateImage(bytes);
    if (business && profile.businessId == null) {
      throw const UserFacingFailure('Business identity is required');
    }
    final bucket = business ? 'business-images' : 'profile-images';
    final path =
        '${business ? '${profile.businessId}/profile' : profile.id}/${const Uuid().v4()}.${kind.extension}';
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: kind.mime, upsert: false),
        );
    try {
      await client
          .from(business ? 'businesses' : 'profiles')
          .update({'image_path': path})
          .eq('id', business ? profile.businessId! : profile.id)
          .select('id')
          .single();
    } catch (_) {
      // Best-effort cleanup of only the just-uploaded object; never another asset.
      try {
        await client.storage.from(bucket).remove([path]);
      } catch (_) {
        /* retry cleanup later */
      }
      rethrow;
    }
  }

  @override
  Future<String> imageUrl(
    AccountProfile profile, {
    required bool business,
  }) async {
    final path = business ? profile.businessImage : profile.profileImage;
    if (path == null) return '';
    if (business) {
      return client.storage.from('business-images').getPublicUrl(path);
    }
    return client.storage.from('profile-images').createSignedUrl(path, 300);
  }
}
