import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/communication_repository.dart';
import '../domain/communication.dart';

class OrderCommunicationPanel extends ConsumerStatefulWidget {
  const OrderCommunicationPanel({required this.orderId, super.key});
  final String orderId;
  @override
  ConsumerState<OrderCommunicationPanel> createState() =>
      _OrderCommunicationPanelState();
}

class OrderReviewPanel extends ConsumerStatefulWidget {
  const OrderReviewPanel({required this.orderId, super.key});
  final String orderId;

  @override
  ConsumerState<OrderReviewPanel> createState() => _OrderReviewPanelState();
}

class _OrderReviewPanelState extends ConsumerState<OrderReviewPanel> {
  final body = TextEditingController();
  int rating = 5;
  bool busy = false;
  String? message;

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await (await ref.read(
        communicationRepositoryProvider.future,
      )).review(widget.orderId, rating, body.text);
      if (mounted) setState(() => message = 'Review submitted.');
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is CommunicationFailure
              ? error.message
              : 'Could not submit the review.',
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
      Text('Review this order', style: Theme.of(context).textTheme.titleLarge),
      DropdownButtonFormField<int>(
        initialValue: rating,
        items: [
          for (var value = 5; value >= 1; value--)
            DropdownMenuItem(value: value, child: Text('$value / 5')),
        ],
        onChanged: busy ? null : (value) => setState(() => rating = value!),
        decoration: const InputDecoration(labelText: 'Rating'),
      ),
      TextField(
        controller: body,
        maxLength: 2000,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Optional review'),
      ),
      FilledButton.tonal(
        onPressed: busy ? null : submit,
        child: const Text('Submit review'),
      ),
      if (message != null) Text(message!),
    ],
  );
}

class _OrderCommunicationPanelState
    extends ConsumerState<OrderCommunicationPanel> {
  final composer = TextEditingController();
  bool busy = false;
  String? message;
  final attachmentPaths = <String>[];

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final body = composer.text.trim();
    if (body.isEmpty || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await (await ref.read(
        communicationRepositoryProvider.future,
      )).send(widget.orderId, body, attachmentPaths: attachmentPaths);
      composer.clear();
      attachmentPaths.clear();
      ref.invalidate(orderMessagesProvider(widget.orderId));
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is CommunicationFailure
              ? error.message
              : 'Could not send message. Retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickAttachment() async {
    if (busy || attachmentPaths.length >= 3) return;
    final selected = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (selected == null || !mounted) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final bytes = await selected.readAsBytes();
      final path = await (await ref.read(
        communicationRepositoryProvider.future,
      )).uploadAttachment(widget.orderId, bytes);
      if (mounted) setState(() => attachmentPaths.add(path));
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is CommunicationFailure
              ? error.message
              : 'Could not upload the image.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> moderate(String action) async {
    final repo = await ref.read(communicationRepositoryProvider.future);
    try {
      if (action == 'block') {
        await repo.block(widget.orderId);
      } else {
        await repo.report(
          widget.orderId,
          'other',
          'Reported from order conversation',
        );
      }
      if (mounted) {
        setState(
          () => message = action == 'block'
              ? 'Participant blocked.'
              : 'Report submitted.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is CommunicationFailure
              ? error.message
              : 'Could not complete this action.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(orderMessagesProvider(widget.orderId));
    final notifications = ref.watch(notificationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Order conversation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Messages are available only to the customer and baker for this app order. Manual orders have no conversation.',
        ),
        notifications.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (rows) {
            final orderNotifications = rows
                .where((notification) => notification.orderId == widget.orderId)
                .toList();
            if (orderNotifications.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Notifications'),
                for (final notification in orderNotifications)
                  ListTile(
                    dense: true,
                    title: Text(notification.body),
                    subtitle: Text(notification.createdAt),
                  ),
              ],
            );
          },
        ),
        messages.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(
            error is CommunicationFailure
                ? error.message
                : 'Could not load messages.',
          ),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty) const Text('No messages yet.'),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(row.body),
                    subtitle: Text(
                      'Message ${row.sequence} · ${row.createdAt}',
                    ),
                  ),
                ),
            ],
          ),
        ),
        TextField(
          controller: composer,
          maxLength: 4000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: busy || attachmentPaths.length >= 3
                  ? null
                  : pickAttachment,
              icon: const Icon(Icons.attach_file),
              label: Text('Attach image (${attachmentPaths.length}/3)'),
            ),
          ],
        ),
        FilledButton(
          onPressed: busy ? null : send,
          child: const Text('Send message'),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: busy ? null : () => moderate('report'),
              child: const Text('Report'),
            ),
            TextButton(
              onPressed: busy ? null : () => moderate('block'),
              child: const Text('Block participant'),
            ),
          ],
        ),
        if (message != null) Semantics(liveRegion: true, child: Text(message!)),
      ],
    );
  }
}
