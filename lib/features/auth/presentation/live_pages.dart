import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../shared/widgets/controls.dart';
import '../application/auth_controller.dart';
import '../domain/auth_models.dart';
import 'auth_pages.dart';
import '../../discovery/discovery.dart';
import '../../availability/availability.dart';
import '../../baker/application/baker_providers.dart';
import '../../requests/requests.dart';
import '../../baker/presentation/baker_operations_page.dart';
import '../../billing/presentation/account_lifecycle_panel.dart';

final accountImageProvider = FutureProvider.autoDispose.family<String, bool>((
  ref,
  business,
) async {
  final profile = ref.watch(authControllerProvider.select((s) => s.profile));
  if (profile == null) return '';
  final repository = await ref.watch(authRepositoryProvider.future);
  return repository!.imageUrl(profile, business: business);
});

class LivePage extends ConsumerWidget {
  const LivePage({required this.view, this.initialCode, super.key});
  final String view;
  final String? initialCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider), s = AppStrings.of(context);
    final profile = state.profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (view == 'account') {
      return LiveAccount(key: ValueKey(profile.id), profile: profile);
    }
    if (view == 'orders') {
      return RequestListPage(
        role: profile.experience ?? 'customer',
        key: ValueKey(profile.id),
      );
    }
    if (view == 'home' && profile.experience == 'customer') {
      return DiscoveryPage(
        initialCode: initialCode,
        key: ValueKey('${profile.id}:$initialCode'),
      );
    }
    if (view == 'calendar' && profile.businessId != null) {
      return ref
          .watch(bakerWorkspaceProvider)
          .when(
            data: (workspace) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                AvailabilityPanel(
                  key: ValueKey(workspace.id),
                  code: workspace.business['code'],
                  ownerId: workspace.id,
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(bakerWorkspaceProvider),
                child: const Text('Could not load bakery. Retry'),
              ),
            ),
          );
    }
    if (view == 'today' && profile.businessId != null) {
      return const BakerTodayPage();
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          s.t(view[0].toUpperCase() + view.substring(1)),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 24),
        if (profile.businessId != null)
          FilledButton(
            onPressed: () => context.go('/live/baker/setup'),
            child: const Text('Open baker setup'),
          ),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(state.identity!.email, textDirection: TextDirection.ltr),
              if (profile.businessName != null) ...[
                const SizedBox(height: 12),
                Text(profile.businessName!),
                Text(
                  s.t(
                    'Open baker setup to edit your business, catalog and pricing.',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                s.t(
                  'Your account is connected. Ordering and bakery operations arrive in later phases.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LiveAccount extends ConsumerStatefulWidget {
  const LiveAccount({required this.profile, super.key});
  final AccountProfile profile;
  @override
  ConsumerState<LiveAccount> createState() => _LiveAccountState();
}

class _LiveAccountState extends ConsumerState<LiveAccount> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone;
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _phone = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pick(bool business) async {
    final owner = widget.profile.id;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      if (await image.length() > 5 * 1024 * 1024) {
        throw const UserFacingFailure('Choose an image up to 5 MB');
      }
      final bytes = await image.readAsBytes();
      if (!mounted || ref.read(authControllerProvider).identity?.id != owner) {
        return;
      }
      await ref
          .read(authControllerProvider.notifier)
          .uploadImage(bytes, business: business);
    } catch (error) {
      if (mounted) {
        ref.read(authControllerProvider.notifier).showImageFailure(error);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context), state = ref.watch(authControllerProvider);
    final busy = state.busy || _picking;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.t('Account'), style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        const AuthMessage(),
        Text(state.identity!.email, textDirection: TextDirection.ltr),
        const SizedBox(height: 24),
        const AccountLifecyclePanel(),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !busy,
                maxLength: 100,
                decoration: InputDecoration(labelText: s.t('Full name')),
                validator: (v) => validateName(v ?? '') == null
                    ? null
                    : s.t('Enter 1 to 100 characters'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                enabled: !busy,
                maxLength: 40,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: s.t('Phone (optional)')),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        if (_form.currentState!.validate()) {
                          ref
                              .read(authControllerProvider.notifier)
                              .saveProfile(_name.text, _phone.text, 'en');
                        }
                      },
                child: Text(s.t(busy ? 'Saving...' : 'Save profile')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (final business in [
          false,
          if (widget.profile.businessId != null) true,
        ]) ...[
          Text(
            s.t(business ? 'Public business image' : 'Private profile image'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ref
              .watch(accountImageProvider(business))
              .when(
                data: (url) => url.isEmpty
                    ? const SizedBox.shrink()
                    : Image.network(
                        url,
                        height: 140,
                        fit: BoxFit.contain,
                        semanticLabel: s.t(
                          business
                              ? 'Public business image'
                              : 'Private profile image',
                        ),
                        errorBuilder: (_, error, stack) =>
                            Text(s.t('Image could not be loaded')),
                      ),
                error: (_, stack) => Text(s.t('Image could not be loaded')),
                loading: () => const LinearProgressIndicator(),
              ),
          OutlinedButton(
            onPressed: busy ? null : () => _pick(business),
            child: Text(s.t('Choose image')),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          s.t(
            'Images: JPEG, PNG or WebP, up to 5 MB. Business images are public.',
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: busy
              ? null
              : ref.read(authControllerProvider.notifier).logout,
          child: Text(s.t('Log out')),
        ),
      ],
    );
  }
}
