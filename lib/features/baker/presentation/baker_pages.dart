import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/backend_config.dart';
import '../../../shared/widgets/controls.dart';
import '../../auth/application/auth_controller.dart';
import '../application/baker_providers.dart';
import '../data/baker_repository.dart';
import '../domain/baker_workspace.dart';

class BakerDirty extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final bakerDirtyProvider = NotifierProvider<BakerDirty, bool>(BakerDirty.new);
Future<bool> confirmBakerExit(
  BuildContext context, {
  required bool dirty,
  required VoidCallback discarded,
}) async {
  if (!dirty) return true;
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard unsaved changes?'),
      content: const Text(
        'Save your draft before leaving to keep these changes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  if (leave == true) discarded();
  return leave == true;
}

class BakerPage extends ConsumerWidget {
  const BakerPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(backendConfigProvider).isPreview;
    final identity = preview
        ? 'preview'
        : ref.watch(authControllerProvider).identity?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baker workspace'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('${preview ? '' : '/live'}/baker/today'),
        ),
      ),
      body: SafeArea(
        child: ref
            .watch(bakerWorkspaceProvider)
            .when(
              data: (w) => BakerEditor(key: ValueKey(identity), initial: w),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(bakerError(e)),
                      FilledButton(
                        onPressed: () => ref.invalidate(bakerWorkspaceProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
      ),
    );
  }
}

class BakerEditor extends ConsumerStatefulWidget {
  const BakerEditor({required this.initial, super.key});
  final BakerWorkspace initial;
  @override
  ConsumerState<BakerEditor> createState() => _BakerEditorState();
}

class _BakerEditorState extends ConsumerState<BakerEditor> {
  late BakerWorkspace w;
  bool busy = false, dirty = false;
  String section = 'Setup', message = '', stage = '';
  @override
  void initState() {
    super.initState();
    w = widget.initial.copy();
    Future.microtask(() {
      if (mounted) ref.read(bakerDirtyProvider.notifier).set(false);
    });
  }

  void changed() {
    dirty = true;
    ref.read(bakerDirtyProvider.notifier).set(true);
    setState(() {});
  }

