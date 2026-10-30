import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../availability/availability.dart';
import '../application/request_controller.dart';
import '../domain/request.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order_rules.dart';
import '../../baker/data/baker_operations_repository.dart';
import '../../communication/presentation/order_communication_panel.dart';

String requestMoney(int p) =>
    'PKR ${p ~/ 100}.${(p % 100).toString().padLeft(2, '0')}';

class RequestImage extends ConsumerWidget {
  const RequestImage(this.path, {super.key});
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(requestImageProvider(path))
      .when(
        data: (url) => Image.network(
          url,
          height: 140,
          fit: BoxFit.contain,
          semanticLabel: 'Private design reference',
          errorBuilder: (_, _, _) =>
              const Text('Reference image unavailable. Refresh to retry.'),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(requestImageProvider(path)),
          child: const Text('Reference unavailable. Retry'),
        ),
      );
}

class EstimateView extends StatelessWidget {
  const EstimateView(this.estimate, {this.pending = true, super.key});
  final RequestEstimate estimate;
  final bool pending;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final l in estimate.lines)
        Text('${l.label}: ${requestMoney(l.amount)}'),
      Text('Product subtotal: ${requestMoney(estimate.subtotal)}'),
      Text('Delivery: ${requestMoney(estimate.delivery)}'),
      Text(
        'Estimated total: ${requestMoney(estimate.total)}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (pending)
        const Text(
          'This estimate is not a confirmation. The baker must issue an exact quote before production can be confirmed.',
        ),
    ],
  );
}

class RequestBuilderPage extends ConsumerStatefulWidget {
  const RequestBuilderPage({
    required this.business,
    required this.product,
    super.key,
  });
  final String business, product;
  @override
  ConsumerState<RequestBuilderPage> createState() => _RequestBuilderPageState();
}

