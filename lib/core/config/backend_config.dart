import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendConfig {
  const BackendConfig({this.url = '', this.publishableKey = ''});
  static const environment = BackendConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  final String url;
  final String publishableKey;
  bool get isConfigured =>
      Uri.tryParse(url)?.scheme == 'https' && publishableKey.isNotEmpty;
}

final backendConfigProvider = Provider((ref) => BackendConfig.environment);

/// Intentionally disconnected in Phase 1. Phase 2 supplies the real client.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
