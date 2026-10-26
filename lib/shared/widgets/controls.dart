import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});
  @override
  Widget build(BuildContext context) => const FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cake_outlined, color: BakeColors.rose),
          SizedBox(width: 8),
          Text.rich(
            TextSpan(
              text: 'Bake',
              children: [
                TextSpan(
                  text: 'Quote',
                  style: TextStyle(color: BakeColors.rose),
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class PreviewNotice extends StatelessWidget {
  const PreviewNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BakeColors.blush,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('Development preview'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              s.t(
                'Phase 1 • Sample data only. Accounts and ordering are not connected.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class MoneyRow extends StatelessWidget {
  const MoneyRow(this.label, this.amount, {super.key});
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(AppStrings.of(context).t(label))),
        const SizedBox(width: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            'PKR $amount',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
