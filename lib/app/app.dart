import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/config/backend_config.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../features/preview/presentation/preview_pages.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/presentation/auth_pages.dart';
import '../features/auth/presentation/live_pages.dart';

class AuthRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final preview = ref.watch(backendConfigProvider).isPreview;
  final refresh = AuthRouterRefresh();
  ref.listen(authControllerProvider, (previous, next) {
    if (previous?.identity?.id != next.identity?.id) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    refresh.refresh();
  });
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      ref.read(authControllerProvider),
      state.uri.path,
      preview: preview,
    ),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      for (final view in [
        'loading',
        'session-error',
        'login',
        'register',
        'forgot',
        'verify',
        'reset',
      ])
        GoRoute(
          path: '/auth/$view',
          builder: (context, state) =>
              AuthPage(key: ValueKey(view), view: view),
        ),
      GoRoute(
        path: '/auth/onboarding',
        builder: (context, state) => const IdentityPage(),
      ),
      for (final role in ['customer', 'baker'])
        ShellRoute(
          builder: (context, state, child) => PreviewShell(
            role: role,
            path: state.uri.path.replaceFirst('/live', ''),
            routePrefix: preview ? '' : '/live',
            onExit: preview
                ? null
                : () {
                    if (!ref.read(authControllerProvider).busy) {
                      ref.read(authControllerProvider.notifier).logout();
                    }
                  },
            exitLabel: preview ? null : 'Log out',
            child: child,
          ),
          routes: [
            for (final view
                in role == 'customer'
                    ? ['home', 'orders', 'messages', 'account']
                    : ['today', 'calendar', 'orders', 'messages', 'account'])
              GoRoute(
                path: '${preview ? '' : '/live'}/$role/$view',
                builder: (context, state) => preview
                    ? PreviewPage(role: role, view: view)
                    : LivePage(view: view),
              ),
          ],
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: Text(AppStrings.of(context).t('Back to welcome')),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class BakeQuoteApp extends ConsumerWidget {
  const BakeQuoteApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'BakeQuote',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: bakeTheme(urdu: locale.languageCode == 'ur'),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
