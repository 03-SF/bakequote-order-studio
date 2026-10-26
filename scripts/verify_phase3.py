"""Phase 3 real development HTTP acceptance. Mutates dedicated fixture businesses.
No service key. Requires explicit development flag and secure test-account env.
"""
import argparse
import json
import os
import sys
import urllib.error
import uuid
from verify_backend import Api, PNG, check


def run(config):
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    actors = []
    for role in ('BAKER_A', 'BAKER_B'):
        email, password = (os.environ.get('BQ_TEST_' + role + suffix) for suffix in ('_EMAIL', '_PASSWORD'))
        if not email or not password:
            raise ValueError('Supply BQ_TEST_BAKER_A and BQ_TEST_BAKER_B EMAIL/PASSWORD through secure local prompts')
        status, login = public.call('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        check(status == 200, role + ' authenticated')
        api = Api(public.url, public.key, login['access_token'])
        status, businesses = api.call('GET', '/rest/v1/businesses')
        check(status == 200 and len(businesses) == 1, role + ' sees one owned business')
        actors.append((api, businesses[0]))
    (a, business), (b, _) = actors
    bid, revision = business['id'], business['revision']
    status, _ = b.call('POST', '/rest/v1/rpc/activate_business', {'p_business_id': bid, 'p_revision': revision})
    check(status in (401, 403), 'Cross-baker activation denied')
    pid, vid, fid, eid, zid = (str(uuid.uuid4()) for _ in range(5))
    product = {'id': pid, 'name': 'Phase 3 regression fixture', 'description': 'Dedicated test only', 'kind': 'cake', 'active': True, 'minimum_quantity': 1,
               'variants': [{'id': vid, 'label': '2 lb', 'units': 907, 'price_paisa': 300000, 'active': True}],
               'options': [{'id': fid, 'kind': 'finish', 'label': 'Buttercream', 'price_paisa': 50000, 'active': True}, {'id': eid, 'kind': 'extra', 'label': 'Topper', 'price_paisa': 30000, 'active': True}]}
    details = dict(business, description='Public regression description', owner_name='Private fixture owner', contact_phone='Private fixture phone', location='Public fixture area', pickup_address='Private fixture address', pickup_enabled=True, delivery_enabled=True, minimum_paisa=0)
    zones = [{'id': zid, 'name': 'Regression zone', 'fee_paisa': 30000, 'active': True}]
    payload = {'p_business_id': bid, 'p_revision': revision, 'p_business': details, 'p_products': [product], 'p_zones': zones}
    status, _ = b.call('POST', '/rest/v1/rpc/save_baker_workspace', payload)
    check(status in (401, 403), 'Cross-baker catalog mutation denied')
    status, new_revision = a.call('POST', '/rest/v1/rpc/save_baker_workspace', payload)
    check(status == 200, 'Business/catalog/zone saved')
    status, _ = a.call('POST', '/rest/v1/rpc/save_baker_workspace', payload)
    check(status == 409, 'Stale repeat cannot duplicate products')
    status, revision = a.call('POST', '/rest/v1/rpc/activate_business', {'p_business_id': bid, 'p_revision': new_revision})
    check(status == 200, 'Complete business activated')
    status, projection = public.call('POST', '/rest/v1/rpc/public_business', {'p_code': business['code']})
    check(status == 200 and projection['name'] == business['name'] and not any(k in projection for k in ('owner_id', 'owner_name', 'contact_phone', 'pickup_address')), 'Public projection excludes private details')
    estimate = {'p_product_id': pid, 'p_variant_id': vid, 'p_option_ids': [fid, eid], 'p_quantity': 1, 'p_zone_id': zid}
    status, price = a.call('POST', '/rest/v1/rpc/catalog_estimate', estimate)
    check(status == 200 and price['subtotal_paisa'] == 380000 and price['total_paisa'] == 410000, 'Backend PKR 4100 fixture')
    path = bid + '/' + pid + '/' + str(uuid.uuid4()) + '.png'
    try:
        status, _ = a.call('POST', '/storage/v1/object/product-images/' + path, PNG, 'image/png')
        check(status in (200, 201), 'Owner product upload')
        status, _ = public.call('GET', '/storage/v1/object/public/product-images/' + path)
        check(status == 200, 'Product image bytes public')
        status, _ = b.call('POST', '/storage/v1/object/product-images/' + bid + '/' + pid + '/' + str(uuid.uuid4()) + '.png', PNG, 'image/png')
        check(status in (400, 401, 403), 'Other baker upload denied')
        status, revision = a.call('POST', '/rest/v1/rpc/set_baker_image', {'p_business_id': bid, 'p_revision': revision, 'p_slot': 'product', 'p_product_id': pid, 'p_path': path})
        check(status == 200, 'Product image attached')
        status, revision = a.call('POST', '/rest/v1/rpc/set_baker_image', {'p_business_id': bid, 'p_revision': revision, 'p_slot': 'product', 'p_product_id': pid, 'p_path': None})
        check(status == 200, 'Product image detached before cleanup')
    finally:
        a.call('DELETE', '/storage/v1/object/product-images', {'prefixes': [path]})
    product['active'] = False
    payload.update(p_revision=revision)
    status, _ = a.call('POST', '/rest/v1/rpc/save_baker_workspace', payload)
    check(status == 200, 'Product deactivated and record retained')
    status, _ = a.call('POST', '/rest/v1/rpc/catalog_estimate', estimate)
    check(status == 400, 'Inactive product cannot be priced')
    for api, _ in actors:
        api.call('POST', '/auth/v1/logout?scope=local')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='config/local.json')
    parser.add_argument('--confirm-development', action='store_true', required=True, help='Only dedicated disposable businesses; replaces their catalog/zone availability')
    args = parser.parse_args()
    try:
        with open(args.config, encoding='utf-8-sig') as handle:
            run(json.load(handle))
    except (OSError, ValueError, AssertionError, KeyError, urllib.error.URLError) as error:
        print('FAILED:', str(error) if isinstance(error, (ValueError, AssertionError, KeyError)) else type(error).__name__, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
