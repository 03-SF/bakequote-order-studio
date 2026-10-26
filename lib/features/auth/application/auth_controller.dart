import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/backend_config.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import '../../../core/media/image_validation.dart';

final authRepositoryProvider = FutureProvider<AuthRepository?>((ref) async {
  final config = ref.watch(backendConfigProvider);
  if (config.isPreview) return null;
  if (config.validationError != null) {
    throw UserFacingFailure(config.validationError!);
  }
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: false,
    ),
  );
  return SupabaseAuthRepository(
    ref.read(supabaseClientProvider),
    config,
    await SharedPreferences.getInstance(),
  );
}, retry: (_, _) => null);

final incomingAuthLinksProvider = Provider<Stream<Uri>>(
  (ref) => kIsWeb ? const Stream.empty() : AppLinks().uriLinkStream,
);
final initialAuthLinkProvider = Provider<Future<Uri?>>(
  (ref) async => kIsWeb ? Uri.base : AppLinks().getInitialLink(),
);
final authControllerProvider = NotifierProvider<AuthController, AuthViewState>(
  AuthController.new,
);
String authErrorKey(Object error) {
  if (error is UserFacingFailure) return error.key;
  if (error is ImageValidationFailure) return error.message;
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Email or password is incorrect';
      case 'email_not_confirmed':
        return 'Verify your email before signing in';
      case 'weak_password':
        return 'Use a stronger password';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Please wait before trying again';
      case 'otp_expired':
      case 'flow_state_expired':
      case 'flow_state_not_found':
        return 'This link is invalid or expired. Request a new email.';
    }
  }
  // Do not display raw backend messages, SQL details, URLs or credentials.
  return 'Could not complete this action. Check your connection and try again.';
}

class AuthController extends Notifier<AuthViewState> {
  AuthRepository? _repository;
  bool get canLogout => _repository != null;
  bool _disposed = false,
      _mutating = false,
      _booting = true,
      _handlingLink = false;
  String? _recoveryUserId;
  int _epoch = 0;
  final _seenLinks = <String>{};
  final _queuedLinks = <Uri>[];
  StreamSubscription<SessionChange>? _sessionSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  @override
  AuthViewState build() {
    ref.onDispose(() {
      _disposed = true;
      _epoch++;
      unawaited(_sessionSubscription?.cancel());
      unawaited(_linkSubscription?.cancel());
    });
    Future.microtask(initialize);
    return const AuthViewState();
  }

  Future<void> retry() async {
    ref.invalidate(authRepositoryProvider);
    await initialize();
  }

  Future<void> initialize() async {
    if (_disposed) return;
    state = const AuthViewState();
    _booting = true;
    _epoch++;
    try {
      _repository = await ref
          .read(authRepositoryProvider.future)
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;
      if (_repository == null) {
        state = const AuthViewState(phase: AuthPhase.signedOut);
        _booting = false;
        return;
      }
      await _sessionSubscription?.cancel();
      await _linkSubscription?.cancel();
      _sessionSubscription = _repository!.changes.listen(
        (event) {
          // Clear revoked/expired identities even if a mutation is in flight.
          if (!_booting &&
              !_handlingLink &&
              !_disposed &&
              event.identity == null) {
            _epoch++;
            _recoveryUserId = null;
            state = const AuthViewState(phase: AuthPhase.signedOut);
            return;
          }
          // SDK auth events can occur inside its auth lock. Defer repository calls.
          if (!_booting && !_mutating && !_handlingLink && !_disposed) {
            Future.microtask(() async {
              if (event.recovery) _recoveryUserId = event.identity?.id;
              await _accept(event.identity);
            });
          }
        },
        onError: (Object error) {
          if (!_disposed && !_booting && !_mutating && !_handlingLink) {
            _failure(error);
          }
        },
      );
      _linkSubscription = ref
          .read(incomingAuthLinksProvider)
          .listen(
            (uri) {
              if (callbackFlow(
                    uri,
                    Uri.parse(ref.read(backendConfigProvider).callbackBase),
                  ) ==
                  null) {
                return;
              }
              if (_booting || _handlingLink || _mutating) {
                _queuedLinks.add(uri);
              } else {
                unawaited(handleCallback(uri));
              }
            },
            onError: (Object error) {
              if (!_disposed) _failure(error);
            },
          );
      final identity = await _repository!.restore().timeout(
        const Duration(seconds: 20),
      );
      final initial = await ref.read(initialAuthLinkProvider);
      if (_disposed) return;
      if (initial != null &&
          callbackFlow(
                initial,
                Uri.parse(ref.read(backendConfigProvider).callbackBase),
              ) !=
              null) {
        _queuedLinks.insert(0, initial);
      }
      _queuedLinks.removeWhere((uri) => _seenLinks.contains(uri.toString()));
      if (_queuedLinks.isEmpty) await _accept(identity);
      // Process a captured callback before exposing the restored account.
      await _drainLinks();
      _booting = false;
    } catch (error) {
      if (!_disposed) {
        _booting = false;
        _failure(error);
      }
    }
  }

