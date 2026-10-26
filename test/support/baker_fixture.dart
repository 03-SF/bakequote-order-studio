import 'package:bakequote_mobile/features/baker/domain/baker_workspace.dart';

const productId = '10000000-0000-4000-8000-000000000001';
const variantId = '20000000-0000-4000-8000-000000000001';
const finishId = '30000000-0000-4000-8000-000000000001';
const extraId = '30000000-0000-4000-8000-000000000002';
const zoneId = '40000000-0000-4000-8000-000000000001';
BakerWorkspace fixture() => BakerWorkspace(
  {
    'id': '50000000-0000-4000-8000-000000000001',
    'revision': 0,
    'name': 'Test bakery',
    'description': 'Cakes baked to order',
    'owner_name': 'Private owner',
    'contact_phone': '0123456789',
    'location': 'Public area',
    'pickup_address': 'Private address',
    'pickup_enabled': true,
    'delivery_enabled': true,
    'minimum_paisa': 0,
    'onboarding_complete': false,
    'code': 'TEST-CODE',
    'image_path': null,
    'cover_path': null,
  },
  [
    {
      'id': productId,
      'name': 'Chocolate cake',
      'description': 'Example pricing',
      'kind': 'cake',
      'minimum_quantity': 1,
      'active': true,
      'image_path': null,
      'variants': [
        {
          'id': variantId,
          'label': '2 lb',
          'units': 907,
          'price_paisa': 300000,
          'active': true,
        },
      ],
      'options': [
        {
          'id': finishId,
          'kind': 'finish',
          'label': 'Buttercream',
          'price_paisa': 50000,
          'active': true,
        },
        {
          'id': extraId,
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
      'id': zoneId,
      'name': 'Local delivery',
      'fee_paisa': 30000,
      'active': true,
    },
  ],
);
