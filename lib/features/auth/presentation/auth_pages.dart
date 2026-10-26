import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../shared/widgets/controls.dart';
import '../../preview/presentation/preview_pages.dart';
import '../application/auth_controller.dart';
import '../domain/auth_models.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Wordmark(), actions: const [LanguageButton()]),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.of(context).t(title),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthMessage extends ConsumerWidget {
  const AuthMessage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return state.message == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                AppStrings.of(context).t(state.message!),
                style: TextStyle(
                  color: state.error
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          );
  }
}

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({required this.view, super.key});
  final String view;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController(),
      _name = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    for (final c in [_email, _password, _confirmation, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context),
        state = ref.watch(authControllerProvider),
        controller = ref.read(authControllerProvider.notifier);
    final view = widget.view;
    if (view == 'loading') {
      return AuthFrame(
        title: 'Restoring your session',
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    if (view == 'session-error') {
      return AuthFrame(
        title: 'Account unavailable',
        children: [
          const AuthMessage(),
          Text(
            s.t('Account data is hidden until your session can be checked.'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.busy ? null : controller.retry,
            child: Text(s.t('Retry')),
          ),
          if (!controller.canLogout)
            Text(s.t('Configure the development backend before signing in.')),
          if (controller.canLogout)
            TextButton(
              onPressed: state.busy ? null : controller.logout,
              child: Text(s.t('Log out')),
            ),
        ],
      );
    }
    if (view == 'verify') {
      return AuthFrame(
        title: 'Verify your email',
        children: [
          const AuthMessage(),
          Text(state.email, textDirection: TextDirection.ltr),
          const SizedBox(height: 12),
          Text(
            s.t(
              'Open the verification email on this device, or verify then sign in.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.busy ? null : () => controller.resend(state.email),
            child: Text(s.t('Resend verification')),
          ),
          TextButton(
            onPressed: state.busy ? null : controller.leaveVerification,
            child: Text(s.t('Sign in after verification')),
          ),
        ],
      );
    }
    final registration = view == 'register',
        recovery = view == 'reset',
        forgot = view == 'forgot';
    final title = registration
        ? 'Create account'
        : recovery
        ? 'Set new password'
        : forgot
        ? 'Reset password'
        : 'Sign in';
    return AuthFrame(
      title: title,
      children: [
        const AuthMessage(),
        if (ref.watch(backendConfigProvider).validationError != null)
          Text(s.t('Configure the development backend before signing in.')),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (registration) ...[
                TextFormField(
                  controller: _name,
                  enabled: !state.busy,
                  maxLength: 100,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: s.t('Full name')),
                  validator: (v) => _translate(validateName(v ?? ''), s),
                ),
                const SizedBox(height: 16),
              ],
              if (!recovery) ...[
                TextFormField(
                  controller: _email,
                  enabled: !state.busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: s.t('Email')),
                  validator: (v) => _translate(validateEmail(v ?? ''), s),
                ),
                const SizedBox(height: 16),
              ],
              if (!forgot) ...[
                TextFormField(
                  controller: _password,
                  enabled: !state.busy,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [
                    registration || recovery
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: s.t('Password'),
                    suffixIcon: IconButton(
                      tooltip: s.t('Show or hide password'),
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => registration || recovery
                      ? _translate(validatePassword(v ?? ''), s)
                      : (v?.isNotEmpty == true
                            ? null
                            : s.t('Enter your password')),
                ),
                const SizedBox(height: 16),
              ],
              if (registration || recovery) ...[
                TextFormField(
                  controller: _confirmation,
                  enabled: !state.busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: s.t('Confirm password'),
                  ),
                  validator: (v) => v == _password.text
                      ? null
                      : s.t('Passwords do not match'),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: state.busy
                    ? null
                    : () async {
                        if (!_form.currentState!.validate()) return;
                        if (registration) {
                          await controller.register(
                            _email.text,
                            _password.text,
                            _name.text,
                          );
                        } else if (recovery) {
                          await controller.resetPassword(_password.text);
                        } else if (forgot) {
                          await controller.requestReset(_email.text);
                        } else {
                          await controller.login(_email.text, _password.text);
                        }
                      },
                child: state.busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.t(forgot ? 'Send recovery email' : title)),
              ),
              if (view == 'login') ...[
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => context.go('/auth/register'),
                  child: Text(s.t('Create account')),
                ),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => context.go('/auth/forgot'),
                  child: Text(s.t('Forgot password?')),
                ),
              ],
              if (registration || forgot)
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => context.go('/auth/login'),
                  child: Text(s.t('Back to sign in')),
                ),
              if (recovery)
                TextButton(
                  onPressed: state.busy ? null : controller.logout,
                  child: Text(s.t('Cancel and sign out')),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _translate(String? key, AppStrings s) =>
      key == null ? null : s.t(key);
}

class IdentityPage extends ConsumerStatefulWidget {
  const IdentityPage({super.key});
  @override
  ConsumerState<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends ConsumerState<IdentityPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _phone = TextEditingController(), _business = TextEditingController();
  String _experience = 'customer';
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(authControllerProvider).profile?.name ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _business.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context),
        state = ref.watch(authControllerProvider),
        controller = ref.read(authControllerProvider.notifier);
    return AuthFrame(
      title: 'Complete your identity',
      children: [
        const AuthMessage(),
        Text(s.t('Choose your initial experience')),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _experience,
                decoration: InputDecoration(labelText: s.t('Experience')),
                items: [
                  for (final r in ['customer', 'baker'])
                    DropdownMenuItem(
                      value: r,
                      child: Text(s.t(r == 'customer' ? 'Customer' : 'Baker')),
                    ),
                ],
                onChanged: state.busy
                    ? null
                    : (v) => setState(() => _experience = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !state.busy,
                maxLength: 100,
                decoration: InputDecoration(labelText: s.t('Full name')),
                validator: (v) => validateName(v ?? '') == null
                    ? null
                    : s.t('Enter 1 to 100 characters'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                enabled: !state.busy,
                maxLength: 40,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: s.t('Phone (optional)')),
              ),
              const SizedBox(height: 16),
              if (_experience == 'baker') ...[
                TextFormField(
                  controller: _business,
                  enabled: !state.busy,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: s.t('Business name')),
                  validator: (v) => validateName(v ?? '') == null
                      ? null
                      : s.t('Enter 1 to 100 characters'),
                ),
                Text(
                  s.t(
                    'This creates a private draft. Full bakery setup arrives in Phase 3.',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: state.busy
                    ? null
                    : () {
                        if (_form.currentState!.validate()) {
                          controller.completeIdentity(
                            _experience,
                            _name.text,
                            _phone.text,
                            _business.text,
                          );
                        }
                      },
                child: Text(s.t(state.busy ? 'Saving...' : 'Continue')),
              ),
              TextButton(
                onPressed: state.busy ? null : controller.logout,
                child: Text(s.t('Log out')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