  void _failure(Object error) {
    _epoch++;
    state = AuthViewState(
      phase: AuthPhase.failure,
      message: authErrorKey(error),
      error: true,
    );
  }

  Future<void> _accept(Identity? identity) async {
    final request = ++_epoch;
    if (_disposed) return;
    // Drop the previous profile immediately, before any asynchronous read.
    state = const AuthViewState();
    if (identity == null) {
      _recoveryUserId = null;
      state = const AuthViewState(phase: AuthPhase.signedOut);
      return;
    }
    if (!identity.verified) {
      state = AuthViewState(
        phase: AuthPhase.verifyEmail,
        identity: identity,
        email: identity.email,
      );
      return;
    }
    try {
      final recovering =
          _recoveryUserId == identity.id ||
          await _repository!.isRecovering(identity.id);
      if (_disposed || request != _epoch) return;
      if (recovering) {
        _recoveryUserId = identity.id;
        state = AuthViewState(phase: AuthPhase.recovery, identity: identity);
        return;
      }
      final profile = await _repository!
          .profile(identity.id)
          .timeout(const Duration(seconds: 20));
      if (_disposed || request != _epoch) return;
      if (profile.id != identity.id ||
          (profile.experience != null &&
              !{'customer', 'baker'}.contains(profile.experience)) ||
          (profile.experience == 'baker' && profile.businessId == null)) {
        throw const UserFacingFailure('Account data could not be verified');
      }
      state = AuthViewState(
        phase: profile.experience == null
            ? AuthPhase.onboarding
            : AuthPhase.signedIn,
        identity: identity,
        profile: profile,
      );
    } catch (error) {
      if (!_disposed && request == _epoch) _failure(error);
    }
  }

  Future<void> _drainLinks() async {
    while (_queuedLinks.isNotEmpty && !_disposed) {
      await handleCallback(_queuedLinks.removeAt(0));
    }
  }

  Future<void> handleCallback(Uri uri) async {
    final flow = callbackFlow(
      uri,
      Uri.parse(ref.read(backendConfigProvider).callbackBase),
    );
    if (flow == null || _repository == null || _disposed) return;
    if (_handlingLink) {
      _queuedLinks.add(uri);
      return;
    }
    if (!_seenLinks.add(uri.toString())) return;
    _handlingLink = true;
    _epoch++;
    state = const AuthViewState();
    try {
      final identity = await _repository!.completeCallback(uri, flow);
      _recoveryUserId = flow == CallbackFlow.reset ? identity.id : null;
      await _accept(identity);
    } catch (error) {
      // An invalid callback never falls through to an old authenticated screen.
      try {
        await _repository!.logout();
      } catch (_) {
        /* still clear local view */
      }
      _recoveryUserId = null;
      if (!_disposed) {
        state = AuthViewState(
          phase: AuthPhase.signedOut,
          message: authErrorKey(error),
          error: true,
        );
      }
    } finally {
      _handlingLink = false;
    }
    if (!_booting) await _drainLinks();
  }

