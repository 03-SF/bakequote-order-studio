import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/media/image_validation.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../data/baker_repository.dart';
import '../domain/baker_repository.dart';
import '../domain/baker_workspace.dart';

final bakerRepositoryProvider = FutureProvider.autoDispose<BakerRepository>((
  ref,
) async {
  final preview = ref.watch(backendConfigProvider).isPreview;
  if (preview) {
    return PreviewBakerRepository(await SharedPreferences.getInstance());
  }
  final auth = ref.watch(authControllerProvider);
  if (auth.phase != AuthPhase.signedIn || auth.profile?.businessId == null) {
    throw const FormatException('Sign in as the business owner');
  }
  return SupabaseBakerRepository(
    ref.read(supabaseClientProvider),
    await SharedPreferences.getInstance(),
    auth.identity!.id,
    auth.profile!.businessId!,
  );
}, retry: (_, _) => null);
final bakerWorkspaceProvider = FutureProvider.autoDispose<BakerWorkspace>((
  ref,
) async {
  final repo = await ref.watch(bakerRepositoryProvider.future);
  final workspace = await repo.load();
  try {
    await repo.retryCleanup();
  } catch (_) {
    /* Explicit retry remains available. */
  }
  return workspace;
}, retry: (_, _) => null);
String bakerError(Object error) {
  if (error is ImageValidationFailure) return error.message;
  if (error is FormatException) return error.message;
  // Avoid exposing database details; conflict and authorization have useful safe copy.
  final text = error.toString();
  if (text.contains('40001')) {
    return 'Workspace changed. Reload and review before saving.';
  }
  if (text.contains('42501') || text.contains('401') || text.contains('JWT')) {
    return 'Session expired or access denied. Sign in again.';
  }
  return 'Could not save this change. Check your connection and retry.';
}
