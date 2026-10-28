"""Development-only backend verification through Auth, PostgREST and Storage HTTP.
No service role is used. Account credentials come only from process environment.
Run against an isolated migrated project. Real registration/email are manual Flutter checks.
"""
import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from backend_setup import SetupError, load_live_config, require_accounts

PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j6XcAAAAASUVORK5CYII=')


class Api:
    def __init__(self, url, key, token=None):
        self.url, self.key, self.token = url.rstrip('/'), key, token

    def call(self, method, path, data=None, mime=None):
        headers = {'apikey': self.key, 'Content-Type': mime or 'application/json'}
        if self.token:
            headers['Authorization'] = 'Bearer ' + self.token
        headers['Prefer'] = 'return=representation'
        body = data if isinstance(data, bytes) else (json.dumps(data).encode() if data is not None else None)
        request = urllib.request.Request(self.url + path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                raw = response.read()
                try:
                    value = json.loads(raw)
                except (ValueError, UnicodeDecodeError):
                    value = raw
                return response.status, value
        except urllib.error.HTTPError as error:
            # Deliberately do not print response bodies or tokens on failures.
            return error.code, None


def check(condition, label):
    if not condition:
        raise AssertionError(label)
    print('PASS:', label)


def run(config):
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    actors = []
    for name, experience in [('CUSTOMER', 'customer'), ('BAKER_A', 'baker'), ('BAKER_B', 'baker')]:
        email, password = os.environ.get('BQ_TEST_' + name + '_EMAIL'), os.environ.get('BQ_TEST_' + name + '_PASSWORD')
        if not email or not password:
            raise ValueError('Set the BQ_TEST_CUSTOMER, BQ_TEST_BAKER_A and BQ_TEST_BAKER_B EMAIL/PASSWORD environment variables')
        code, login = public.call('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        check(code == 200 and login and login.get('access_token'), name + ' signs in')
        actor = Api(public.url, public.key, login['access_token'])
        user_id = login['user']['id']
        code, profiles = actor.call('GET', '/rest/v1/profiles?id=eq.' + user_id)
        check(code == 200 and len(profiles) == 1, name + ' has trigger-initialized profile')
        code, _ = actor.call('POST', '/rest/v1/rpc/complete_identity', {'p_experience': experience, 'p_name': name, 'p_phone': '', 'p_business_name': name + ' test bakery'})
        check(code in (200, 204), name + ' completes identity through RPC')
        actors.append((actor, user_id))
        # Refresh-token restoration is a real Auth request, not a UI assertion.
        code, refreshed = public.call('POST', '/auth/v1/token?grant_type=refresh_token', {'refresh_token': login['refresh_token']})
        check(code == 200 and refreshed.get('user', {}).get('id') == user_id, name + ' refreshes session')
        actor.token = refreshed['access_token']
    customer, baker_a, baker_b = actors
    actor, uid = customer
    other, other_id = baker_a
    code, data = public.call('GET', '/rest/v1/profiles')
    check(code in (401, 403), 'Anonymous private profile reads rejected')
    code, data = actor.call('GET', '/rest/v1/profiles?id=eq.' + other_id)
    check(code == 200 and data == [], 'Another private profile is invisible')
    code, data = actor.call('PATCH', '/rest/v1/profiles?id=eq.' + other_id, {'phone': 'unauthorized'})
    check(code == 200 and data == [], 'Another profile cannot be modified')
    code, _ = actor.call('PATCH', '/rest/v1/profiles?id=eq.' + uid, {'initial_experience': 'baker'})
    check(code in (401, 403), 'Experience cannot be assigned directly')
    code, _ = actor.call('POST', '/rest/v1/rpc/complete_identity', {'p_experience': 'admin', 'p_name': 'No', 'p_phone': '', 'p_business_name': ''})
    check(code in (400, 403), 'Admin/operator role cannot be assigned')
    code, rows = baker_a[0].call('GET', '/rest/v1/businesses')
    check(code == 200 and len(rows) == 1 and rows[0]['owner_id'] == baker_a[1], 'Baker A sees own business only')
    business_id = rows[0]['id']
    code, data = baker_b[0].call('PATCH', '/rest/v1/businesses?id=eq.' + business_id, {'name': 'unauthorized'})
    check(code == 200 and data == [], 'Baker B cannot modify baker A business')
    code, _ = baker_a[0].call('PATCH', '/rest/v1/businesses?id=eq.' + business_id, {'owner_id': baker_b[1]})
    check(code in (401, 403), 'Ownership cannot be transferred by client')
    path = uid + '/' + str(uuid.uuid4()) + '.png'
    code, _ = actor.call('POST', '/storage/v1/object/profile-images/' + path, PNG, 'image/png')
    check(code in (200, 201), 'Owner profile image upload succeeds')
    try:
        code, _ = actor.call('POST', '/storage/v1/object/sign/profile-images/' + path, {'expiresIn': 60})
        check(code == 200, 'Owner can sign private image')
        code, _ = other.call('GET', '/storage/v1/object/authenticated/profile-images/' + path)
        check(code in (400, 401, 403, 404), 'Unrelated user cannot download private image')
        code, _ = public.call('GET', '/storage/v1/object/public/profile-images/' + path)
        check(code in (400, 401, 403, 404), 'Private image has no public download URL')
        code, _ = other.call('POST', '/storage/v1/object/sign/profile-images/' + path, {'expiresIn': 60})
        check(code in (400, 401, 403, 404), 'Unrelated user cannot sign private image')
        code, _ = other.call('POST', '/storage/v1/object/profile-images/' + uid + '/' + str(uuid.uuid4()) + '.png', PNG, 'image/png')
        check(code in (400, 401, 403), 'Unrelated user cannot upload into owner path')
        for bucket in ['order-references', 'conversation-attachments', 'product-images']:
            code, _ = actor.call('POST', '/storage/v1/object/' + bucket + '/' + uid + '/' + str(uuid.uuid4()) + '.png', PNG, 'image/png')
            check(code in (400, 401, 403), bucket + ' uploads remain denied')
    finally:
        actor.call('DELETE', '/storage/v1/object/profile-images', {'prefixes': [path]})
    image_path = business_id + '/profile/' + str(uuid.uuid4()) + '.png'
    code, _ = baker_a[0].call('POST', '/storage/v1/object/business-images/' + image_path, PNG, 'image/png')
    check(code in (200, 201), 'Business owner image upload succeeds')
    try:
        code, _ = public.call('GET', '/storage/v1/object/public/business-images/' + image_path)
        check(code == 200, 'Business image bytes are intentionally public')
        code, _ = baker_b[0].call('POST', '/storage/v1/object/business-images/' + business_id + '/profile/' + str(uuid.uuid4()) + '.png', PNG, 'image/png')
        check(code in (400, 401, 403), 'Other baker cannot upload business image')
    finally:
        baker_a[0].call('DELETE', '/storage/v1/object/business-images', {'prefixes': [image_path]})
    # Do not send hosted signup to an invented example.test mailbox. A response
    # for an existing address can also conceal enumeration, so real signup and
    # delivered-email checks must be observed from Flutter with a fresh inbox.
    print('MANUAL REQUIRED: fresh Flutter registration, delivered verification/resend and password recovery are not verified by this HTTP suite.')
    for api, _ in actors:
        code, _ = api.call('POST', '/auth/v1/logout?scope=local')
        check(code in (200, 204), 'Test session signed out')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='config/local.json')
    parser.add_argument('--preflight-only', action='store_true', help='Validate inputs without making network requests')
    args = parser.parse_args()
    try:
        config = load_live_config(args.config)
        require_accounts(('CUSTOMER', 'BAKER_A', 'BAKER_B'))
        if args.preflight_only:
            print('Setup inputs present. Project identity and live behavior remain unverified; no requests made.')
            return 0
        run(config)
    except SetupError as error:
        print('BLOCKED:', str(error), file=sys.stderr)
        return 2
    except (OSError, ValueError, AssertionError, KeyError, urllib.error.URLError) as error:
        # Exception text from network operations may contain sensitive URLs.
        print('FAILED:', str(error) if isinstance(error, (ValueError, AssertionError, KeyError)) else type(error).__name__, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
