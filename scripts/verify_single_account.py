"""Limited real HTTP checks using the confirmed, ignored email-test account.
No emails or privileged keys. Does not substitute for two-baker/customer tests.
Restores the profile name and removes the temporary image in a finally block.
"""
import json
from pathlib import Path
import sys
import uuid
from backend_setup import load_live_config
from verify_backend import Api, PNG, check


def run():
    config = load_live_config('config/local.json')
    creds = json.loads(Path('config/email-check.local.json').read_text())
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    status, login = public.call('POST', '/auth/v1/token?grant_type=password',
                               {'email': creds['email'], 'password': creds['password']})
    check(status == 200, 'Confirmed test account signs in')
    api = Api(public.url, public.key, login['access_token'])
    uid = login['user']['id']
    path = uid + '/' + str(uuid.uuid4()) + '.png'
    original = None
    uploaded = False
    try:
        status, rows = api.call('GET', '/rest/v1/profiles?id=eq.' + uid)
        check(status == 200 and len(rows) == 1, 'Trigger initialized one private profile')
        original = rows[0]['display_name']
        status, _ = api.call('PATCH', '/rest/v1/profiles?id=eq.' + uid, {'display_name': 'Laptop persistence check'})
        check(status == 200, 'Profile write acknowledged')
        status, refresh = public.call('POST', '/auth/v1/token?grant_type=refresh_token',
                                     {'refresh_token': login['refresh_token']})
        check(status == 200, 'Auth refresh succeeds')
        api.token = refresh['access_token']
        status, rows = api.call('GET', '/rest/v1/profiles?id=eq.' + uid)
        check(status == 200 and rows[0]['display_name'] == 'Laptop persistence check', 'Profile persisted across refreshed session')
        status, _ = api.call('PATCH', '/rest/v1/profiles?id=eq.' + uid, {'initial_experience': 'baker'})
        check(status in (401, 403), 'Direct experience assignment rejected')
        status, _ = api.call('POST', '/storage/v1/object/profile-images/' + path, PNG, 'image/png')
        check(status in (200, 201), 'Private image upload succeeds')
        uploaded = True
        status, data = api.call('GET', '/storage/v1/object/authenticated/profile-images/' + path)
        check(status == 200 and data == PNG, 'Owner retrieves identical private bytes')
        status, _ = public.call('GET', '/storage/v1/object/public/profile-images/' + path)
        check(status in (400, 401, 403, 404), 'Existing private object unavailable publicly')
        status, _ = api.call('POST', '/storage/v1/object/sign/profile-images/' + path, {'expiresIn': 60})
        check(status == 200, 'Owner signs private image')
        for bucket in ('order-references', 'conversation-attachments'):
            status, _ = api.call('POST', '/storage/v1/object/' + bucket + '/' + path, PNG, 'image/png')
            check(status in (400, 401, 403), 'Authenticated upload denied: ' + bucket)
    finally:
        try:
            if original is not None:
                status, _ = api.call('PATCH', '/rest/v1/profiles?id=eq.' + uid, {'display_name': original})
                check(status == 200, 'Original profile name restored')
            if uploaded:
                status, _ = api.call('DELETE', '/storage/v1/object/profile-images', {'prefixes': [path]})
                check(status == 200, 'Temporary object removed')
        finally:
            status, _ = api.call('POST', '/auth/v1/logout?scope=local')
            check(status in (200, 204), 'Diagnostic session signed out')


if __name__ == '__main__':
    try:
        run()
    except Exception as error:
        print('FAILED:', type(error).__name__, '(details withheld)')
        sys.exit(1)
