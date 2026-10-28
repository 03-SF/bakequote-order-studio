"""Ordinary-session development checks. Never creates or confirms identities.
Requires three dedicated verified accounts through BQ_TEST_* environment variables.
Denial checks compare target snapshots/bytes, not only HTTP status.
"""
import argparse
import os
import sys
import uuid
from backend_setup import SetupError, load_live_config, require_accounts
from verify_backend import Api, PNG, check


def run(config):
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    actors = []
    try:
        for role in ('CUSTOMER', 'BAKER_A', 'BAKER_B'):
            status, login = public.call('POST', '/auth/v1/token?grant_type=password', {
                'email': os.environ['BQ_TEST_' + role + '_EMAIL'],
                'password': os.environ['BQ_TEST_' + role + '_PASSWORD']})
            check(status == 200 and login['user'].get('email_confirmed_at'), role + ' normal verified session')
            actors.append((Api(public.url, public.key, login['access_token']), login['user']['id']))
        check(len({uid for _, uid in actors}) == 3, 'Three distinct identities')
        customer = actors[0][0]
        for index, other_index in ((1, 2), (2, 1)):
            owner, uid = actors[index]
            other = actors[other_index][0]
            status, rows = owner.call('GET', '/rest/v1/businesses')
            check(status == 200 and len(rows) == 1, 'Baker sees owned business')
            business = rows[0]
            bid, revision = business['id'], business['revision']

            def snapshot():
                result = []
                for table, column in (('businesses', 'id'), ('products', 'business_id'), ('delivery_zones', 'business_id')):
                    status, data = owner.call('GET', '/rest/v1/' + table + '?' + column + '=eq.' + bid + '&order=id')
                    check(status == 200, 'Owner target snapshot readable')
                    result.append(data)
                return result

            before = snapshot()
            for attacker in (other, customer):
                status, _ = attacker.call('POST', '/rest/v1/rpc/save_baker_workspace', {
                    'p_business_id': bid, 'p_revision': revision,
                    'p_business': {}, 'p_products': [], 'p_zones': []})
                check(status in (401, 403), 'Unrelated workspace mutation rejected')
                check(snapshot() == before, 'Denied mutation leaves business and catalog unchanged')
                status, data = attacker.call('GET', '/rest/v1/profiles?id=eq.' + uid)
                check(status == 200 and data == [], 'Private profile hidden from unrelated account')
                status, original_profile = owner.call('GET', '/rest/v1/profiles?id=eq.' + uid)
                check(status == 200, 'Owner profile snapshot available')
                attacker.call('PATCH', '/rest/v1/profiles?id=eq.' + uid, {'display_name': 'Forbidden change'})
                status, after_profile = owner.call('GET', '/rest/v1/profiles?id=eq.' + uid)
                check(status == 200 and after_profile == original_profile, 'Unrelated profile mutation leaves owner data unchanged')
                status, data = attacker.call('GET', '/rest/v1/businesses?id=eq.' + bid)
                check(status == 200 and data == [], 'Private business hidden from unrelated account')
            status, projection = customer.call('POST', '/rest/v1/rpc/public_business', {'p_code': business['code']})
            check(status == 200 and (projection is None or not any(k in projection for k in ('owner_id','contact_phone','owner_name','pickup_address'))), 'Public profile excludes private fields')
            status, settings = owner.call('POST', '/rest/v1/rpc/owner_availability', {'p_business_id': bid})
            check(status == 200, 'Owner settings readable')
            status, _ = other.call('POST', '/rest/v1/rpc/save_availability', {'p_business_id': bid, 'p_revision': settings['revision'], 'p_timezone': 'UTC', 'p_lead_days': 0, 'p_capacity': 1})
            check(status in (401,403), 'Other baker cannot edit availability')
            status, after_settings = owner.call('POST', '/rest/v1/rpc/owner_availability', {'p_business_id': bid})
            check(status == 200 and after_settings == settings, 'Denied availability write leaves target unchanged')
            for bucket, path in (('business-images', bid + '/cover/' + str(uuid.uuid4()) + '.png'), ('profile-images', uid + '/' + str(uuid.uuid4()) + '.png')):
                try:
                    status, _ = owner.call('POST', '/storage/v1/object/' + bucket + '/' + path, PNG, 'image/png')
                    check(status in (200, 201), 'Owner uploads temporary image')
                    status, original = owner.call('GET', '/storage/v1/object/authenticated/' + bucket + '/' + path)
                    check(status == 200, 'Owner can retrieve uploaded object')
                    status, _ = other.call('PUT', '/storage/v1/object/' + bucket + '/' + path, PNG, 'image/png')
                    check(status in (400,401,403), 'Unrelated replacement denied')
                    other.call('DELETE', '/storage/v1/object/' + bucket, {'prefixes': [path]})
                    status, after = owner.call('GET', '/storage/v1/object/authenticated/' + bucket + '/' + path)
                    check(status == 200 and after == original, 'Denied replace/delete leaves existing object unchanged')
                    if bucket == 'profile-images':
                        status, _ = other.call('GET', '/storage/v1/object/authenticated/' + bucket + '/' + path)
                        check(status in (400,401,403,404), 'Known existing private image inaccessible to unrelated user')
                finally:
                    owner.call('DELETE', '/storage/v1/object/' + bucket, {'prefixes': [path]})
    finally:
        for api, _ in actors:
            api.call('POST', '/auth/v1/logout?scope=local')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='config/local.json')
    parser.add_argument('--preflight-only', action='store_true')
    args = parser.parse_args()
    try:
        config = load_live_config(args.config)
        require_accounts(('CUSTOMER','BAKER_A','BAKER_B'))
        if args.preflight_only:
            print('PASS input presence only; no requests made')
        else:
            run(config)
    except SetupError as error:
        print('BLOCKED:', str(error)); return 2
    except Exception as error:
        print('FAILED:', str(error) if isinstance(error, AssertionError) else type(error).__name__); return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
