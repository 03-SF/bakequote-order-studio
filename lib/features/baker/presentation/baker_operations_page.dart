import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/baker_operations_repository.dart';

class BakerTodayPage extends ConsumerWidget {
  const BakerTodayPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(bakerTodayProvider(null));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Today', style: Theme.of(context).textTheme.headlineLarge),
        const Text(
          'Confirmed production only. Pending requests are shown separately.',
        ),
        day.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error is BakerOperationsFailure
                    ? error.message
                    : 'Could not load today. Retry the request.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(bakerTodayProvider(null)),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${value.date} · ${value.timezone}'),
              Text('Pending requests: ${value.pending}'),
              if (value.orders.isEmpty)
                const Text('No confirmed production for this date.'),
              for (final order in value.orders)
                Card(
                  child: ListTile(
                    title: Text('${order.reference} · ${order.status}'),
                    subtitle: Text(
                      '${order.name}\n${order.totalPaisa ~/ 100}.${(order.totalPaisa % 100).toString().padLeft(2, '0')} PKR',
                    ),
                    onTap: () =>
                        context.push('/live/baker/requests/${order.id}'),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 40),
        const _QuickAddPanel(),
        const Divider(height: 40),
        const _ContactPanel(),
      ],
    );
  }
}

class _QuickAddPanel extends ConsumerStatefulWidget {
  const _QuickAddPanel();
  @override
  ConsumerState<_QuickAddPanel> createState() => _QuickAddPanelState();
}

class _QuickAddPanelState extends ConsumerState<_QuickAddPanel> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final amount = TextEditingController();
  DateTime? date;
  bool busy = false, acknowledge = false;
  String? message;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> add() async {
    final total = int.tryParse(amount.text.trim());
    if (name.text.trim().isEmpty ||
        total == null ||
        total <= 0 ||
        date == null) {
      setState(
        () =>
            message = 'Enter a name, exact amount in paisa, and service date.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await (await ref.read(
        bakerOperationsRepositoryProvider.future,
      )).addManualOrder(
        name: name.text.trim(),
        phone: phone.text.trim(),
        date: date!,
        totalPaisa: total,
        acknowledgeLeadTime: acknowledge,
      );
      if (mounted) {
        setState(() => message = 'Manual confirmed order added.');
        ref.invalidate(bakerTodayProvider(null));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is BakerOperationsFailure
              ? error.message
              : 'Could not add manual order.',
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
      Text('Quick Add', style: Theme.of(context).textTheme.headlineSmall),
      const Text(
        'Creates a confirmed manual order. It does not create a customer account or conversation.',
      ),
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Customer name'),
      ),
      TextField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'Phone'),
      ),
      TextField(
        controller: amount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Final price (paisa)',
          helperText: 'PKR 5800.00 = 580000 paisa',
        ),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: date ?? DateTime.now(),
                );
                if (picked != null) setState(() => date = picked);
              },
        child: Text(
          date == null
              ? 'Choose service date'
              : 'Service date: ${date!.toIso8601String().substring(0, 10)}',
        ),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: acknowledge,
        onChanged: busy
            ? null
            : (value) => setState(() => acknowledge = value == true),
        title: const Text('I acknowledge a documented lead-time bypass'),
      ),
      if (message != null) Text(message!),
      FilledButton(
        onPressed: busy ? null : add,
        child: const Text('Add manual order'),
      ),
    ],
  );
}

class _ContactPanel extends ConsumerStatefulWidget {
  const _ContactPanel();
  @override
  ConsumerState<_ContactPanel> createState() => _ContactPanelState();
}

class _ContactPanelState extends ConsumerState<_ContactPanel> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      setState(() => message = 'Enter a contact name and phone number.');
      return;
    }
    setState(() => busy = true);
    try {
      await (await ref.read(
        bakerOperationsRepositoryProvider.future,
      )).saveContact(
        name: name.text.trim(),
        phone: phone.text.trim(),
        notes: notes.text.trim(),
      );
      if (mounted) setState(() => message = 'Private contact saved.');
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is BakerOperationsFailure
              ? error.message
              : 'Could not save contact.',
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
      Text(
        'Private contacts',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Text(
        'Contacts are scoped to this bakery. Matching a phone never grants account access.',
      ),
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      TextField(
        controller: phone,
        decoration: const InputDecoration(labelText: 'Phone'),
      ),
      TextField(
        controller: notes,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Private notes'),
      ),
      if (message != null) Text(message!),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Save contact'),
      ),
    ],
  );
}
