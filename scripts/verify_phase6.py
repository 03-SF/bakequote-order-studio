"""Live Phase 5/6 acceptance on two existing disposable Pending requests.

This changes quotes, agreements, and order statuses, and occupies a capacity
slot in a dedicated development bakery. It does not change bakery settings or
delete test data. The winning test order is advanced through Delivered.
Credentials and UUIDs are read from process environment; nothing is logged.
"""
import argparse
import os
import sys
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlsplit
from backend_setup import SetupError, load_live_config, require_accounts
from verify_backend import Api, check


ROLES = ('CUSTOMER', 'BAKER_A', 'BAKER_B')


def order_ids():
    result = []
    for name in ('BQ_PHASE6_ORDER_ONE', 'BQ_PHASE6_ORDER_TWO'):
        try:
            result.append(str(uuid.UUID(os.environ.get(name, ''))))
        except ValueError:
            raise SetupError('Set ' + name + ' to a dedicated Pending order UUID in this terminal.') from None
    if result[0] == result[1]:
        raise SetupError('Two distinct Pending order UUIDs are required.')
    return result


def list_candidates(config):
    """Print test request UUIDs and service dates locally, never tokens or contact data."""
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    status, login = public.call('POST', '/auth/v1/token?grant_type=password', {
        'email': os.environ['BQ_TEST_CUSTOMER_EMAIL'],
        'password': os.environ['BQ_TEST_CUSTOMER_PASSWORD']})
    check(status == 200 and login['user'].get('email_confirmed_at'), 'Customer has a verified ordinary session')
    customer = Api(public.url, public.key, login['access_token'])
    try:
        status, rows = customer.call('GET', '/rest/v1/order_requests?status=eq.pending&source=eq.app&select=id,snapshot&order=created_at.desc&limit=50')
        check(status == 200, 'Customer can list own Pending requests')
        for row in rows:
            print('Pending test candidate:', row['id'], 'service date:', row['snapshot'].get('service_date', 'unknown'))
        if not rows:
            print('BLOCKED: Create two dedicated Pending requests in the same bakery for the same future date.')
        return bool(rows)
    finally:
        customer.call('POST', '/auth/v1/logout?scope=local')


def require_linked_project(config):
    """Refuse mutations if the configured hosted URL differs from the linked project."""
    try:
        project_ref = Path('supabase/.temp/project-ref').read_text(encoding='utf-8').strip()
    except OSError:
        raise SetupError('Link the intended development project using the Supabase CLI before this mutating runner.') from None
    if not project_ref or urlsplit(config['SUPABASE_URL']).hostname != project_ref + '.supabase.co':
        raise SetupError('Configured URL does not match the linked hosted project. Verify the development project before proceeding.')