class _RequestBuilderPageState extends ConsumerState<RequestBuilderPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(requestControllerProvider.notifier)
          .open(widget.business, widget.product),
    );
  }

  Future<void> pick() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const RequestFailure('Choose an image up to 5 MiB.');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        await ref.read(requestControllerProvider.notifier).upload(bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image could not be selected. Choose JPEG, PNG or WebP up to 5 MiB.',
            ),
          ),
        );
      }
    }
  }

  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep draft'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(requestControllerProvider),
        c = ref.read(requestControllerProvider.notifier),
        d = s.draft,
        catalog = s.catalog;
    final x = d?.input ?? const RequestInput(productId: '');
    final locked = s.busy || s.uncertain || s.orderId != null;
    Widget field(
      String label,
      String value,
      void Function(String) change, {
      int? max,
      int lines = 1,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        key: ValueKey('$label:${d?.id}:${d?.revision}:${s.formRevision}'),
        initialValue: value,
        enabled: !locked,
        maxLength: max,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
        onChanged: change,
      ),
    );
    Widget choice(
      String label,
      List<RequestChoice> values,
      String selected,
      void Function(String) change,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$selected'),
        initialValue: values.any((v) => v.id == selected) ? selected : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final v in values)
            DropdownMenuItem(
              value: v.id,
              child: Text(
                '${v.label} (${requestMoney(v.price)})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: locked
            ? null
            : (v) {
                if (v != null) change(v);
              },
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Order request')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Step ${s.step + 1} of 4 · ${['Product and customization', 'Date and fulfilment', 'Contact and design', 'Review and submit'][s.step]}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          LinearProgressIndicator(value: s.busy ? null : (s.step + 1) / 4),
          if (s.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(liveRegion: true, child: Text(s.message!)),
            ),
          if (d == null)
            TextButton(
              onPressed: s.busy
                  ? null
                  : () => c.open(widget.business, widget.product),
              child: const Text('Load / retry draft'),
            ),
          if (s.orderId != null)
            FilledButton(
              onPressed: () =>
                  context.go('/live/customer/requests/${s.orderId}'),
              child: const Text('Open saved Pending request'),
            ),
          if (s.orderId != null)
            OutlinedButton(
              onPressed: s.busy
                  ? null
                  : () => c.newDraft(widget.business, widget.product),
              child: const Text('Start another request'),
            ),
          if (s.uncertain) ...[
            const Text(
              'Submission outcome is uncertain. Keep this draft unchanged while checking or retrying the same submission.',
            ),
            FilledButton(
              onPressed: s.busy ? null : c.checkOutcome,
              child: const Text('Check submission status'),
            ),
            OutlinedButton(
              onPressed: s.busy ? null : c.submit,
              child: const Text('Retry same submission'),
            ),
          ],
          if (d != null && s.orderId == null && !s.uncertain) ...[
            const Text(
              'Unsent draft · account and bakery scoped. Edits are kept locally; Save draft synchronizes them. No offline submission queue.',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: locked ? null : c.save,
                  child: const Text('Save draft'),
                ),
                TextButton(
                  onPressed: locked
                      ? null
                      : () async {
                          if (await confirm(
                            'Replace local edits with the server draft?',
                          )) {
                            await c.reload();
                          }
                        },
                  child: const Text('Reload server draft'),
                ),
                TextButton(
                  onPressed: locked ? null : c.refreshCatalog,
                  child: const Text('Refresh catalog'),
                ),
                if (x.productId != widget.product)
                  TextButton(
                    onPressed: locked
                        ? null
                        : () async {
                            if (await confirm(
                              'Change product and clear size/options? Other details stay.',
                            )) {
                              await c.changeProduct(widget.product);
                            }
                          },
                    child: const Text('Change product'),
                  ),
              ],
            ),
            if (catalog == null)
              const Text(
                'Product unavailable or catalog not loaded. Refresh the catalog or return to the bakery to choose another product.',
              ),
            if (catalog != null && !catalog.accepts(x)) ...[
              const Text(
                'Choose current size/options and meet the minimum quantity. Restored selections may no longer be available.',
              ),
              TextButton(
                onPressed: locked
                    ? null
                    : () => c.edit(
                        x.copy(
                          optionIds: x.optionIds
                              .where(
                                (id) => catalog.options.any((o) => o.id == id),
                              )
                              .toList(),
                          variantId:
                              catalog.variants.any((v) => v.id == x.variantId)
                              ? x.variantId
                              : '',
                        ),
                      ),
                child: const Text('Remove unavailable selections'),
              ),
            ],
            if (s.step == 0 && catalog != null) ...[
              Text(
                catalog.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              choice(
                'Weight / size / pack',
                catalog.variants,
                x.variantId,
                (v) => c.edit(x.copy(variantId: v)),
              ),
              field(
                'Quantity (minimum ${catalog.minimum})',
                '${x.quantity}',
                (v) => c.edit(x.copy(quantity: int.tryParse(v) ?? 0)),
              ),
              for (final kind in ['flavour', 'finish']) ...[
                choice(
                  'Optional $kind',
                  catalog.options.where((o) => o.kind == kind).toList(),
                  catalog.options
                          .where(
                            (o) => o.kind == kind && x.optionIds.contains(o.id),
                          )
                          .firstOrNull
                          ?.id ??
                      '',
                  (id) => c.edit(
                    x.copy(
                      optionIds: [
                        ...x.optionIds.where(
                          (v) => !catalog.options.any(
                            (o) => o.id == v && o.kind == kind,
                          ),
                        ),
                        id,
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: locked
                      ? null
                      : () => c.edit(
                          x.copy(
                            optionIds: x.optionIds
                                .where(
                                  (v) => !catalog.options.any(
                                    (o) => o.id == v && o.kind == kind,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                  child: Text('No $kind surcharge'),
                ),
              ],
              for (final o in catalog.options.where((o) => o.kind == 'extra'))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${o.label} · ${requestMoney(o.price)}'),
                  value: x.optionIds.contains(o.id),
                  onChanged: locked
                      ? null
                      : (checked) => c.edit(
                          x.copy(
                            optionIds: checked == true
                                ? [...x.optionIds, o.id]
                                : x.optionIds.where((v) => v != o.id).toList(),
                          ),
                        ),
                ),
            ],
            if (s.step == 1 && catalog != null) ...[
              Text(
                'Requested service date: ${x.date.isEmpty ? 'Not selected' : x.date}',
              ),
              AvailabilityPanel(
                code: catalog.code,
                onSelected: locked
                    ? null
                    : (date) => c.edit(x.copy(date: date)),
              ),
              const Text(
                'Select an available date above. Dates use the bakery timezone.',
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(x.fulfilment),
                initialValue: x.fulfilment,
                decoration: const InputDecoration(labelText: 'Fulfilment'),
                items: const [
                  DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
                  DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                ],
                onChanged: locked
                    ? null
                    : (v) => c.edit(x.copy(fulfilment: v, zoneId: '')),
              ),
              Text(
                'Pickup ${catalog.pickup ? 'available' : 'unavailable'} · Delivery ${catalog.delivery ? 'available' : 'unavailable'}',
              ),
              if (x.fulfilment == 'delivery') ...[
                choice(
                  'Delivery zone',
                  catalog.zones,
                  x.zoneId,
                  (v) => c.edit(x.copy(zoneId: v)),
                ),
                field(
                  'Delivery address',
                  x.address,
                  (v) => c.edit(x.copy(address: v)),
                  max: 500,
                  lines: 3,
                ),
              ],
            ],
            if (s.step == 2) ...[
              field(
                'Contact name',
                x.name,
                (v) => c.edit(x.copy(name: v)),
                max: 100,
              ),
              field('Phone', x.phone, (v) => c.edit(x.copy(phone: v)), max: 40),
              if (catalog?.kind == 'cake')
                field(
                  'Cake message (optional)',
                  x.message,
                  (v) => c.edit(x.copy(message: v)),
                  max: 200,
                ),
              field(
                'Design instructions (optional)',
                x.instructions,
                (v) => c.edit(x.copy(instructions: v)),
                max: 2000,
                lines: 4,
              ),
              const Text(
                'Private references: up to three JPEG, PNG or WebP images, 5 MiB each. Interrupted uploads may require selecting the file again after restart.',
              ),
              for (final path in x.attachments)
                Column(
                  children: [
                    RequestImage(path),
                    TextButton(
                      onPressed: locked ? null : () => c.remove(path),
                      child: const Text('Remove reference'),
                    ),
                  ],
                ),
              OutlinedButton(
                onPressed: locked || x.attachments.length >= 3 ? null : pick,
                child: Text(
                  s.busy ? 'Working / uploading…' : 'Choose reference image',
                ),
              ),
              if (s.retryUpload)
                TextButton(
                  onPressed: locked ? null : c.retryUpload,
                  child: const Text('Retry last upload'),
                ),
              TextButton(
                onPressed: locked ? null : c.cleanup,
                child: const Text('Clean abandoned uploads'),
              ),
            ],
            if (s.step == 3) ...[
              Text(
                '${catalog?.name ?? 'Product'} · quantity ${x.quantity}\n${x.date} · ${x.fulfilment}\n${x.name} · ${x.phone}\n${x.address}\n${x.message}\n${x.instructions}',
              ),
              FilledButton.tonal(
                onPressed: locked ? null : c.review,
                child: const Text('Review current server estimate'),
              ),
              if (d.estimate != null) ...[
                EstimateView(d.estimate!),
                FilledButton(
                  onPressed: locked ? null : c.submit,
                  child: const Text('Submit Pending request'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: [
                OutlinedButton(
                  onPressed: locked || s.step == 0 ? null : () => c.step(-1),
                  child: const Text('Back'),
                ),
                if (s.step < 3)
                  FilledButton(
                    onPressed: locked ? null : () => c.step(1),
                    child: const Text('Next'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class RequestListPage extends ConsumerStatefulWidget {
  const RequestListPage({required this.role, super.key});
  final String role;
  @override
  ConsumerState<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends ConsumerState<RequestListPage> {
  String after = '';
  bool past = false;
  @override
  Widget build(BuildContext context) {
    final provider = after.isEmpty
        ? requestsProvider
        : requestPageProvider(after);
    final list = ref.watch(provider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.role == 'baker' ? 'Incoming requests' : 'Your requests',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Active'),
              selected: !past,
              onSelected: (_) => setState(() => past = false),
            ),
            ChoiceChip(
              label: const Text('Past'),
              selected: past,
              onSelected: (_) => setState(() => past = true),
            ),
            TextButton(
              onPressed: () {
                setState(() => after = '');
                ref.invalidate(requestsProvider);
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
        list.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(provider),
            child: const Text('Could not load requests. Retry'),
          ),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!rows.any(
                (r) =>
                    past ==
                    [
                      'delivered',
                      'declined',
                      'withdrawn',
                      'cancelled',
                    ].contains(r.status),
              ))
                const Text('No matching orders on this page.'),
              for (final r in rows.where(
                (r) =>
                    past ==
                    [
                      'delivered',
                      'declined',
                      'withdrawn',
                      'cancelled',
                    ].contains(r.status),
              ))
                Card(
                  child: ListTile(
                    title: Text('${r.reference}\n${r.status.toUpperCase()}'),
                    subtitle: Text(
                      '${r.businessName} · ${r.productName}\n${r.input.date} · Original estimate ${requestMoney(r.estimate.total)}',
                    ),
                    onTap: () =>
                        context.push('/live/${widget.role}/requests/${r.id}'),
                  ),
                ),
              if (rows.length == 20)
                TextButton(
                  onPressed: () => setState(() => after = rows.last.id),
                  child: const Text('Next 20 requests'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class RequestDetailsPage extends ConsumerWidget {
  const RequestDetailsPage(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Order details')),
    body: ref
        .watch(requestDetailProvider(id))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(requestDetailProvider(id)),
              child: const Text(
                'Request unavailable. Check your account or retry',
              ),
            ),
          ),
          data: (r) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                r.reference,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(r.status.toUpperCase()),
              Text(r.businessName),
              Text(
                '${r.productName} · ${r.variant} · Quantity ${r.input.quantity}',
              ),
              for (final option in r.options) Text(option),
              Text(
                'Service date: ${r.input.date}\n${r.input.fulfilment}\n${r.input.address}',
              ),
              Text('Contact: ${r.input.name}\n${r.input.phone}'),
              Text('Bakery timezone: ${r.timezone}'),
              if (r.zone.isNotEmpty) Text('Delivery zone: ${r.zone}'),
              if (r.pickupAddress.isNotEmpty)
                Text('Pickup address: ${r.pickupAddress}'),
              Text(r.input.message),
              Text(r.input.instructions),
              const Text('Original request estimate'),
              EstimateView(r.estimate, pending: r.status == 'pending'),
              OrderActionPanel(orderId: id, record: r),
              OrderSynchronizationPanel(orderId: id),
              if (r.status != 'declined' &&
                  r.status != 'withdrawn' &&
                  r.status != 'cancelled')
                OrderCommunicationPanel(orderId: id),
              if (r.status == 'delivered' &&
                  ref.read(authControllerProvider).profile?.experience !=
                      'baker')
                OrderReviewPanel(orderId: id),
              if (ref.read(authControllerProvider).profile?.experience ==
                  'baker')
                BakerPrivateOperationsPanel(orderId: id),
              for (final path in r.input.attachments) RequestImage(path),
              Text('Created: ${r.created}'),
              ref
                  .watch(requestEventsProvider(id))
                  .when(
                    data: (events) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final event in events) Text(event)],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => TextButton(
                      onPressed: () =>
                          ref.invalidate(requestEventsProvider(id)),
                      child: const Text('Reload request history'),
                    ),
                  ),
            ],
          ),
        ),
  );
}

class OrderSynchronizationPanel extends ConsumerStatefulWidget {
  const OrderSynchronizationPanel({required this.orderId, super.key});
  final String orderId;

  @override
  ConsumerState<OrderSynchronizationPanel> createState() =>
      _OrderSynchronizationPanelState();
}

class _OrderSynchronizationPanelState
    extends ConsumerState<OrderSynchronizationPanel> {
  int cursor = 0;
  bool busy = false;
  String? message;

  Future<void> synchronize() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await (await ref.read(
        orderRepositoryProvider.future,
      )).synchronize(afterSequence: cursor);
      cursor = result.cursor;
      ref.invalidate(requestDetailProvider(widget.orderId));
      ref.invalidate(requestEventsProvider(widget.orderId));
      if (mounted) {
        setState(
          () => message = result.changes.isEmpty
              ? 'Already up to date.'
              : 'Synchronized ${result.changes.length} change(s).',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is OrderCommandFailure
              ? error.message
              : 'Could not synchronize. Retry without changing local data.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: busy ? null : synchronize,
        icon: const Icon(Icons.sync),
        label: const Text('Refresh from server'),
      ),
      if (message != null) Semantics(liveRegion: true, child: Text(message!)),
    ],
  );
}

class BakerPrivateOperationsPanel extends ConsumerStatefulWidget {
  const BakerPrivateOperationsPanel({required this.orderId, super.key});
  final String orderId;
  @override
  ConsumerState<BakerPrivateOperationsPanel> createState() =>
      _BakerPrivateOperationsPanelState();
}

class _BakerPrivateOperationsPanelState
    extends ConsumerState<BakerPrivateOperationsPanel> {
  final note = TextEditingController();
  final advance = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void dispose() {
    note.dispose();
    advance.dispose();
    super.dispose();
  }

  Future<void> run(
    Future<void> Function(BakerOperationsRepository) action,
  ) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action(await ref.read(bakerOperationsRepositoryProvider.future));
      if (mounted) setState(() => message = 'Private record saved.');
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is BakerOperationsFailure
              ? error.message
              : 'Could not save the private record.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Baker-only records', style: Theme.of(context).textTheme.titleLarge),
      TextField(
        controller: note,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Private order note'),
      ),
      FilledButton.tonal(
        onPressed: busy
            ? null
            : () =>
                  run((repo) => repo.addNote(widget.orderId, note.text.trim())),
        child: const Text('Save private note'),
      ),
      TextField(
        controller: advance,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Advance received (paisa)',
          helperText: 'Record only; this does not claim payment success.',
        ),
      ),
      FilledButton.tonal(
        onPressed: busy
            ? null
            : () {
                final value = int.tryParse(advance.text.trim());
                if (value == null || value < 0) {
                  setState(() => message = 'Enter a valid advance in paisa.');
                  return;
                }
                run((repo) => repo.recordAdvance(widget.orderId, value));
              },
        child: const Text('Save recorded advance'),
      ),
      if (message != null) Text(message!),
    ],
  );
}

class OrderActionPanel extends ConsumerStatefulWidget {
  const OrderActionPanel({
    required this.orderId,
    required this.record,
    super.key,
  });
  final String orderId;
  final RequestRecord record;

  @override
  ConsumerState<OrderActionPanel> createState() => _OrderActionPanelState();
}

class _OrderActionPanelState extends ConsumerState<OrderActionPanel> {
  final amount = TextEditingController();
  final reason = TextEditingController();
  final basis = TextEditingController();
  bool busy = false;
  String? message;
  String? operationId;
  Future<void> Function(OrderRepository)? retryAction;

  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    basis.dispose();
    super.dispose();
  }

  bool get isBaker =>
      ref.read(authControllerProvider).profile?.experience == 'baker';

  Future<bool> run(Future<void> Function(OrderRepository) action) async {
    if (busy) return false;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action(await ref.read(orderRepositoryProvider.future));
      if (!mounted) return false;
      ref.invalidate(requestDetailProvider(widget.orderId));
      ref.invalidate(requestsProvider);
      ref.invalidate(orderQuotesProvider(widget.orderId));
      ref.invalidate(orderScheduleProvider(widget.orderId));
      ref.invalidate(orderCancellationProvider(widget.orderId));
      ref.invalidate(requestEventsProvider(widget.orderId));
      retryAction = null;
      setState(() => message = 'Saved. Reloading the current order.');
      return true;
    } catch (error) {
      final definite =
          error is OrderCommandFailure &&
          {'40001', '23514', '42501', '22023', 'SESSION'}.contains(error.code);
      retryAction = definite ? null : action;
      if (definite) operationId = null;
      if (mounted) {
        setState(() {
          message = error is OrderCommandFailure
              ? error.message
              : 'Could not update this order. Retry after checking the connection.';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> revise() async {
    final paisa = int.tryParse(amount.text.trim());
    if (paisa == null || paisa <= 0 || reason.text.trim().isEmpty) {
      setState(() => message = 'Enter a positive exact amount and a reason.');
      return;
    }
    await run(
      (repo) => repo.reviseQuote(
        orderId: widget.orderId,
        expectedVersion: widget.record.currentQuoteVersion,
        estimate: {
          'subtotal_paisa': paisa,
          'delivery_paisa': 0,
          'total_paisa': paisa,
          'lines': [
            {'label': 'Exact quote', 'amount_paisa': paisa},
          ],
        },
        reason: reason.text.trim(),
      ),
    );
  }

  Future<void> confirmOrder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
    );
    if (time == null || !mounted) return;
    final localTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final success = await run(
      (repo) => repo.confirm(
        orderId: widget.orderId,
        expectedVersion: widget.record.version,
        quoteVersion: widget.record.currentQuoteVersion,
        localTime: localTime,
        operationId: operationId ??= const Uuid().v4(),
      ),
    );
    if (success) operationId = null;
  }

  Future<void> transition(OrderStatus next) async {
    final success = await run(
      (repo) => repo.transition(
        orderId: widget.orderId,
        expectedVersion: widget.record.version,
        status: next,
        operationId: operationId ??= const Uuid().v4(),
      ),
    );
    if (success) operationId = null;
  }

  Future<void> cancellation(String action) async {
    final version = widget.record.version;
    final key = operationId ??= const Uuid().v4();
    final success = await run(
      (repo) => repo.cancelCommand(
        id: widget.orderId,
        version: version,
        action: action,
        operationId: key,
      ),
    );
    if (success) operationId = null;
  }

  Future<void> reschedule(Map<String, dynamic> schedule) async {
    final currentDate = DateTime.tryParse(schedule['date'] as String? ?? '');
    final currentTime = (schedule['time'] as String? ?? '').split(':');
    if (currentDate == null || currentTime.length != 2) {
      setState(
        () => message =
            'The saved due time is unavailable. Reload the order or contact support.',
      );
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(currentTime[0]),
        minute: int.parse(currentTime[1]),
      ),
    );
    if (time == null || !mounted) return;
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm reschedule'),
        content: Text(
          'Move this order to $day at $clock in ${schedule['timezone']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final version = widget.record.version;
    final key = operationId ??= const Uuid().v4();
    final success = await run(
      (repo) => repo.reschedule(
        id: widget.orderId,
        version: version,
        date: day,
        time: clock,
        operationId: key,
      ),
    );
    if (success) operationId = null;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final pending = r.status == 'pending';
    final locked = busy || retryAction != null;
    final confirmed = r.status == 'confirmed';
    final baking = r.status == 'baking';
    final decorating = r.status == 'decorating';
    final ready = r.status == 'ready';
    final quotes = ref.watch(orderQuotesProvider(widget.orderId));
    final schedule = ref.watch(orderScheduleProvider(widget.orderId));
    final cancellationState = ref.watch(
      orderCancellationProvider(widget.orderId),
    );
    final latest = quotes.asData?.value
        .where((q) => q['version'] == r.currentQuoteVersion)
        .firstOrNull;
    final quoteEstimate = latest?['estimate'];
    final canReview =
        quoteEstimate is Map && quoteEstimate['total_paisa'] is int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        schedule.when(
          data: (value) => Text(
            'Saved schedule: ${value['date']} ${value['time'] ?? 'time not set'} (${value['timezone']})',
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(orderScheduleProvider(widget.orderId)),
            child: const Text('Could not load schedule. Retry'),
          ),
        ),
        if (isBaker &&
            (confirmed || baking || decorating || ready) &&
            schedule.asData != null)
          OutlinedButton(
            onPressed: locked ? null : () => reschedule(schedule.asData!.value),
            child: const Text('Reschedule order'),
          ),
        cancellationState.when(
          data: (status) => Column(
            children: [
              if (status != null) Text('Cancellation: $status'),
              if (!isBaker && (confirmed || baking) && status == null)
                OutlinedButton(
                  onPressed: locked ? null : () => cancellation('request'),
                  child: const Text('Request cancellation'),
                ),
              if (isBaker && status == 'open') ...[
                FilledButton(
                  onPressed: locked ? null : () => cancellation('approve'),
                  child: const Text('Approve cancellation'),
                ),
                OutlinedButton(
                  onPressed: locked ? null : () => cancellation('reject'),
                  child: const Text('Reject cancellation'),
                ),
              ],
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(orderCancellationProvider(widget.orderId)),
            child: const Text('Could not load cancellation status. Retry'),
          ),
        ),
        quotes.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(orderQuotesProvider(widget.orderId)),
            child: const Text('Could not load quote history. Retry'),
          ),
          data: (history) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final quote in history)
                if (quote['estimate'] is Map &&
                    quote['estimate']['total_paisa'] is int)
                  Text(
                    'Quote v${quote['version']}: ${requestMoney(quote['estimate']['total_paisa'])}${quote['version'] == r.currentQuoteVersion ? ' (current)' : ''}${quote['reason'] == null ? '' : ' — ${quote['reason']}'}',
                  ),
            ],
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(liveRegion: true, child: Text(message!)),
          ),
        if (retryAction != null)
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final action = retryAction!;
                    if (await run(action)) operationId = null;
                  },
            child: const Text('Retry the same action'),
          ),
        if (isBaker && pending) ...[
          TextFormField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Exact quote (paisa)',
              helperText: 'Example: PKR 5800.00 is 580000 paisa.',
            ),
          ),
          TextFormField(
            controller: reason,
            decoration: const InputDecoration(
              labelText: 'Quote revision reason',
            ),
            maxLength: 1000,
          ),
          FilledButton(
            onPressed: locked ? null : revise,
            child: const Text('Issue exact quote'),
          ),
          FilledButton.tonal(
            onPressed: locked ? null : () => transition(OrderStatus.declined),
            child: const Text('Decline request'),
          ),
        ],
        if (!isBaker &&
            pending &&
            r.agreedQuoteVersion != r.currentQuoteVersion) ...[
          TextFormField(
            controller: basis,
            decoration: const InputDecoration(
              labelText: 'Agreement basis',
              helperText:
                  'Record what you are acknowledging. This is not a payment.',
            ),
            maxLength: 1000,
          ),
          FilledButton(
            onPressed: locked || !canReview
                ? null
                : () => run(
                    (repo) => repo.recordAgreement(
                      orderId: widget.orderId,
                      quoteVersion: r.currentQuoteVersion,
                      basis: basis.text.trim(),
                    ),
                  ),
            child: const Text('Acknowledge exact quote'),
          ),
        ],
        if (!isBaker && pending)
          OutlinedButton(
            onPressed: locked
                ? null
                : () async {
                    final success = await run(
                      (repo) => repo.transition(
                        orderId: widget.orderId,
                        expectedVersion: r.version,
                        status: OrderStatus.withdrawn,
                        operationId: operationId ??= const Uuid().v4(),
                      ),
                    );
                    if (success) operationId = null;
                  },
            child: const Text('Withdraw request'),
          ),
        if (isBaker && pending && r.agreedQuoteVersion == r.currentQuoteVersion)
          Text('Choose a due time in the bakery timezone: ${r.timezone}.'),
        if (isBaker && pending && r.agreedQuoteVersion == r.currentQuoteVersion)
          FilledButton(
            onPressed: locked ? null : confirmOrder,
            child: const Text('Confirm production order'),
          ),
        if (isBaker && confirmed)
          FilledButton(
            onPressed: locked ? null : () => transition(OrderStatus.baking),
            child: const Text('Start baking'),
          ),
        if (isBaker && (baking || decorating))
          FilledButton(
            onPressed: locked ? null : () => transition(OrderStatus.ready),
            child: const Text('Mark ready'),
          ),
        if (isBaker && ready)
          FilledButton(
            onPressed: locked ? null : () => transition(OrderStatus.delivered),
            child: const Text('Mark delivered'),
          ),
      ],
    );
  }
}