  Future<void> _run(Future<void> Function(AuthRepository) action) async {
    if (state.busy ||
        _mutating ||
        _handlingLink ||
        _repository == null ||
        _disposed) {
      return;
    }
    _mutating = true;
    state = state.operation(busy: true);
    try {
      await action(_repository!);
    } catch (error) {
      if (!_disposed) {
        state = state.operation(
          busy: false,
          message: authErrorKey(error),
          error: true,
        );
      }
    } finally {
      _mutating = false;
      if (!_disposed && state.busy) state = state.operation(busy: false);
    }
    await _drainLinks();
  }

  Future<void> login(String email, String password) => _run((repo) async {
    try {
      final identity = await repo.login(email.trim(), password);
      _recoveryUserId = null;
      await _accept(identity);
    } on AuthException catch (error) {
      if (error.code == 'email_not_confirmed') {
        state = AuthViewState(
          phase: AuthPhase.verifyEmail,
          email: email.trim(),
          message: 'Verify your email before signing in',
        );
      } else {
        rethrow;
      }
    }
  });
  Future<void> register(String email, String password, String name) => _run((
    repo,
  ) async {
    final identity = await repo.register(email.trim(), password, name.trim());
    if (identity == null) {
      state = AuthViewState(
        phase: AuthPhase.verifyEmail,
        email: email.trim(),
        message: 'Check your email to verify your account',
      );
    } else {
      await _accept(identity);
    }
  });
  Future<void> leaveVerification() async {
    if (state.busy) return;
    if (state.identity != null) {
      await logout();
    } else {
      state = const AuthViewState(phase: AuthPhase.signedOut);
    }
  }

  Future<void> resend(String email) => _run((repo) async {
    await repo.resend(email.trim());
    state = state.operation(
      busy: false,
      message: 'Verification email sent if eligible',
    );
  });
  Future<void> requestReset(String email) => _run((repo) async {
    await repo.requestReset(email.trim());
    state = state.operation(
      busy: false,
      message: 'Recovery email sent if an account exists',
    );
  });
  Future<void> resetPassword(String password) => _run((repo) async {
    if (state.phase != AuthPhase.recovery) {
      throw const UserFacingFailure('Open a valid recovery link first');
    }
    await repo.updatePassword(password);
    _recoveryUserId = null;
    state = const AuthViewState(
      phase: AuthPhase.signedOut,
      message: 'Password updated. Sign in with your new password.',
    );
  });
  Future<void> logout() => _run((repo) async {
    _epoch++;
    _recoveryUserId = null;
    state = const AuthViewState(busy: true);
    try {
      await repo.logout();
    } finally {
      if (!_disposed) state = const AuthViewState(phase: AuthPhase.signedOut);
    }
  });
  Future<void> completeIdentity(
    String experience,
    String name,
    String phone,
    String businessName,
  ) => _run((repo) async {
    final identity = state.identity!;
    await repo.completeIdentity(
      experience,
      name.trim(),
      phone.trim(),
      businessName.trim(),
    );
    if (state.identity?.id == identity.id) await _accept(identity);
  });
  Future<void> saveProfile(String name, String phone, String locale) =>
      _run((repo) async {
        final identity = state.identity!;
        await repo.saveProfile(identity.id, name.trim(), phone.trim(), locale);
        if (state.identity?.id != identity.id) return;
        await _accept(identity);
        if (state.phase == AuthPhase.signedIn) {
          state = state.operation(busy: false, message: 'Profile saved');
        }
      });
  Future<void> uploadImage(Uint8List bytes, {required bool business}) =>
      _run((repo) async {
        final identity = state.identity!, profile = state.profile!;
        await repo.uploadImage(profile, bytes, business: business);
        if (state.identity?.id != identity.id) return;
        await _accept(identity);
        if (state.phase == AuthPhase.signedIn) {
          state = state.operation(busy: false, message: 'Image uploaded');
        }
      });
  void showImageFailure(Object error) {
    state = state.operation(
      busy: false,
      message: authErrorKey(error),
      error: true,
    );
  }
}
