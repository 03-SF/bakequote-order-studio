import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/availability_controller.dart';
import '../domain/availability.dart';

class AvailabilityPanel extends ConsumerStatefulWidget {
  const AvailabilityPanel({required this.code, this.ownerId, super.key});
  final String code;
  final String? ownerId;
  @override
  ConsumerState<AvailabilityPanel> createState() => _AvailabilityPanelState();
}

class _AvailabilityPanelState extends ConsumerState<AvailabilityPanel> {
  final timezone = TextEditingController(),
      lead = TextEditingController(),
      capacity = TextEditingController();
  String? start, selected;
  bool dirty = false, initialized = false;
  void markDirty(bool value) {
    ref.read(availabilityDirtyProvider.notifier).set(value);
    setState(() => dirty = value);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    if (!mounted) return;
    await ref
        .read(availabilityControllerProvider.notifier)
        .load(widget.code, start, widget.ownerId);
    if (!mounted) return;
    final s = ref.read(availabilityControllerProvider).settings;
    if (s != null && (!initialized || !dirty)) {
      timezone.text = s.timezone;
      lead.text = '${s.leadDays}';
      capacity.text = '${s.capacity}';
      initialized = true;
    }
  }

  @override
  void dispose() {
    timezone.dispose();
    lead.dispose();
    capacity.dispose();
    super.dispose();
  }

  Future<bool> leave() async =>
      !dirty ||
      (await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard unsaved availability edits?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          )) ==
          true;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availabilityControllerProvider),
        calendar = state.calendar;
    final controller = ref.read(availabilityControllerProvider.notifier);
    final days = calendar?.days ?? <AvailabilityDay>[];
    final chosen = days.where((d) => d.date == selected).firstOrNull;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await leave() && context.mounted) {
          markDirty(false);
          if (context.mounted) Navigator.maybePop(context);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Availability',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (state.busy) const LinearProgressIndicator(),
          if (state.message != null)
            Semantics(liveRegion: true, child: Text(state.message!)),
          if (widget.ownerId != null) ...[
            const Text(
              'Choose your business timezone explicitly. Lead time uses whole calendar days; capacity counts orders per service date.',
            ),
            for (final field in [
              (timezone, 'IANA timezone (for example Asia/Karachi)'),
              (lead, 'Minimum lead days'),
              (capacity, 'Daily order capacity'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextField(
                  controller: field.$1,
                  enabled: !state.busy,
                  decoration: InputDecoration(labelText: field.$2),
                  onChanged: (_) => markDirty(true),
                ),
              ),
            FilledButton(
              onPressed: state.busy || state.settings == null
                  ? null
                  : () async {
                      final l = int.tryParse(lead.text),
                          c = int.tryParse(capacity.text);
                      if (l == null ||
                          l < 0 ||
                          l > 365 ||
                          c == null ||
                          c < 1 ||
                          c > 10000 ||
                          timezone.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a timezone, lead days 0–365 and capacity 1–10000.',
                            ),
                          ),
                        );
                        return;
                      }
                      await controller.save(
                        widget.code,
                        widget.ownerId!,
                        start,
                        timezone.text.trim(),
                        l,
                        c,
                      );
                      if (mounted &&
                          ref.read(availabilityControllerProvider).message ==
                              'Availability saved.') {
                        markDirty(false);
                      }
                    },
              child: const Text('Save availability'),
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: state.busy
                    ? null
                    : () async {
                        if (dirty && !await leave()) return;
                        if (!mounted) return;
                        markDirty(false);
                        await load();
                      },
                child: const Text('Reload / retry'),
              ),
              for (final direction in [-1, 1])
                TextButton(
                  onPressed: state.busy || dirty || calendar?.configured != true
                      ? null
                      : () {
                          final month = calendarMonth(
                            DateTime.parse(start ?? calendar!.today),
                            direction,
                          );
                          setState(() {
                            start = serviceDate(month);
                            selected = null;
                          });
                          load();
                        },
                  child: Text(direction < 0 ? 'Previous month' : 'Next month'),
                ),
              TextButton(
                onPressed: state.busy || dirty
                    ? null
                    : () {
                        setState(() {
                          start = null;
                          selected = calendar?.today;
                        });
                        load();
                      },
                child: const Text('Today'),
              ),
            ],
          ),
          if (calendar != null && !calendar.configured)
            const Text('Availability has not been configured by this bakery.'),
          if (calendar?.configured == true) ...[
            Text(
              '${(start ?? calendar!.today).substring(0, 7)} · ${calendar!.timezone} · Minimum ${calendar.leadDays} calendar days',
            ),
            const Text(
              'Legend: available · full · blocked · past · lead time restricted. Availability is rechecked when an order is confirmed.',
            ),
            const Text(
              'Order submission is not enabled yet. No orders are reserved by viewing dates.',
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in days)
                  OutlinedButton(
                    onPressed: () => setState(() => selected = day.date),
                    child: Text('${day.date.substring(8)}: ${day.label}'),
                  ),
              ],
            ),
            if (chosen != null) ...[
              Text(
                '${chosen.date}: ${chosen.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.ownerId != null)
                FilledButton.tonal(
                  onPressed: state.busy || dirty || chosen.state == 'past'
                      ? null
                      : () => controller.block(
                          widget.code,
                          widget.ownerId!,
                          start,
                          chosen,
                        ),
                  child: Text(
                    chosen.state == 'blocked' ? 'Unblock date' : 'Block date',
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
