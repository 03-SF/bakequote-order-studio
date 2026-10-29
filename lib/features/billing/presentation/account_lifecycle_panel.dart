import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/billing_repository.dart';
import '../domain/billing.dart';

class AccountLifecyclePanel extends ConsumerStatefulWidget {
  const AccountLifecyclePanel({super.key});

  @override
  ConsumerState<AccountLifecyclePanel> createState() =>
      _AccountLifecyclePanelState();
}

class _AccountLifecyclePanelState extends ConsumerState<AccountLifecyclePanel> {
  bool busy = false;
  String? message;

  Future<void> export() async {
    await run(() async {
      final json = await (await ref.read(
        billingRepositoryProvider.future,
      )).exportSnapshot();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Account export'),
          content: SingleChildScrollView(child: SelectableText(json)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(
          () => message =
              'Snapshot generated. Encrypted archive export requires the configured release crypto adapter.',
        );
      }
    });
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is BillingFailure
              ? error.message
              : 'Could not complete this account action.',
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
      Text('Billing and data', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'Pro access is granted only after server verification with Apple or Google. '
        'Store products and localized prices are unavailable until store credentials are configured.',
      ),
      OutlinedButton(
        onPressed: busy ? null : export,
        child: const Text('Create account snapshot'),
      ),
      OutlinedButton(
        onPressed: null,
        child: const Text('Account deletion unavailable'),
      ),
      const Text(
        'Account deletion is not yet configured. No deletion request will be submitted.',
      ),
      if (message != null) Semantics(liveRegion: true, child: Text(message!)),
    ],
  );
}
