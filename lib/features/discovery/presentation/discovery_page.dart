import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../application/discovery_controller.dart';
import '../domain/discovery.dart';
import '../../availability/availability.dart';

class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({this.initialCode, super.key});
  final String? initialCode;
  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage> {
  final _code = TextEditingController();
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(discoveryControllerProvider.notifier).loadSaved();
      if (!mounted) return;
      await ref.read(discoveryControllerProvider.notifier).loadRecent();
      if (!mounted) return;
      if (widget.initialCode != null) {
        _code.text = widget.initialCode!;
        await ref.read(discoveryControllerProvider.notifier).lookup(_code.text);
        return;
      }
      final uri = await ref.read(initialAuthLinkProvider);
      if (!mounted || uri == null) return;
      final code = bakeryCode(uri.toString());
      if (code != null) {
        _code.text = code;
        await ref.read(discoveryControllerProvider.notifier).lookup(code);
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Widget _image(String? url, String label) => url == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Image.network(
            url,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: label,
            errorBuilder: (_, _, _) => const Text('Image unavailable'),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryControllerProvider);
    final controller = ref.read(discoveryControllerProvider.notifier);
    final bakery = state.bakery;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Find a bakery', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          enabled: !state.busy,
          decoration: const InputDecoration(
            labelText: 'Bakery code or shared link',
          ),
          onSubmitted: (_) => controller.lookup(_code.text),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: state.busy ? null : () => controller.lookup(_code.text),
          child: const Text('Find bakery'),
        ),
        if (state.busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
        if (state.message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(state.message!)),
          ),
        if (bakery != null) ...[
          const SizedBox(height: 20),
          Text(bakery.name, style: Theme.of(context).textTheme.headlineMedium),
          _image(bakery.coverUrl ?? bakery.imageUrl, '${bakery.name} image'),
          Text(bakery.description),
          const SizedBox(height: 8),
          Text(bakery.location),
          for (final zone in bakery.deliveryZones)
            Text('Delivery: ${zone.label} — ${paisaText(zone.price)}'),
          Text('Minimum product subtotal: ${paisaText(bakery.minimum)}'),
          Text(
            '${bakery.pickup ? 'Pickup available' : 'No pickup'} · ${bakery.delivery ? 'Delivery available' : 'No delivery'}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: state.busy
                    ? null
                    : () => controller.setSaved(bakery.id, !state.isSaved),
                child: Text(
                  state.isSaved ? 'Remove saved bakery' : 'Save bakery',
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: kIsWeb
                          ? 'http://localhost:7357/#/bakery/${bakery.code}'
                          : bakery.sharedLink,
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bakery link copied')),
                    );
                  }
                },
                child: const Text('Copy bakery link'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Menu', style: Theme.of(context).textTheme.titleLarge),
          if (state.products.isEmpty) const Text('No available products yet.'),
          for (final product in state.products)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _image(product.imageUrl, product.name),
                    Text(product.description),
                    FilledButton.tonal(
                      onPressed: () => context.push(
                        '/live/customer/request/${bakery.id}/${product.id}',
                      ),
                      child: const Text('Customize request'),
                    ),
                    if (product.startingPrice != null)
                      Text(
                        'From ${paisaText(product.startingPrice!)} before customizations and delivery',
                      ),
                    Text(
                      '${product.kind == 'cake' ? 'Cake' : 'Cupcakes'} · Minimum ${product.minimumQuantity} cake(s) / pack(s)',
                    ),
                    for (final choice in product.choices)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${choice.kind}: ${choice.label} — ${paisaText(choice.price)}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (state.moreMenu)
            TextButton(
              onPressed: state.busy ? null : controller.moreProducts,
              child: const Text('Load more products'),
            ),
          AvailabilityPanel(key: ValueKey(bakery.id), code: bakery.code),
          const Text('Reviews are not available yet.'),
        ],
        const SizedBox(height: 24),
        Text(
          'Recently opened bakeries',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextButton(
          onPressed: state.busy ? null : controller.loadRecent,
          child: const Text('Refresh recent bakeries'),
        ),
        if (state.recent.isEmpty)
          const Text('No recently opened bakeries loaded.'),
        for (final recent in state.recent)
          ListTile(
            title: Text(recent.profile?.name ?? 'Bakery currently unavailable'),
            trailing: recent.profile == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: state.busy || recent.profile == null
                ? null
                : () {
                    _code.text = recent.profile!.code;
                    controller.lookup(_code.text);
                  },
          ),
        const SizedBox(height: 24),
        Text(
          'Saved bakeries',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextButton(
          onPressed: state.busy ? null : () => controller.loadSaved(),
          child: const Text('Refresh saved bakeries'),
        ),
        if (state.saved.isEmpty)
          const Text('No saved bakeries loaded. Find a bakery using its code.'),
        for (final saved in state.saved)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(saved.profile?.name ?? 'Bakery currently unavailable'),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (saved.profile != null)
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () {
                                  _code.text = saved.profile!.code;
                                  controller.lookup(_code.text);
                                },
                          child: const Text('View menu'),
                        ),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => controller.setSaved(saved.id, false),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (state.moreSaved)
          TextButton(
            onPressed: state.busy
                ? null
                : () => controller.loadSaved(more: true),
            child: const Text('Load more saved bakeries'),
          ),
      ],
    );
  }
}
