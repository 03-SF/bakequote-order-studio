"""Non-network setup validation shared by development HTTP test runners.

Never includes supplied values in diagnostics. This is not project verification.
"""
import base64
import json
import os
from pathlib import Path
from urllib.parse import urlsplit


class SetupError(ValueError):
    pass


def load_live_config(path):
    try:
        with Path(path).open(encoding='utf-8-sig') as handle:
            config = json.load(handle)
    except FileNotFoundError:
        raise SetupError(
            'Live configuration file is missing. From mobile, copy '
            'config/example.json to ignored config/local.json, fill the development '
            'URL/public key, and pass --config config/local.json. '
            'See docs/hosted-development-setup.md.'
        ) from None
    except (ValueError, UnicodeError):
        raise SetupError('Configuration must be valid UTF-8 JSON; values withheld.') from None
    if not isinstance(config, dict) or config.get('APP_MODE') != 'live':
        raise SetupError('HTTP verification requires APP_MODE=live; preview is isolated.')
    for field in ('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY', 'AUTH_CALLBACK_BASE'):
        if not isinstance(config.get(field), str) or not config[field].strip():
            raise SetupError('Set ' + field + ' in the ignored live configuration.')
    url, key = config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY']
    try:
        parsed = urlsplit(url)
        valid = (parsed.hostname and not parsed.username and not parsed.password
                 and not parsed.query and not parsed.fragment and parsed.path in ('', '/')
                 and (parsed.scheme == 'https' or (parsed.scheme == 'http'
                      and parsed.hostname in ('localhost', '127.0.0.1', '10.0.2.2'))))
        parsed.port  # Reject malformed port without printing the supplied URL.
    except ValueError:
        valid = False
    if not valid or any(part in url.lower() for part in ('<', '>', 'your-project', 'replace_')):
        raise SetupError('Set SUPABASE_URL to the actual development API URL; hosted URLs require HTTPS.')
    if key.startswith('sb_secret_'):
        raise SetupError('Privileged keys are forbidden. Use the public publishable/anon client key.')
    if key.startswith('sb_publishable_'):
        valid_key = len(key) > len('sb_publishable_') and not any(
            marker in key.lower() for marker in ('<', '>', 'replace', 'your_'))
    else:
        try:
            payload = key.split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            valid_key = claims.get('role') == 'anon'
        except (ValueError, IndexError, AttributeError, UnicodeError):
            valid_key = False
    if not valid_key:
        raise SetupError('Set SUPABASE_PUBLISHABLE_KEY to a public publishable/anon key; no privileged keys or placeholders.')
    callback = config['AUTH_CALLBACK_BASE']
    try:
        cb = urlsplit(callback)
        valid_callback = callback == 'dev.bakequote.mobile://auth' or (
            cb.scheme == 'http' and cb.hostname in ('localhost', '127.0.0.1')
            and cb.path == '/auth' and not cb.username and not cb.password
            and not cb.query and not cb.fragment)
    except ValueError:
        valid_callback = False
    if not valid_callback:
        raise SetupError('Use AUTH_CALLBACK_BASE=dev.bakequote.mobile://auth for native, or http://localhost:7357/auth for optional web.')
    return config


def require_accounts(roles):
    missing = [f'BQ_TEST_{role}_{field}' for role in roles
               for field in ('EMAIL', 'PASSWORD')
               if not os.environ.get(f'BQ_TEST_{role}_{field}')]
    if missing:
        raise SetupError('Missing test-account environment variables: ' + ', '.join(missing)
                         + '. Use secure local prompts in docs/integration-verification.md '
                         'and run tests in that same terminal. Do not paste credentials into chat.')
