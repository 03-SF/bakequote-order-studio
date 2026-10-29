import 'package:flutter/material.dart';
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
import '../features/baker/presentation/baker_pages.dart';
import '../features/discovery/domain/discovery.dart';
import '../features/requests/requests.dart';
import '../features/availability/application/availability_controller.dart';

class AuthRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final preview = ref.watch(backendConfigProvider).isPreview;
  final refresh = AuthRouterRefresh();
  String? pendingBakery;
  ref.listen(authControllerProvider, (previous, next) {
    if (previous?.identity?.id != next.identity?.id) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    refresh.refresh();
  });
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (!preview &&
          auth.phase != AuthPhase.signedIn &&
          state.uri.path == '/live/customer/home') {
        pendingBakery ??= bakeryCode(state.uri.queryParameters['bakery'] ?? '');
      }
      if (!preview && state.uri.path.startsWith('/bakery/')) {
        pendingBakery = bakeryCode(
          state.pathParameters['code'] ??
              state.uri.path.substring('/bakery/'.length),
        );
      }
      final redirect = authRedirect(auth, state.uri.path, preview: preview);
      if (!preview &&
          auth.phase == AuthPhase.signedIn &&
          auth.profile?.experience == 'customer' &&
          pendingBakery != null) {
        final code = pendingBakery!;
        pendingBakery = null;
        return '/live/customer/home?bakery=$code';
      }
      if (!preview && state.uri.path.startsWith('/bakery/')) {
        return redirect ?? '/auth/login';
      }
      return redirect;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      if (!preview)
        GoRoute(
          path: '/live/customer/request/:business/:product',
          builder: (context, state) => RequestBuilderPage(
            business: state.pathParameters['business']!,
            product: state.pathParameters['product']!,
          ),
        ),
      if (!preview)
        for (final role in ['customer', 'baker'])
          GoRoute(
            path: '/live/$role/requests/:id',
            builder: (context, state) =>
                RequestDetailsPage(state.pathParameters['id']!),
          ),
      GoRoute(
        path: '/bakery/:code',
        builder: (context, state) => const WelcomePage(),
      ),
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
      GoRoute(
        path: '${preview ? '' : '/live'}/baker/setup',
        builder: (context, state) => const BakerPage(),
        onExit: (context, state) =>
            !preview &&
                ref.read(authControllerProvider).phase != AuthPhase.signedIn
            ? true
            : confirmBakerExit(
                context,
                dirty: ref.read(bakerDirtyProvider),
                discarded: () =>
                    ref.read(bakerDirtyProvider.notifier).set(false),
              ),
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
                    : LivePage(
                        view: view,
                        initialCode: bakeryCode(
                          state.uri.queryParameters['bakery'] ?? '',
                        ),
                      ),
                onExit: (context, state) =>
                    !preview &&
                        view == 'calendar' &&
                        ref.read(authControllerProvider).phase ==
                            AuthPhase.signedIn
                    ? confirmBakerExit(
                        context,
                        dirty: ref.read(availabilityDirtyProvider),
                        discarded: () => ref
                            .read(availabilityDirtyProvider.notifier)
                            .set(false),
                      )
                    : true,
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
    return MaterialApp.router(
      title: 'BakeQuote',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      theme: bakeTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
