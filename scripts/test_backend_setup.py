import base64
import json
import io
import os
from pathlib import Path
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

from backend_setup import SetupError, load_live_config, require_accounts
import verify_phase6
import verify_phase5
from verify_backend import Api


class BackendSetupTests(unittest.TestCase):
    def test_fixture_plan_wont_overwrite_completed_or_malformed_pair(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixture.json'
            self.assertEqual(verify_phase5.fixture_plan(path), {})
            path.write_text(json.dumps({'order_one': 'first'}), encoding='utf-8')
            self.assertEqual(verify_phase5.fixture_plan(path)['order_one'], 'first')
            path.write_text(json.dumps({'order_one': 'first', 'order_two': 'second'}), encoding='utf-8')
            with self.assertRaises(SetupError):
                verify_phase5.fixture_plan(path)
            path.write_text('{}', encoding='utf-8')
            with self.assertRaises(SetupError):
                verify_phase5.fixture_plan(path)
    def test_phase6_refuses_config_from_a_different_linked_project(self):
        with patch('verify_phase6.Path.read_text', return_value='dev-project'):
            verify_phase6.require_linked_project({'SUPABASE_URL': 'https://dev-project.supabase.co'})
            with self.assertRaisesRegex(SetupError, 'does not match'):
                verify_phase6.require_linked_project({'SUPABASE_URL': 'https://another-project.supabase.co'})

    def test_backend_error_returns_only_whitelisted_sqlstate(self):
        payload = b'{"code":"40001","message":"private content","details":"private token"}'
        error = urllib.error.HTTPError('https://example.invalid', 500, 'Error', {}, io.BytesIO(payload))
        with patch('urllib.request.urlopen', side_effect=error):
            status, result = Api('https://example.invalid', 'public').call('POST', '/rpc', {}, include_error_code=True)
        self.assertEqual((status, result), (500, {'code': '40001'}))

    def test_phase6_requires_explicit_disposable_fixture_flag(self):
        environment = {f'BQ_TEST_{role}_{field}': 'fixture' for role in verify_phase6.ROLES for field in ('EMAIL', 'PASSWORD')}
        environment.update({'BQ_PHASE6_ORDER_ONE': '00000000-0000-4000-8000-000000000001', 'BQ_PHASE6_ORDER_TWO': '00000000-0000-4000-8000-000000000002'})
        with patch.dict(os.environ, environment, clear=True), patch('sys.argv', ['verify_phase6.py']), patch.object(verify_phase6, 'load_live_config', return_value={}), patch.object(verify_phase6, 'run') as run:
            self.assertEqual(verify_phase6.main(), 2)
            run.assert_not_called()
    def test_phase6_requires_two_distinct_valid_fixture_ids(self):
        fixture = '00000000-0000-4000-8000-000000000001'
        with patch.dict(os.environ, {'BQ_PHASE6_ORDER_ONE': fixture, 'BQ_PHASE6_ORDER_TWO': fixture}, clear=True):
            with self.assertRaisesRegex(SetupError, 'distinct'):
                verify_phase6.order_ids()
        with patch.dict(os.environ, {'BQ_PHASE6_ORDER_ONE': 'invalid'}, clear=True):
            with self.assertRaisesRegex(SetupError, 'BQ_PHASE6_ORDER_ONE'):
                verify_phase6.order_ids()

    def test_phase6_preflight_makes_no_live_requests(self):
        environment = {f'BQ_TEST_{role}_{field}': 'fixture' for role in verify_phase6.ROLES for field in ('EMAIL', 'PASSWORD')}
        environment.update({'BQ_PHASE6_ORDER_ONE': '00000000-0000-4000-8000-000000000001', 'BQ_PHASE6_ORDER_TWO': '00000000-0000-4000-8000-000000000002'})
        with patch.dict(os.environ, environment, clear=True), patch('sys.argv', ['verify_phase6.py', '--preflight-only']), patch.object(verify_phase6, 'load_live_config', return_value={}), patch.object(verify_phase6, 'run') as run:
            self.assertEqual(verify_phase6.main(), 0)
            run.assert_not_called()
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'local.json'
        self.config = {
            'APP_MODE': 'live',
            'SUPABASE_URL': 'https://example.invalid',
            'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_synthetic_test_value',
            'AUTH_CALLBACK_BASE': 'dev.bakequote.mobile://auth',
        }

    def load(self):
        self.path.write_text(json.dumps(self.config), encoding='utf-8')
        return load_live_config(self.path)

    def test_missing_file_explains_required_file_and_guide(self):
        with self.assertRaisesRegex(SetupError, 'config/local.json'):
            load_live_config(self.path)

    def test_preview_cannot_run_live_mutations(self):
        self.config['APP_MODE'] = 'preview'
        with self.assertRaisesRegex(SetupError, 'preview is isolated'):
            self.load()

    def test_privileged_key_is_rejected_without_echo(self):
        self.config['SUPABASE_PUBLISHABLE_KEY'] = 'sb_secret_fake'
        with self.assertRaises(SetupError) as error:
            self.load()
        self.assertNotIn('synthetic_do_not_echo', str(error.exception))

    def test_empty_key_identifies_field(self):
        self.config['SUPABASE_PUBLISHABLE_KEY'] = ''
        with self.assertRaisesRegex(SetupError, 'SUPABASE_PUBLISHABLE_KEY'):
            self.load()

    def test_legacy_anon_allowed_but_service_role_rejected(self):
        for role in ('anon', 'service_role'):
            payload = base64.urlsafe_b64encode(json.dumps({'role': role}).encode()).decode().rstrip('=')
            self.config['SUPABASE_PUBLISHABLE_KEY'] = 'e30.' + payload + '.synthetic'
            if role == 'anon':
                self.assertEqual(self.load(), self.config)
            else:
                with self.assertRaises(SetupError):
                    self.load()

    def test_url_credentials_and_remote_http_rejected(self):
        for url in ('https://user:private@example.invalid', 'http://example.invalid',
                    'https://example.invalid?token=private'):
            self.config['SUPABASE_URL'] = url
            with self.assertRaises(SetupError) as error:
                self.load()
            self.assertNotIn('private', str(error.exception))

    def test_placeholder_and_invalid_callback_rejected(self):
        self.config['SUPABASE_PUBLISHABLE_KEY'] = 'sb_publishable_REPLACE_ME'
        with self.assertRaises(SetupError):
            self.load()
        self.config['SUPABASE_PUBLISHABLE_KEY'] = 'sb_publishable_synthetic'
        self.config['AUTH_CALLBACK_BASE'] = 'https://unapproved.invalid/auth'
        with self.assertRaisesRegex(SetupError, 'AUTH_CALLBACK_BASE'):
            self.load()

    def test_valid_native_and_local_web_configuration(self):
        self.assertEqual(self.load(), self.config)
        self.config['SUPABASE_URL'] = 'http://127.0.0.1:54321'
        self.config['AUTH_CALLBACK_BASE'] = 'http://localhost:7357/auth'
        self.assertEqual(self.load(), self.config)

    def test_malformed_json_never_echoes_contents(self):
        self.path.write_text('{"private-token": secret', encoding='utf-8')
        with self.assertRaises(SetupError) as error:
            load_live_config(self.path)
        self.assertNotIn('private-token', str(error.exception))

    def test_all_accounts_checked_before_network_operations(self):
        with patch.dict(os.environ, {'BQ_TEST_CUSTOMER_EMAIL': 'private@example.test'}, clear=True):
            with self.assertRaises(SetupError) as error:
                require_accounts(('CUSTOMER', 'BAKER_A', 'BAKER_B'))
        self.assertIn('BQ_TEST_BAKER_B_PASSWORD', str(error.exception))
        self.assertNotIn('private@example.test', str(error.exception))


if __name__ == '__main__':
    unittest.main()
