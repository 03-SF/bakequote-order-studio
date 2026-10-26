import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/controls.dart';
import '../data/preview_repository.dart';

class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () => ref.read(localeProvider.notifier).toggle(),
    child: Text(
      ref.watch(localeProvider).languageCode == 'en' ? 'اردو' : 'English',
    ),
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/bakery-hero.jpg',
                      height: 240,
                      fit: BoxFit.cover,
                      semanticLabel: s.t('Sample bakery'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    s.t('Made with care. Ordered with confidence.'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(s.t('A little sweetness, thoughtfully planned.')),
                  const SizedBox(height: 24),
                  const PreviewNotice(),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/customer/home'),
                    child: Text(s.t('Explore customer preview')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/baker/today'),
                    child: Text(s.t('Explore baker preview')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const navIcons = {
  'home': Icons.home_outlined,
  'orders': Icons.receipt_long_outlined,
  'messages': Icons.chat_bubble_outline,
  'account': Icons.person_outline,
  'today': Icons.wb_sunny_outlined,
  'calendar': Icons.calendar_month_outlined,
};
String titleFor(String view) => view[0].toUpperCase() + view.substring(1);

class PreviewShell extends StatelessWidget {
  const PreviewShell({
    required this.role,
    required this.path,
    required this.child,
    super.key,
  });
  final String role, path;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final views = role == 'customer'
        ? ['home', 'orders', 'messages', 'account']
        : ['today', 'calendar', 'orders', 'messages', 'account'];
    final index = views.indexWhere((view) => path == '/$role/$view');
    void navigate(int i) => context.go('/$role/${views[i]}');
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Scaffold(
          appBar: AppBar(
            title: const Wordmark(),
            actions: [
              IconButton(
                tooltip: s.t('Switch preview role'),
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.swap_horiz),
              ),
              const LanguageButton(),
            ],
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: index < 0 ? 0 : index,
                    onDestinationSelected: navigate,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final v in views)
                        NavigationRailDestination(
                          icon: Icon(navIcons[v]),
                          label: Text(s.t(titleFor(v))),
                        ),
                    ],
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: index < 0 ? 0 : index,
                  onDestinationSelected: navigate,
                  destinations: [
                    for (final v in views)
                      NavigationDestination(
                        icon: Icon(navIcons[v]),
                        label: s.t(titleFor(v)),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class PreviewPage extends ConsumerWidget {
  const PreviewPage({required this.role, required this.view, super.key});
  final String role, view;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final bakery = ref.watch(bakeryPreviewProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          s.t(titleFor(view)),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        const PreviewNotice(),
        const SizedBox(height: 20),
        if (view == 'home' || view == 'today') ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(role == 'baker' ? 'Your bakery' : 'Sample bakery'),
                  style: const TextStyle(color: BakeColors.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  bakery.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(s.t('Custom cakes & cupcakes, baked at home.')),
                const SizedBox(height: 8),
                Text(s.t('F-10, Islamabad')),
                const SizedBox(height: 8),
                Text('${s.t('Bakery code')}: ${bakery.code}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (role == 'customer') ...[
            Text(
              s.t('Find a bakery'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(s.t('Bakery access is planned for Phase 4.')),
            const SizedBox(height: 20),
            Text(
              s.t('Preview menu'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            for (final p in [
              ('cake-chocolate.jpg', 'Chocolate cake', 'From PKR 1,800'),
              ('cupcakes.jpg', 'Cupcakes', 'From PKR 1,500'),
            ]) ...[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/${p.$1}',
                        height: 140,
                        fit: BoxFit.cover,
                        semanticLabel: s.t(p.$2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.t(p.$2),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(s.t(p.$3)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ] else
            const SampleOrderCard(),
        ] else if (view == 'orders')
          const SampleOrderCard()
        else if (view == 'calendar')
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Order agenda'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(s.t('Calendar rules and date editing arrive in Phase 4.')),
              ],
            ),
          )
        else if (view == 'messages')
          SectionCard(
            child: Column(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  size: 40,
                  color: BakeColors.rose,
                ),
                const SizedBox(height: 16),
                Text(
                  s.t('No live conversations yet'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  s.t(
                    'Order messaging arrives in Phase 8. Chat never confirms an order.',
                  ),
                ),
              ],
            ),
          )
        else if (view == 'account')
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Preview profile'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(role == 'customer' ? 'Sara Ahmed' : 'Ayesha Siddiqui'),
                const SizedBox(height: 8),
                Text(
                  s.t(
                    'Real accounts arrive in Phase 2. No session is signed in.',
                  ),
                ),
                const SizedBox(height: 20),
                Text(s.t('Language')),
                const LanguageButton(),
                const Divider(),
                Text(
                  s.t(
                    ref.watch(backendConfigProvider).isConfigured
                        ? 'Configuration supplied • integration deferred to Phase 2'
                        : 'Backend not connected',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SampleOrderCard extends StatelessWidget {
  const SampleOrderCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('Sample orders'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'BQ-1042',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Chip(label: Text(s.t('Pending'))),
            ],
          ),
          Text(s.t('2 lb chocolate birthday cake')),
          const MoneyRow('Total', 4500),
          OutlinedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.t('Quotation v2'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const MoneyRow('Base cake', 3000),
                    const MoneyRow('Buttercream', 500),
                    const MoneyRow('Topper', 300),
                    const MoneyRow('Delivery', 300),
                    const MoneyRow('Custom design', 400),
                    const Divider(),
                    const MoneyRow('Total', 4500),
                    const MoneyRow('Advance recorded', 1500),
                    const MoneyRow('Balance due', 3000),
                    Text(
                      s.t(
                        'Sample amounts • payments received outside the app.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(s.t('Agreement and confirmation arrive in Phase 6.')),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(s.t('Close')),
                    ),
                  ],
                ),
              ),
            ),
            child: Text(s.t('View quotation')),
          ),
        ],
      ),
    );
  }
}
