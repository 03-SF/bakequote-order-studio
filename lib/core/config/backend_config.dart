import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendConfig {
  const BackendConfig({
    this.url = '',
    this.publishableKey = '',
    this.mode = 'preview',
    this.callbackBase = 'dev.bakequote.mobile://auth',
  });
  static const environment = BackendConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    mode: String.fromEnvironment('APP_MODE', defaultValue: 'preview'),
    callbackBase: String.fromEnvironment(
      'AUTH_CALLBACK_BASE',
      defaultValue: 'dev.bakequote.mobile://auth',
    ),
  );
  final String url, publishableKey, mode, callbackBase;
  bool get isPreview => mode == 'preview';
  bool get isConfigured => validationError == null;
  String? get validationError {
    if (mode != 'preview' && mode != 'live') return 'Invalid app mode';
    if (isPreview) return null;
    final callbackUri = Uri.tryParse(callbackBase);
    final nativeCallback = callbackBase == 'dev.bakequote.mobile://auth';
    final localCallback =
        callbackUri != null &&
        callbackUri.scheme == 'http' &&
        {'localhost', '127.0.0.1'}.contains(callbackUri.host) &&
        callbackUri.path == '/auth' &&
        callbackUri.userInfo.isEmpty &&
        !callbackUri.hasQuery &&
        !callbackUri.hasFragment;
    if (!nativeCallback && !localCallback) {
      return 'Invalid callback configuration';
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host)))) {
      return 'Invalid backend configuration';
    }
    if (publishableKey.startsWith('sb_secret_')) {
      return 'Privileged keys are forbidden';
    }
    if (publishableKey.startsWith('sb_publishable_')) return null;
    try {
      final payload =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(
                    base64Url.normalize(publishableKey.split('.')[1]),
                  ),
                ),
              )
              as Map<String, dynamic>;
      if (payload['role'] == 'anon') return null;
    } catch (_) {
      /* Only public publishable or legacy anon keys are accepted. */
    }
    return 'Use a public publishable key';
  }

  Uri callback(String flow) => Uri.parse('$callbackBase/$flow');
}

final backendConfigProvider = Provider((ref) => BackendConfig.environment);

/// Initialized asynchronously by the live auth repository; never accessed in preview.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
