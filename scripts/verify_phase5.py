"""Phase 5 positive acceptance on dedicated development accounts/catalog only.

Creates one persistent Pending test request and private reference. No production
transition or automatic deletion. Credentials come only from BQ_TEST_* variables.
"""
import argparse
import os
import sys
import uuid
from backend_setup import load_live_config, require_accounts, SetupError
from verify_backend import Api, PNG, check


def run(config):
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    actors = []
    try:
        for role in ('CUSTOMER', 'BAKER_A', 'BAKER_B'):
            status, data = public.call('POST', '/auth/v1/token?grant_type=password', {
                'email': os.environ['BQ_TEST_' + role + '_EMAIL'],
                'password': os.environ['BQ_TEST_' + role + '_PASSWORD']})
            check(status == 200 and data['user'].get('email_confirmed_at'), role + ' verified ordinary session')
            actors.append((Api(public.url, public.key, data['access_token']), data['user']['id']))
        check(len({u for _, u in actors}) == 3, 'Three distinct identities')
        (customer, uid), (baker, _), (other, _) = actors
        def rpc(api, name, body):
            status, data = api.call('POST', '/rest/v1/rpc/' + name, body)
            assert status in (200, 204), name + ' failed (response body withheld)'
            return data
        status, businesses = baker.call('GET', '/rest/v1/businesses?onboarding_complete=eq.true')
        if status != 200 or len(businesses) != 1:
            raise SetupError('Baker A needs one activated dedicated test bakery.')
        business = businesses[0]
        menu = rpc(customer, 'public_menu', {'p_code': business['code']})
        if not menu:
            raise SetupError('Baker A needs an active product with active variants.')
        product = menu[0]
        catalog = rpc(customer, 'request_catalog', {'p_business_id': business['id'], 'p_product_id': product['id']})
        calendar = rpc(customer, 'bakery_availability', {'p_code': business['code'], 'p_days': 62})
        dates = [d['date'] for d in calendar['days'] if d['state'] == 'available']
        if not dates:
            raise SetupError('Baker A needs a configured available date within 62 days.')
        draft = rpc(customer, 'open_request_draft', {'p_business_id': business['id']})
        if draft['input']:
            raise SetupError('Existing unsent draft found. Finish it first; the runner will not overwrite it.')
        delivery = not catalog['pickup']
        if delivery and not catalog['zones']:
            raise SetupError('The test bakery needs pickup or an active delivery zone.')
        path = uid + '/' + draft['id'] + '/' + str(uuid.uuid4()) + '.png'
        rpc(customer, 'register_request_upload', {'p_draft_id': draft['id'], 'p_path': path})
        status, _ = customer.call('POST', '/storage/v1/object/order-references/' + path, PNG, 'image/png')
        check(status in (200, 201), 'Customer uploads registered private reference')
        status, _ = baker.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status in (400, 401, 403, 404), 'Baker cannot read unsent draft reference')
        p = catalog['product']
        if not p['variants']:
            raise SetupError('The dedicated product needs an active size/pack variant.')
        price = p['variants'][0]['price_paisa']
        minimum = business['minimum_paisa']
        if price == 0 and minimum > 0:
            raise SetupError('Use a test variant whose base price can meet the bakery minimum.')
        quantity = max(p['minimum_quantity'], (minimum + price - 1) // price if price else 1)
        if quantity > 10000:
            raise SetupError('The selected test variant cannot meet the minimum within the quantity bound.')
        value = {'product_id': product['id'], 'variant_id': p['variants'][0]['id'], 'option_ids': [],
                 'quantity': quantity, 'service_date': dates[0],
                 'fulfilment': 'delivery' if delivery else 'pickup',
                 'zone_id': catalog['zones'][0]['id'] if delivery else None,
                 'address': 'Dedicated integration fixture address' if delivery else '',
                 'contact_name': 'Integration customer', 'phone': '03000000000',
                 'cake_message': '', 'instructions': 'Dedicated development acceptance request', 'attachments': [path]}
        saved = rpc(customer, 'save_request_draft', {'p_id': draft['id'], 'p_revision': draft['revision'], 'p_input': value})
        reviewed = rpc(customer, 'review_request', {'p_id': draft['id'], 'p_revision': saved['revision']})
        order = rpc(customer, 'submit_request', {'p_id': draft['id'], 'p_review_token': reviewed['review_token']})
        check(rpc(customer, 'submit_request', {'p_id': draft['id'], 'p_review_token': reviewed['review_token']}) == order, 'Exact retry returns same persisted order')
        query = '/rest/v1/order_requests?id=eq.' + order
        status, original = customer.call('GET', query)
        check(status == 200 and len(original) == 1 and original[0]['status'] == 'pending', 'Customer retrieves one Pending request')
        status, count = customer.call('GET', '/rest/v1/order_requests?source_draft_id=eq.' + draft['id'])
        check(status == 200 and len(count) == 1, 'Retry persisted exactly one request')
        status, owned = baker.call('GET', query)
        check(status == 200 and owned == original, 'Correct baker retrieves same snapshot')
        status, hidden = other.call('GET', query)
        check(status == 200 and hidden == [], 'Other baker cannot retrieve request')
        other.call('PATCH', query, {'snapshot': {}})
        status, unchanged = customer.call('GET', query)
        check(status == 200 and unchanged == original, 'Denied mutation leaves target snapshot unchanged')
        status, image = baker.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status == 200 and image == PNG, 'Correct baker retrieves original reference bytes')
        status, _ = other.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status in (400, 401, 403, 404), 'Other baker cannot retrieve private attachment')
        other.call('DELETE', '/storage/v1/object/order-references', {'prefixes': [path]})
        customer.call('DELETE', '/storage/v1/object/order-references', {'prefixes': [path]})
        status, image = customer.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status == 200 and image == PNG, 'Denied cleanup cannot remove submitted reference')
        for table in ('request_quotes', 'request_events'):
            status, rows = customer.call('GET', '/rest/v1/' + table + '?order_id=eq.' + order)
            check(status == 200 and len(rows) == 1, table + ' initial record persisted')
        status, login = public.call('POST', '/auth/v1/token?grant_type=password', {'email': os.environ['BQ_TEST_CUSTOMER_EMAIL'], 'password': os.environ['BQ_TEST_CUSTOMER_PASSWORD']})
        assert status == 200
        fresh = Api(public.url, public.key, login['access_token'])
        try:
            status, restored = fresh.call('GET', query)
            check(status == 200 and restored == original, 'Fresh ordinary customer session retrieves saved request')
        finally:
            fresh.call('POST', '/auth/v1/logout?scope=local')
        print('Pending test request retained for browser inspection; IDs and private content withheld.')
    finally:
        for api, _ in actors:
            api.call('POST', '/auth/v1/logout?scope=local')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='config/local.json')
    parser.add_argument('--preflight-only', action='store_true')
    args = parser.parse_args()
    try:
        config = load_live_config(args.config)
        require_accounts(('CUSTOMER', 'BAKER_A', 'BAKER_B'))
        if not args.preflight_only:
            run(config)
    except SetupError as error:
        print('BLOCKED:', str(error))
        sys.exit(1)
    except Exception as error:
        print('FAILED:', str(error) if isinstance(error, AssertionError) else type(error).__name__)
        sys.exit(1)
