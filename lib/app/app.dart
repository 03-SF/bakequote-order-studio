import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../features/preview/presentation/preview_pages.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      for (final role in ['customer', 'baker'])
        ShellRoute(
          builder: (context, state, child) =>
              PreviewShell(role: role, path: state.uri.path, child: child),
          routes: [
            for (final view
                in role == 'customer'
                    ? ['home', 'orders', 'messages', 'account']
                    : ['today', 'calendar', 'orders', 'messages', 'account'])
              GoRoute(
                path: '/$role/$view',
                builder: (context, state) =>
                    PreviewPage(role: role, view: view),
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
  ref.onDispose(router.dispose);
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
