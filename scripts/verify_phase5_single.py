"""Limited Phase 5 endpoints with one existing customer. No fixture writes/emails.

This does not prove customer-to-baker order or object access. Separate verified
baker sessions and an owned active catalog are required for positive acceptance.
"""
import json
import sys
from pathlib import Path
from backend_setup import load_live_config
from verify_backend import Api, PNG, check


def run():
    config = load_live_config('config/local.json')
    creds = json.loads(Path('config/email-check.local.json').read_text())
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    status, login = public.call('POST', '/auth/v1/token?grant_type=password', {'email': creds['email'], 'password': creds['password']})
    check(status == 200 and login['user'].get('email_confirmed_at'), 'Confirmed customer ordinary session')
    api = Api(public.url, public.key, login['access_token'])
    missing = '00000000-0000-4000-8000-000000000000'
    try:
        for table in ('request_drafts', 'order_requests', 'request_quotes', 'request_events', 'request_uploads', 'request_attachments'):
            status, rows = api.call('GET', '/rest/v1/' + table + '?limit=20')
            check(status == 200 and isinstance(rows, list), table + ' authorized endpoint readable (single-account scope only)')
            status, _ = public.call('GET', '/rest/v1/' + table + '?limit=1')
            check(status in (401, 403), table + ' anonymous read denied')
        status, value = api.call('POST', '/rest/v1/rpc/request_catalog', {'p_business_id': missing, 'p_product_id': missing})
        check(status == 200 and value is None, 'Unknown catalog returns no private fallback')
        status, _ = api.call('POST', '/rest/v1/rpc/open_request_draft', {'p_business_id': missing})
        check(status == 400, 'Unavailable business cannot create draft')
        status, before = api.call('GET', '/rest/v1/order_requests?select=id&limit=20')
        assert status == 200
        status, _ = api.call('POST', '/rest/v1/rpc/submit_request', {'p_id': missing, 'p_review_token': missing})
        check(status in (401, 403), 'Unknown or unowned draft cannot submit (limited negative check)')
        status, after = api.call('GET', '/rest/v1/order_requests?select=id&limit=20')
        check(status == 200 and before == after, 'Rejected submission leaves visible request set unchanged')
        path = login['user']['id'] + '/' + missing + '/' + missing + '.png'
        status, _ = api.call('POST', '/storage/v1/object/order-references/' + path, PNG, 'image/png')
        check(status in (400, 401, 403), 'Unregistered private reference upload denied')
        status, _ = api.call('GET', '/storage/v1/object/authenticated/order-references/' + path)
        check(status in (400, 401, 403, 404), 'Rejected object is not retrievable')
        status, _ = api.call('POST', '/rest/v1/rpc/request_snapshot', {'p_draft_id': missing})
        check(status in (401, 403), 'Internal snapshot function not executable by client')
        status, _ = api.call('POST', '/rest/v1/rpc/confirm_order_local', {'p_order_id': missing, 'p_expected_version': 1, 'p_quote_version': 1, 'p_local_time': '12:00', 'p_operation_id': missing})
        check(status in (401, 403), 'Missing or unowned order cannot be confirmed')
        status, _ = api.call('POST', '/rest/v1/rpc/request_account_deletion', {'p_confirmation': 'DELETE'})
        check(status in (401, 403), 'Incomplete account deletion endpoint denied')
    finally:
        api.call('POST', '/auth/v1/logout?scope=local')


if __name__ == '__main__':
    try:
        run()
    except Exception as error:
        print('FAILED:', str(error) if isinstance(error, AssertionError) else type(error).__name__)
        sys.exit(1)
