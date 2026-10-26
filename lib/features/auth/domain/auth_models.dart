enum AuthPhase {
  initializing,
  signedOut,
  verifyEmail,
  onboarding,
  signedIn,
  recovery,
  failure,
}

class Identity {
  const Identity(this.id, this.email, {required this.verified});
  final String id, email;
  final bool verified;
}

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.locale = 'en',
    this.experience,
    this.businessId,
    this.businessName,
    this.profileImage,
    this.businessImage,
  });
  final String id, name, phone, locale;
  final String? experience,
      businessId,
      businessName,
      profileImage,
      businessImage;
}

class SessionChange {
  const SessionChange(this.identity, {this.recovery = false});
  final Identity? identity;
  final bool recovery;
}

class AuthViewState {
  const AuthViewState({
    this.phase = AuthPhase.initializing,
    this.identity,
    this.profile,
    this.busy = false,
    this.message,
    this.error = false,
    this.email = '',
  });
  final AuthPhase phase;
  final Identity? identity;
  final AccountProfile? profile;
  final bool busy, error;
  final String? message;
  final String email;
  AuthViewState operation({
    required bool busy,
    String? message,
    bool error = false,
  }) => AuthViewState(
    phase: phase,
    identity: identity,
    profile: profile,
    busy: busy,
    message: message,
    error: error,
    email: email,
  );
}

class UserFacingFailure implements Exception {
  const UserFacingFailure(this.key);
  final String key;
}

String? validateEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? null
    : 'Enter a valid email';
String? validatePassword(String value) =>
    value.length >= 8 ? null : 'Use at least 8 characters';
String? validateName(String value) =>
    value.trim().isNotEmpty && value.trim().length <= 100
    ? null
    : 'Enter 1 to 100 characters';

enum CallbackFlow { verify, reset }

CallbackFlow? callbackFlow(Uri uri, Uri base) {
  if (uri.scheme != base.scheme ||
      uri.host != base.host ||
      uri.port != base.port ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  if (uri.path == '${base.path}/verify') return CallbackFlow.verify;
  if (uri.path == '${base.path}/reset') return CallbackFlow.reset;
  return null;
}

/// Route guards are UX only. Database RLS and grants enforce authorization.
String? authRedirect(AuthViewState s, String path, {required bool preview}) {
  if (preview) {
    return path.startsWith('/live') || path.startsWith('/auth') ? '/' : null;
  }
  if (s.phase == AuthPhase.initializing) {
    return path == '/auth/loading' ? null : '/auth/loading';
  }
  if (s.phase == AuthPhase.failure) {
    return path == '/auth/session-error' ? null : '/auth/session-error';
  }
  if (s.phase == AuthPhase.recovery) {
    return path == '/auth/reset' ? null : '/auth/reset';
  }
  if (s.phase == AuthPhase.verifyEmail) {
    return path == '/auth/verify' ? null : '/auth/verify';
  }
  if (s.phase == AuthPhase.signedOut) {
    return {'/auth/login', '/auth/register', '/auth/forgot'}.contains(path)
        ? null
        : '/auth/login';
  }
  if (s.phase == AuthPhase.onboarding) {
    return path == '/auth/onboarding' ? null : '/auth/onboarding';
  }
  final role = s.profile?.experience;
  final home = role == 'baker' ? '/live/baker/today' : '/live/customer/home';
  return path.startsWith('/live/$role/') ? null : home;
}