def run(config, ids):
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    actors = []
    try:
        for role in ROLES:
            status, data = public.call('POST', '/auth/v1/token?grant_type=password', {
                'email': os.environ['BQ_TEST_' + role + '_EMAIL'],
                'password': os.environ['BQ_TEST_' + role + '_PASSWORD']})
            check(status == 200 and data['user'].get('email_confirmed_at'), role + ' verified ordinary session')
            actors.append((Api(public.url, public.key, data['access_token']), data['user']['id']))
        check(len({ident for _, ident in actors}) == 3, 'Three distinct accounts')
        (customer, customer_id), (baker, baker_id), (other, _) = actors

        def call(api, name, params):
            status, result = api.call('POST', '/rest/v1/rpc/' + name, params)
            check(status in (200, 204), name + ' accepted')
            return result

        def read(api, order_id):
            status, rows = api.call('GET', '/rest/v1/order_requests?id=eq.' + order_id)
            check(status == 200 and len(rows) == 1, 'Authorized order readable')
            return rows[0]

        orders = [read(customer, oid) for oid in ids]
        if any(o['customer_id'] != customer_id or o['status'] != 'pending' or o.get('source') != 'app' for o in orders):
            raise SetupError('Both IDs must be the test customer’s unsent-to-production Pending app requests.')
        if orders[0]['business_id'] != orders[1]['business_id'] or orders[0]['snapshot']['service_date'] != orders[1]['snapshot']['service_date']:
            raise SetupError('Both test requests must have the same bakery and future service date.')
        business_id = orders[0]['business_id']
        status, businesses = baker.call('GET', '/rest/v1/businesses?id=eq.' + business_id)
        check(status == 200 and len(businesses) == 1 and businesses[0]['owner_id'] == baker_id, 'Baker A owns fixture bakery')
        settings = call(baker, 'owner_availability', {'p_business_id': business_id})
        if settings.get('daily_capacity') != 1 or orders[0]['snapshot']['service_date'] <= settings['today']:
            raise SetupError('Fixture bakery must have daily capacity 1 and both requests on the same future date.')
        calendar = call(customer, 'bakery_availability', {'p_code': businesses[0]['code'], 'p_start': orders[0]['snapshot']['service_date'], 'p_days': 1})
        if not calendar or calendar['days'][0]['state'] != 'available':
            raise SetupError('The dedicated test date must currently have one available capacity slot.')
        path = next(iter(orders[0]['snapshot'].get('attachments', [])), None)
        if not path:
            raise SetupError('The first test request must have a successfully uploaded private reference image.')

        for oid, original in zip(ids, orders):
            check(read(baker, oid) == original, 'Owner and customer see same persisted order')
            status, hidden = other.call('GET', '/rest/v1/order_requests?id=eq.' + oid)
            check(status == 200 and not hidden, 'Other baker cannot read order')
            other.call('PATCH', '/rest/v1/order_requests?id=eq.' + oid, {'status': 'cancelled'})
            check(read(customer, oid) == original, 'Denied mutation leaves order unchanged')
        status, image = baker.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status == 200 and isinstance(image, bytes), 'Owner can read reference')
        status, _ = other.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status in (400, 401, 403, 404), 'Unrelated baker cannot read reference')
        other.call('DELETE', '/storage/v1/object/order-references', {'prefixes': [path]})
        status, unchanged = baker.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status == 200 and unchanged == image, 'Denied storage deletion leaves original bytes unchanged')

        first = orders[0]
        old_version = first['current_quote_version']
        status, quotes = customer.call('GET', '/rest/v1/request_quotes?order_id=eq.' + ids[0] + '&order=version')
        check(status == 200 and any(q['version'] == old_version for q in quotes), 'Customer reads current quote before agreement revision')
        current = next(q for q in quotes if q['version'] == old_version)
        call(customer, 'record_order_agreement', {'p_order_id': ids[0], 'p_quote_version': old_version, 'p_basis': 'Dedicated test agreement', 'p_message_id': None})
        previous_total = current['estimate']['total_paisa']
        if not isinstance(previous_total, int) or not 0 < previous_total <= 9007199254740891:
            raise SetupError('The fixture quote amount cannot be safely revised by the test runner.')
        new_total = previous_total + 100
        updated = {'subtotal_paisa': new_total, 'delivery_paisa': 0, 'total_paisa': new_total,
                   'currency': 'PKR', 'lines': [{'label': 'Revised fixture quote', 'amount_paisa': new_total}]}
        call(baker, 'revise_order_quote', {'p_order_id': ids[0], 'p_expected_version': old_version, 'p_estimate': updated, 'p_reason': 'Dedicated revision acceptance test'})
        revised = read(customer, ids[0])
        check(revised['current_quote_version'] == old_version + 1 and revised['agreed_quote_version'] is None, 'Revision invalidates prior agreement')
        status, error = customer.call('POST', '/rest/v1/rpc/record_order_agreement', {'p_order_id': ids[0], 'p_quote_version': old_version, 'p_basis': 'Stale test', 'p_message_id': None}, include_error_code=True)
        check(status in (400, 409, 500) and error == {'code': '40001'}, 'Stale quote agreement rejected with conflict SQLSTATE')
        status, error = baker.call('POST', '/rest/v1/rpc/confirm_order_local', {'p_order_id': ids[0], 'p_expected_version': revised['version'], 'p_quote_version': revised['current_quote_version'], 'p_local_time': '12:00', 'p_operation_id': str(uuid.uuid4())}, include_error_code=True)
        check(status in (400, 409, 500) and error == {'code': '40001'}, 'Confirmation without revised agreement rejected with conflict SQLSTATE')
        check(read(customer, ids[0]) == revised, 'Rejected confirmation leaves order unchanged')
        for oid in ids:
            current_order = read(customer, oid)
            status, visible_quotes = customer.call('GET', '/rest/v1/request_quotes?order_id=eq.' + oid + '&order=version')
            check(status == 200 and any(q['version'] == current_order['current_quote_version'] for q in visible_quotes), 'Current quote readable before customer agreement')
            call(customer, 'record_order_agreement', {'p_order_id': oid, 'p_quote_version': current_order['current_quote_version'], 'p_basis': 'Dedicated current quote agreement', 'p_message_id': None})
        ready = [read(customer, oid) for oid in ids]
        payloads = [{'p_order_id': oid, 'p_expected_version': row['version'], 'p_quote_version': row['current_quote_version'], 'p_local_time': '12:00', 'p_operation_id': str(uuid.uuid4())} for oid, row in zip(ids, ready)]
        start = threading.Barrier(2, timeout=10)
        def confirm(payload):
            start.wait()
            return baker.call('POST', '/rest/v1/rpc/confirm_order_local', payload, include_error_code=True)
        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(confirm, payloads))
        check(sum(status == 200 for status, _ in outcomes) == 1, 'Exactly one simultaneous last-slot confirmation succeeds')
        check(sum(error == {'code': '23514'} for status, error in outcomes if status != 200) == 1, 'Other confirmation fails on capacity constraint')
        after = [read(customer, oid) for oid in ids]
        check(sorted(o['status'] for o in after) == ['confirmed', 'pending'], 'One order confirmed and one remains pending')
        winner = next(i for i, row in enumerate(after) if row['status'] == 'confirmed')
        status, result = baker.call('POST', '/rest/v1/rpc/confirm_order_local', payloads[winner])
        check(status == 200 and result['id'] == ids[winner], 'Exact confirmation retry returns same order')
        changed = dict(payloads[winner], p_local_time='13:00')
        status, error = baker.call('POST', '/rest/v1/rpc/confirm_order_local', changed, include_error_code=True)
        check(status in (400, 409, 500) and error == {'code': '40001'}, 'Different payload with same operation ID rejected with conflict SQLSTATE')
        check(read(customer, ids[winner]) == after[winner], 'Rejected retry leaves confirmed order unchanged')
        status, login = public.call('POST', '/auth/v1/token?grant_type=password', {'email': os.environ['BQ_TEST_CUSTOMER_EMAIL'], 'password': os.environ['BQ_TEST_CUSTOMER_PASSWORD']})
        check(status == 200 and login['user'].get('email_confirmed_at'), 'Customer signs in again')
        fresh = Api(public.url, public.key, login['access_token'])
        try:
            check(read(fresh, ids[winner]) == after[winner], 'Confirmed order persists in a fresh customer session')
        finally:
            fresh.call('POST', '/auth/v1/logout?scope=local')
        current_order = after[winner]
        for next_status in ('baking', 'ready', 'delivered'):
            transition = {'p_order_id': ids[winner], 'p_expected_version': current_order['version'], 'p_next_status': next_status, 'p_operation_id': str(uuid.uuid4())}
            updated = call(baker, 'transition_order', transition)
            check(updated['status'] == next_status, 'Owner advances to ' + next_status)
            duplicate = call(baker, 'transition_order', transition)
            check(duplicate['id'] == ids[winner] and duplicate['status'] == next_status, 'Exact transition retry remains idempotent')
            current_order = read(customer, ids[winner])
            check(current_order['status'] == next_status and current_order['snapshot'] == after[winner]['snapshot'], 'Customer sees transition with original snapshot intact')
        status, events = customer.call('GET', '/rest/v1/order_events?order_id=eq.' + ids[winner] + '&select=kind')
        check(status == 200 and {'confirmed', 'status_baking', 'status_ready', 'status_delivered'}.issubset({e['kind'] for e in events}), 'Customer can read production event history')
        print('Dedicated test orders retained: one Delivered and one Pending. IDs and private content withheld.')
        return True
    finally:
        for api, _ in actors:
            api.call('POST', '/auth/v1/logout?scope=local')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', default='config/local.json')
    parser.add_argument('--preflight-only', action='store_true')
    parser.add_argument('--list-candidates', action='store_true', help='List only this customer’s Pending fixture IDs and service dates')
    parser.add_argument('--confirm-dedicated-fixtures', action='store_true')
    args = parser.parse_args()
    try:
        config = load_live_config(args.config)
        require_accounts(ROLES)
        if args.list_candidates:
            return 0 if list_candidates(config) else 2
        ids = order_ids()
        if args.preflight_only:
            print('PASS: Inputs present only; no requests or identity verification performed.')
            return 0
        if not args.confirm_dedicated_fixtures:
            raise SetupError('Use --confirm-dedicated-fixtures only with disposable development orders and bakery.')
        require_linked_project(config)
        return 0 if run(config, ids) else 2
    except SetupError as error:
        print('BLOCKED:', str(error))
        return 2
    except AssertionError as error:
        print('FAILED:', str(error))
        return 1
    except Exception as error:
        print('FAILED:', type(error).__name__, '(sensitive details withheld)')
        return 1


if __name__ == '__main__':
    sys.exit(main())
