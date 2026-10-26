import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bakequote_mobile/features/baker/domain/baker_workspace.dart';
import 'package:bakequote_mobile/features/baker/data/baker_repository.dart';
import 'package:bakequote_mobile/features/auth/domain/auth_models.dart';
import 'package:bakequote_mobile/core/media/image_validation.dart';
import 'support/baker_fixture.dart';
import 'package:bakequote_mobile/features/baker/application/baker_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Image validation exposes useful safe instructions', () {
    expect(
      bakerError(
        const ImageValidationFailure('Choose a JPEG, PNG or WebP image'),
      ),
      'Choose a JPEG, PNG or WebP image',
    );
    expect(
      bakerError(const ImageValidationFailure('Choose an image up to 5 MB')),
      'Choose an image up to 5 MB',
    );
  });
  test('Estimate rejects totals that cannot be represented exactly on web', () {
    final w = fixture();
    w.products[0]['variants'][0]['price_paisa'] = 100000000000;
    final ids = <String>[];
    w.products[0]['options'] = List.generate(20, (i) {
      final id = 'extra-$i';
      ids.add(id);
      return {
        'id': id,
        'label': 'Extra',
        'kind': 'extra',
        'price_paisa': 100000000000,
        'active': true,
      };
    });
    expect(
      () => previewEstimate(w, productId, variantId, ids, 10000, zoneId),
      throwsFormatException,
    );
  });
  test('Legacy Urdu profile preference safely resolves to English', () {
    const profile = AccountProfile(
      id: 'old',
      name: 'Old',
      phone: '',
      locale: 'ur',
    );
    expect(profile.locale, 'en');
  });
  test(
    'PKR decimal parsing is exact integer paisa and rejects invalid money',
    () {
      expect(parsePkr('3000.01'), 300001);
      expect(parsePkr('0.10'), 10);
      for (final input in ['-1', '1.001', 'NaN', '1e2', '']) {
        expect(() => parsePkr(input), throwsFormatException);
      }
    },
  );
  test('Canonical estimate is 3800 subtotal plus 300 delivery = 4100', () {
    final e = previewEstimate(
      fixture(),
      productId,
      variantId,
      [finishId, extraId],
      1,
      zoneId,
    );
    expect(e['subtotal_paisa'], 380000);
    expect(e['delivery_paisa'], 30000);
    expect(e['total_paisa'], 410000);
  });
  test('Minimum subtotal excludes delivery and pack quantity is enforced', () {
    final w = fixture();
    w.business['minimum_paisa'] = 400000;
    expect(
      () => previewEstimate(
        w,
        productId,
        variantId,
        [finishId, extraId],
        1,
        zoneId,
      ),
      throwsFormatException,
    );
    w.business['minimum_paisa'] = 0;
    w.products[0]['kind'] = 'cupcakes';
    w.products[0]['minimum_quantity'] = 2;
    expect(
      () => previewEstimate(w, productId, variantId, [], 1, zoneId),
      throwsFormatException,
    );
    expect(
      previewEstimate(w, productId, variantId, [], 2, zoneId)['total_paisa'],
      630000,
    );
  });
  test(
    'Inactive, duplicate, unrelated options and unavailable delivery rejected',
    () {
      final w = fixture();
      for (final ids in [
        [finishId, finishId],
        ['unrelated'],
      ]) {
        expect(
          () => previewEstimate(w, productId, variantId, ids, 1, zoneId),
          throwsFormatException,
        );
      }
      w.products[0]['options'][0]['active'] = false;
      expect(
        () => previewEstimate(w, productId, variantId, [finishId], 1, zoneId),
        throwsFormatException,
      );
      expect(
        () => previewEstimate(w, productId, variantId, [], 1, 'unrelated'),
        throwsFormatException,
      );
      w.business['delivery_enabled'] = false;
      expect(
        () => previewEstimate(w, productId, variantId, [], 1, zoneId),
        throwsFormatException,
      );
      w.products[0]['active'] = false;
      expect(
        () => previewEstimate(w, productId, variantId, [], 1, null),
        throwsFormatException,
      );
    },
  );
  test('Activation requires real setup details and valid fulfilment', () {
    final w = fixture();
    w.business['owner_name'] = '';
    expect(() => w.validate(activation: true), throwsFormatException);
    w.business['owner_name'] = 'Owner';
    w.zones.clear();
    expect(() => w.validate(activation: true), throwsFormatException);
    w.business['delivery_enabled'] = false;
    w.validate(activation: true);
    w.business['pickup_address'] = '';
    expect(() => w.validate(activation: true), throwsFormatException);
  });
  test(
    'Catalog rejects missing variant, invalid packs and negative prices',
    () {
      final w = fixture();
      w.products[0]['variants'][0]['active'] = false;
      expect(() => w.validate(), throwsFormatException);
      w.products[0]['variants'][0]['active'] = true;
      w.products[0]['variants'][0]['units'] = 0;
      expect(() => w.validate(), throwsFormatException);
      w.products[0]['variants'][0]['units'] = 1;
      w.products[0]['options'][0]['price_paisa'] = -1;
      expect(() => w.validate(), throwsFormatException);
    },
  );
  test(
    'Preview restart persists draft, activation and deactivation without live keys',
    () async {
      SharedPreferences.setMockInitialValues({'old.locale': 'ur'});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreviewBakerRepository(prefs);
      final saved = await repo.save(fixture());
      expect(saved.revision, 1);
      final reopened = await PreviewBakerRepository(prefs).load();
      expect(reopened.products[0]['name'], 'Chocolate cake');
      final active = await repo.activate(reopened);
      expect(active.active, true);
      active.products[0]['active'] = false;
      await repo.save(active);
      expect((await repo.load()).products.single['active'], false);
      expect(prefs.getKeys().any((k) => k.contains('auth-token')), false);
      await expectLater(repo.save(fixture()), throwsFormatException);
    },
  );
  test(
    'Preview invalid upload leaves prior image unchanged; replace/remove persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PreviewBakerRepository(
        await SharedPreferences.getInstance(),
      );
      var w = await repo.save(fixture());
      await expectLater(
        repo.image(w, 'product', productId, Uint8List.fromList([1, 2]), (_) {}),
        throwsA(isA<ImageValidationFailure>()),
      );
      expect((await repo.load()).products[0]['image_path'], null);
      w = await repo.image(
        w,
        'product',
        productId,
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        (_) {},
      );
      expect(w.products[0]['image_path'], startsWith('data:'));
      w = await repo.image(w, 'product', productId, null, (_) {});
      expect(w.products[0]['image_path'], null);
    },
  );
}
