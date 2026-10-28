import base64
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from backend_setup import SetupError, load_live_config, require_accounts


class BackendSetupTests(unittest.TestCase):
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
