"""Chrome development check with one confirmed disposable account.

Reads credentials locally; never logs inputs, Auth bodies, tokens or callback URLs.
May complete CUSTOMER onboarding and edits/restores the fixture's display name.
No signup/reset/resend emails. This does not test two-baker authorization.
Install playwright==1.55.0 into build/browser-tools and use installed Chrome.
"""
import json
import re
from pathlib import Path
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build' / 'browser-tools'))
from playwright.sync_api import sync_playwright, expect
from backend_setup import load_live_config
from verify_backend import Api


def run():
    creds = json.loads((ROOT / 'config' / 'email-check.local.json').read_text())
    config = load_live_config(str(ROOT / 'config' / 'local.json'))
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    status, login = public.call('POST', '/auth/v1/token?grant_type=password', {'email': creds['email'], 'password': creds['password']})
    assert status == 200
    api = Api(public.url, public.key, login['access_token'])
    try:
        status, profiles = api.call('GET', '/rest/v1/profiles?select=display_name')
        assert status == 200 and len(profiles) == 1
        original = profiles[0]['display_name']
    finally:
        api.call('POST', '/auth/v1/logout?scope=local')
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='chrome', headless=True)
        context = browser.new_context(viewport={'width': 1280, 'height': 900})
        page = context.new_page()
        page.set_default_timeout(45000)

        def semantics():
            page.locator('flutter-view').wait_for(timeout=90000)
            marker = page.locator('flt-semantics-placeholder')
            if marker.count():
                marker.evaluate('(e)=>e.click()')

        def enter(label, value):
            field = page.get_by_role('textbox', name=label, exact=True)
            field.click()
            field.press('Control+a')
            field.press('Backspace')
            field.press_sequentially(value, delay=30)
            field.press('Tab')

        try:
            page.goto('http://localhost:7357')
            semantics()
            enter('Email', creds['email'])
            enter('Password', creds['password'])
            with page.expect_response(lambda r: '/auth/v1/token' in r.url) as request:
                page.get_by_role('button', name='Sign in', exact=True).click()
            assert request.value.status == 200, 'Live login rejected'
            page.wait_for_url(lambda u: '/auth/onboarding' in str(u) or '/live/customer/' in str(u), timeout=60000)
            print('PASS: Chrome password login received a real Auth session', flush=True)
            if '/auth/onboarding' in page.url:
                enter('Full name', 'Laptop Test Customer')
                with page.expect_response(lambda r: '/rpc/complete_identity' in r.url) as onboarding:
                    page.get_by_role('button', name='Continue', exact=True).click()
                assert onboarding.value.status in (200, 204), 'Onboarding rejected'
            page.wait_for_url('**/live/customer/home', timeout=60000)
            print('PASS: Customer onboarding and protected home route', flush=True)
            page.reload()
            semantics()
            page.wait_for_url('**/live/customer/home', timeout=60000)
            page.get_by_role('textbox', name='Bakery code or shared link').wait_for()
            print('PASS: Browser reload restores session and customer discovery', flush=True)
            page.goto('http://localhost:7357/#/live/customer/account')
            semantics()
            field = page.get_by_role('textbox', name='Full name', exact=True)
            field.wait_for()
            assert original.strip(), 'Expected a populated test profile before editing'
            enter('Full name', 'Laptop network check')
            # Fail only the write request, keeping Auth refresh and all reads real.
            def fail_write(route):
                if route.request.method == 'PATCH':
                    route.abort('internetdisconnected')
                else:
                    route.continue_()
            page.route('**/rest/v1/profiles*', fail_write)
            page.get_by_role('button', name='Save profile', exact=True).click()
            expect(page.get_by_text('Could not complete this action. Check your connection and try again.', exact=True)).to_be_visible()
            assert page.locator('input').evaluate_all('(elements)=>elements.some(e=>e.value === "Laptop network check")'), 'Input lost after failed write'
            print('PASS: Interrupted profile write shows failure and preserves entered text', flush=True)
            page.unroute('**/rest/v1/profiles*', fail_write)
            enter('Full name', original)
            with page.expect_response(lambda r: '/rest/v1/profiles' in r.url and r.request.method == 'PATCH') as saved:
                page.get_by_role('button', name='Save profile', exact=True).click()
            assert saved.value.status == 200, 'Profile restore failed'
            print('PASS: Retry restores profile through an acknowledged live write', flush=True)
            page.get_by_role('button', name='Log out', exact=True).click()
            page.wait_for_url('**/auth/login', timeout=60000)
            page.goto('http://localhost:7357/#/live/customer/account')
            semantics()
            page.get_by_role('textbox', name='Email', exact=True).wait_for()
            print('PASS: Logout clears access; protected account route redirects to login', flush=True)
        except Exception:
            print('Browser route at failure:', urlsplit(page.url).fragment.split('?')[0][:100])
            visible = page.locator('body').inner_text()
            for value in creds.values():
                if isinstance(value, str) and value:
                    visible = visible.replace(value, '[withheld]')
            print('Visible UI at failure:', visible[:1200])
            raise
        finally:
            browser.close()


if __name__ == '__main__':
    try:
        run()
    except Exception as error:
        # Playwright tracebacks may include input values. Report type only.
        print('FAILED:', type(error).__name__, '(details withheld; inspect the failed stage)')
        detail = str(error)
        for source in ('config/email-check.local.json', 'config/local.json'):
            values = json.loads((ROOT / source).read_text())
            for value in values.values():
                if isinstance(value, str) and len(value) > 3:
                    detail = detail.replace(value, '[withheld]')
        detail = re.sub(r'https?://\S+|[\w.+-]+@[\w.-]+', '[withheld]', detail)
        print('Sanitized browser diagnostic:', detail[:500])
        sys.exit(1)