  Future<void> perform(
    Future<BakerWorkspace> Function(BakerRepository) action, {
    String success = 'Saved',
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final repo = await ref.read(bakerRepositoryProvider.future);
      final result = await action(repo);
      if (!mounted) return;
      setState(() {
        w = result;
        dirty = false;
        message = success;
      });
      ref.read(bakerDirtyProvider.notifier).set(false);
    } catch (e) {
      if (mounted) setState(() => message = bakerError(e));
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          stage = '';
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(message),
            ),
          );
      }
    }
  }

  Future<void> save() async =>
      perform((repo) => repo.save(w.copy()), success: 'Draft saved');
  Future<void> reviewActivate() async {
    if (dirty) {
      setState(() => message = 'Save your draft before activation.');
      return;
    }
    if (w.setupIssues.isNotEmpty) {
      setState(() => message = w.setupIssues.join('. '));
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Activate this business?'),
        content: const Text(
          'Your business name, description, location, code and public images become publicly readable. Owner contact details and the exact pickup address remain private.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await perform((repo) => repo.activate(w), success: 'Business activated');
    }
  }

  Future<void> pickImage(
    String slot, [
    String? productId,
    Uint8List? retryBytes,
  ]) async {
    if (busy) return;
    if (dirty) {
      setState(() => message = 'Save the draft before changing images.');
      return;
    }
    setState(() => busy = true);
    Uint8List? bytes = retryBytes;
    try {
      if (bytes == null) {
        final selected = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (selected == null) return;
        if (await selected.length() > 5 * 1024 * 1024) {
          throw const FormatException('Choose an image up to 5 MB');
        }
        bytes = await selected.readAsBytes();
      }
      if (!mounted) return;
      final repo = await ref.read(bakerRepositoryProvider.future);
      final result = await repo.image(w, slot, productId, bytes, (s) {
        if (mounted) setState(() => stage = s);
      });
      if (mounted) {
        setState(() {
          w = result;
          message = 'Image saved';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = bakerError(e));
        final retained = bytes;
        if (retained != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image could not be saved'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => pickImage(slot, productId, retained),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          stage = '';
        });
      }
    }
  }

  Widget field(
    Json record,
    String key,
    String label, {
    int max = 100,
    int lines = 1,
    bool currency = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('${record['id'] ?? w.id}-$key'),
      initialValue: currency && record[key] is int
          ? pkrInput(record[key])
          : '${record[key] ?? ''}',
      enabled: !busy,
      maxLength: currency || number ? null : max,
      maxLines: lines,
      keyboardType: currency
          ? const TextInputType.numberWithOptions(decimal: true)
          : number
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        if (currency || number) {
          try {
            record[key] = currency ? parsePkr(v) : int.parse(v);
            message = '';
          } catch (_) {
            record[key] = v;
          }
        } else {
          record[key] = v;
        }
        changed();
      },
    ),
  );
  Widget imageControl(String slot, String? path, [String? productId]) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        slot == 'profile'
            ? 'Public logo'
            : slot == 'cover'
            ? 'Public cover'
            : 'Public product image',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (path != null) ...[
        const SizedBox(height: 8),
        if (path.startsWith('data:'))
          Image.memory(
            base64Decode(path.split(',').last),
            height: 150,
            fit: BoxFit.contain,
          )
        else
          FutureBuilder<BakerRepository>(
            future: ref.read(bakerRepositoryProvider.future),
            builder: (c, s) => s.hasData
                ? Image.network(
                    s.data!.imageUrl(path, slot),
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Text('Image could not be loaded'),
                  )
                : const LinearProgressIndicator(),
          ),
      ],
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: busy ? null : () => pickImage(slot, productId),
            child: Text(path == null ? 'Choose image' : 'Replace image'),
          ),
          if (path != null)
            TextButton(
              onPressed: busy
                  ? null
                  : () => perform(
                      (repo) => repo.image(w, slot, productId, null, (_) {}),
                    ),
              child: const Text('Remove image'),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(backendConfigProvider).isPreview;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop &&
            await confirmBakerExit(
              context,
              dirty: dirty,
              discarded: () => ref.read(bakerDirtyProvider.notifier).set(false),
            ) &&
            context.mounted) {
          context.go('${preview ? '' : '/live'}/baker/today');
        }
      },
      child: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (preview)
              const Text(
                'Preview workspace • saved on this device only. No live account or backend writes.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            Text(
              w.active ? 'Active business' : 'Business draft',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              w.setupIssues.isEmpty
                  ? 'Ready for review'
                  : '${w.setupIssues.length} setup items remaining',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in [
                  'Setup',
                  'Catalog',
                  'Fulfilment',
                  'Pricing',
                  'Review',
                ])
                  ChoiceChip(
                    label: Text(s),
                    selected: section == s,
                    onSelected: (_) => setState(() => section = s),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (busy) ...[
              const LinearProgressIndicator(),
              Text(stage.isEmpty ? 'Saving...' : stage),
            ],
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(message, semanticsLabel: message),
              ),
            if (section == 'Setup') ...[
              field(w.business, 'name', 'Business name'),
              field(
                w.business,
                'description',
                'Business description',
                max: 2000,
                lines: 4,
              ),
              field(w.business, 'owner_name', 'Owner / contact name'),
              field(w.business, 'contact_phone', 'Contact phone', max: 40),
              field(w.business, 'location', 'Public location / area', max: 200),
              field(
                w.business,
                'pickup_address',
                'Private pickup address',
                max: 500,
                lines: 3,
              ),
              const Text(
                'Contact name, phone and exact pickup address are private. Public images must not include private details.',
              ),
              const SizedBox(height: 16),
              imageControl('profile', w.business['image_path']),
              imageControl('cover', w.business['cover_path']),
              const Text(
                'JPEG, PNG or WebP • up to 5 MB. Save details before uploading.',
              ),
            ],
            if (section == 'Catalog') ...[
              const Text(
                'Sizes are cake weights in grams or cupcake counts per pack. Option prices apply once per ordered cake/pack. Each product has its own applicable options.',
              ),
              const SizedBox(height: 12),
              if (w.products.isEmpty)
                const Text(
                  'No products yet. Add your first cake or cupcake pack.',
                ),
              for (final p in w.products) ...[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        p['name'],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${p['kind']} • ${p['active'] ? 'Active' : 'Inactive'}',
                      ),
                      Text(p['description']),
                      OutlinedButton(
                        onPressed: () => editProduct(p),
                        child: const Text('Edit product'),
                      ),
                      imageControl('product', p['image_path'], p['id']),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: () => editProduct(null),
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
            ],
            if (section == 'Fulfilment') ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pickup available'),
                value: w.business['pickup_enabled'],
                onChanged: (v) {
                  w.business['pickup_enabled'] = v;
                  changed();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Delivery available'),
                value: w.business['delivery_enabled'],
                onChanged: (v) {
                  w.business['delivery_enabled'] = v;
                  changed();
                },
              ),
              field(
                w.business,
                'minimum_paisa',
                'Minimum product subtotal (PKR)',
                currency: true,
              ),
              const Text(
                'The minimum excludes delivery. A zone is selected explicitly; automatic geographic matching belongs to a later customer workflow.',
              ),
              for (final z in w.zones) ...[
                const Divider(),
                field(z, 'name', 'Delivery zone name'),
                field(z, 'fee_paisa', 'Delivery fee (PKR)', currency: true),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Zone active'),
                  value: z['active'],
                  onChanged: (v) {
                    z['active'] = v;
                    changed();
                  },
                ),
              ],
              OutlinedButton(
                onPressed: () {
                  w.zones.add({
                    'id': const Uuid().v4(),
                    'name': '',
                    'fee_paisa': 0,
                    'active': true,
                  });
                  changed();
                },
                child: const Text('Add delivery zone'),
              ),
            ],
            if (section == 'Pricing') PricingPanel(workspace: w, dirty: dirty),
            if (section == 'Review') ...[
              Text(
                w.business['name'],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(w.business['description']),
              Text('Public area: ${w.business['location']}'),
              Text(
                'Pickup: ${w.business['pickup_enabled'] ? 'Available' : 'Unavailable'} • Delivery: ${w.business['delivery_enabled'] ? 'Available' : 'Unavailable'}',
              ),
              Text(
                '${w.products.where((p) => p['active'] == true).length} active products',
              ),
              for (final issue in w.setupIssues) Text('• $issue'),
              const SizedBox(height: 16),
              SelectableText('Business code: ${w.business['code']}'),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: w.business['code']),
                      );
                      if (mounted) {
                        setState(() => message = 'Business code copied');
                      }
                    },
                    child: const Text('Copy code'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        if (kIsWeb) {
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${w.business['name']} — BakeQuote code ${w.business['code']}',
                            ),
                          );
                        } else {
                          await const MethodChannel(
                            'dev.bakequote/share',
                          ).invokeMethod(
                            'share',
                            '${w.business['name']} — BakeQuote code ${w.business['code']}',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () =>
                                message = 'Sharing unavailable. Use Copy code.',
                          );
                        }
                      }
                    },
                    child: const Text('Share code'),
                  ),
                ],
              ),
              const Text(
                'Draft codes are not discoverable. Activation publishes only approved business fields; customer lookup is Phase 4.',
              ),
              if (!w.active)
                FilledButton(
                  onPressed: reviewActivate,
                  child: const Text('Review and activate'),
                ),
              OutlinedButton(
                onPressed: () async {
                  if (dirty) {
                    setState(
                      () => message = 'Save or discard edits before reopening.',
                    );
                    return;
                  }
                  await perform(
                    (repo) => repo.load(),
                    success: 'Saved workspace reopened',
                  );
                },
                child: const Text('Reopen saved workspace'),
              ),
              OutlinedButton(
                onPressed: () async {
                  try {
                    final n = await (await ref.read(
                      bakerRepositoryProvider.future,
                    )).retryCleanup();
                    if (mounted) {
                      setState(
                        () => message = n == 0
                            ? 'Image cleanup complete'
                            : '$n image cleanups remain. Retry when connected.',
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => message = bakerError(e));
                  }
                },
                child: const Text('Retry image cleanup'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: save,
              child: Text(dirty ? 'Save draft changes' : 'Save draft'),
            ),
            if (preview)
              TextButton(
                onPressed: loadExample,
                child: const Text('Load PKR 4,100 example (preview only)'),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> editProduct(Json? p) async {
    final result = await Navigator.of(
      context,
    ).push<Json>(MaterialPageRoute(builder: (_) => ProductEditor(product: p)));
    if (result != null && mounted) {
      final index = w.products.indexWhere((p) => p['id'] == result['id']);
      if (index < 0) {
        w.products.add(result);
      } else {
        w.products[index] = result;
      }
      changed();
    }
  }

  void loadExample() {
    final pid = const Uuid().v4();
    w = BakerWorkspace(
      {
        ...w.business,
        'name': 'Example bakery',
        'description': 'Example pricing fixture only',
        'owner_name': 'Example owner',
        'contact_phone': 'Example contact',
        'location': 'Example area',
        'pickup_address': 'Example pickup address',
        'pickup_enabled': true,
        'delivery_enabled': true,
        'minimum_paisa': 0,
      },
      [
        {
          'id': pid,
          'name': 'Example cake',
          'description': 'PKR 4,100 regression example',
          'kind': 'cake',
          'active': true,
          'minimum_quantity': 1,
          'image_path': null,
          'variants': [
            {
              'id': const Uuid().v4(),
              'label': '2 lb cake',
              'units': 907,
              'price_paisa': 300000,
              'active': true,
            },
          ],
          'options': [
            {
              'id': const Uuid().v4(),
              'kind': 'finish',
              'label': 'Buttercream',
              'price_paisa': 50000,
              'active': true,
            },
            {
              'id': const Uuid().v4(),
              'kind': 'extra',
              'label': 'Topper',
              'price_paisa': 30000,
              'active': true,
            },
          ],
        },
      ],
      [
        {
          'id': const Uuid().v4(),
          'name': 'Example delivery',
          'fee_paisa': 30000,
          'active': true,
        },
      ],
    );
    section = 'Pricing';
    changed();
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({this.product, super.key});
  final Json? product;
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  late Json p;
  late String original;
  String error = '';
  bool leaving = false;
  @override
  void initState() {
    super.initState();
    p = widget.product == null
        ? {
            'id': const Uuid().v4(),
            'name': '',
            'description': '',
            'kind': 'cake',
            'active': false,
            'minimum_quantity': 1,
            'image_path': null,
            'variants': <Json>[],
            'options': <Json>[],
          }
        : jsonDecode(jsonEncode(widget.product));
    original = jsonEncode(p);
  }

  Widget field(
    Json row,
    String key,
    String label, {
    bool price = false,
    bool number = false,
    int max = 100,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      initialValue: price
          ? pkrInput(row[key] is int ? row[key] : 0)
          : '${row[key] ?? ''}',
      key: ValueKey('${row['id']}-$key'),
      maxLength: price || number ? null : max,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      keyboardType: price
          ? const TextInputType.numberWithOptions(decimal: true)
          : number
          ? TextInputType.number
          : TextInputType.text,
      onChanged: (v) {
        if (price || number) {
          try {
            row[key] = price ? parsePkr(v) : int.parse(v);
          } catch (_) {
            row[key] = v;
          }
        } else {
          row[key] = v;
        }
        setState(() {});
      },
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || jsonEncode(p) == original,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Discard product edits?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (yes == true && context.mounted) {
        setState(() => leaving = true);
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            field(p, 'name', 'Product name'),
            field(p, 'description', 'Product description', max: 2000, lines: 3),
            DropdownButtonFormField<String>(
              initialValue: p['kind'],
              decoration: const InputDecoration(labelText: 'Product type'),
              items: const [
                DropdownMenuItem(value: 'cake', child: Text('Cake')),
                DropdownMenuItem(value: 'cupcakes', child: Text('Cupcakes')),
              ],
              onChanged: (v) => setState(() => p['kind'] = v),
            ),
            field(
              p,
              'minimum_quantity',
              'Minimum cakes / packs per order',
              number: true,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Product active'),
              value: p['active'],
              onChanged: (v) => setState(() => p['active'] = v),
            ),
            const Text(
              'Deactivate to preserve references. Existing orders will use immutable snapshots when ordering is introduced.',
            ),
            const SizedBox(height: 20),
            Text(
              p['kind'] == 'cake' ? 'Cake sizes' : 'Cupcake packs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final v in rows(p['variants'])) option(v, true),
            OutlinedButton(
              onPressed: () => setState(
                () => p['variants'].add({
                  'id': const Uuid().v4(),
                  'label': '',
                  'units': 1,
                  'price_paisa': 0,
                  'active': true,
                }),
              ),
              child: const Text('Add size / pack'),
            ),
            const SizedBox(height: 20),
            Text(
              'Applicable customizations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final o in rows(p['options'])) option(o, false),
            for (final kind in ['flavour', 'finish', 'extra'])
              OutlinedButton(
                onPressed: () => setState(
                  () => p['options'].add({
                    'id': const Uuid().v4(),
                    'label': '',
                    'kind': kind,
                    'price_paisa': 0,
                    'active': true,
                  }),
                ),
                child: Text('Add $kind'),
              ),
            const Text(
              'Select at most one flavour and finish; extras are optional one-per-cake/pack additions. Custom designs are manually quoted in Phase 6; no automatic design fee is invented.',
            ),
            if (error.isNotEmpty) Text(error),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                try {
                  validateProduct(p);
                  setState(() => leaving = true);
                  Navigator.pop(context, p);
                } catch (e) {
                  setState(() => error = bakerError(e));
                }
              },
              child: const Text('Use product changes'),
            ),
            const Text('Changes are saved with Save draft in the workspace.'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
  Widget option(Json copy, bool variant) {
    // rows() produces copies; edit the actual owned option so changes survive rebuilds.
    final list = p[variant ? 'variants' : 'options'] as List;
    final o = list.firstWhere((v) => v['id'] == copy['id']) as Json;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field(
            o,
            'label',
            variant ? 'Size / pack label' : '${o['kind']} name',
          ),
          if (variant)
            field(
              o,
              'units',
              p['kind'] == 'cake' ? 'Weight (grams)' : 'Cupcakes per pack',
              number: true,
            ),
          field(
            o,
            'price_paisa',
            variant ? 'Base price (PKR)' : 'Additional price (PKR)',
            price: true,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Option active'),
            value: o['active'],
            onChanged: (v) => setState(() => o['active'] = v),
          ),
        ],
      ),
    );
  }
}

class PricingPanel extends ConsumerStatefulWidget {
  const PricingPanel({required this.workspace, required this.dirty, super.key});
  final BakerWorkspace workspace;
  final bool dirty;
  @override
  ConsumerState<PricingPanel> createState() => _PricingPanelState();
}

class _PricingPanelState extends ConsumerState<PricingPanel> {
  String? product, variant, zone;
  final options = <String>[];
  int quantity = 1;
  String result = '';
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final w = widget.workspace,
        products = w.products.where((p) => p['active'] == true).toList();
    final p = products.where((p) => p['id'] == product).firstOrNull;
    final variants = p == null
        ? <Json>[]
        : rows(p['variants']).where((v) => v['active'] == true).toList();
    String local = 'Choose a product and size / pack';
    if (p != null && variant != null) {
      try {
        final e = previewEstimate(
          w,
          product!,
          variant!,
          options,
          quantity,
          zone,
        );
        local =
            'Product subtotal: ${pkr(e['subtotal_paisa'])}\nDelivery: ${pkr(e['delivery_paisa'])}\nEstimated total: ${pkr(e['total_paisa'])}';
      } catch (e) {
        local = bakerError(e);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'All prices are PKR. The live server calculates estimates from saved catalog data; this screen does not create an order or charge.',
        ),
        const SizedBox(height: 16),
        if (products.isEmpty)
          const Text(
            'Add an active product with a size / pack to preview pricing.',
          ),
        DropdownButtonFormField<String>(
          initialValue: p == null ? null : product,
          decoration: const InputDecoration(labelText: 'Product'),
          isExpanded: true,
          items: [
            for (final p in products)
              DropdownMenuItem(
                value: p['id'] as String,
                child: Text(p['name']),
              ),
          ],
          onChanged: (v) => setState(() {
            product = v;
            variant = null;
            options.clear();
            result = '';
          }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(product),
          initialValue: variants.any((v) => v['id'] == variant)
              ? variant
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Size / pack'),
          items: [
            for (final v in variants)
              DropdownMenuItem(
                value: v['id'] as String,
                child: Text('${v['label']} • ${pkr(v['price_paisa'])}'),
              ),
          ],
          onChanged: (v) => setState(() => variant = v),
        ),
        if (p != null)
          for (final o in rows(p['options']).where((o) => o['active'] == true))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${o['label']} (${o['kind']}) +${pkr(o['price_paisa'])}',
              ),
              value: options.contains(o['id']),
              onChanged: (v) => setState(() {
                if (v == true) {
                  if (o['kind'] != 'extra') {
                    final same = rows(p['options'])
                        .where((other) => other['kind'] == o['kind'])
                        .map((o) => o['id']);
                    options.removeWhere(same.contains);
                  }
                  options.add(o['id']);
                } else {
                  options.remove(o['id']);
                }
              }),
            ),
        TextFormField(
          initialValue: '1',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of cakes / packs',
          ),
          onChanged: (v) => setState(() => quantity = int.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: 'pickup',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Fulfilment'),
          items: [
            const DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
            for (final z in w.zones.where((z) => z['active'] == true))
              DropdownMenuItem(
                value: z['id'] as String,
                child: Text('${z['name']} • ${pkr(z['fee_paisa'])}'),
              ),
          ],
          onChanged: (v) => setState(() => zone = v == 'pickup' ? null : v),
        ),
        const SizedBox(height: 16),
        Text(local, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy || widget.dirty || p == null || variant == null
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final repo = await ref.read(bakerRepositoryProvider.future);
                    final e = await repo.estimate(
                      w,
                      product!,
                      variant!,
                      options,
                      quantity,
                      zone,
                    );
                    if (mounted) {
                      setState(
                        () => result =
                            '${ref.read(backendConfigProvider).isPreview ? 'Device preview' : 'Backend estimate'}: ${pkr(e['total_paisa'])}',
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => result = bakerError(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Calculating...' : 'Check saved pricing'),
        ),
        if (widget.dirty)
          const Text('Save draft changes before checking saved pricing.'),
        if (result.isNotEmpty) Text(result),
      ],
    );
  }
}
