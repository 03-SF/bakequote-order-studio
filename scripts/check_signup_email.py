"""One interactive signup email request; no retries or delivery-success claim.

This checks email transport only, not Flutter PKCE/mobile callback behavior.
Passwords and Auth response bodies are never printed or persisted.
"""
from datetime import datetime, timezone
from getpass import getpass
import sys
from urllib.parse import quote

from backend_setup import SetupError, load_live_config
from verify_backend import Api


def main():
    if not sys.stdin.isatty():
        print('BLOCKED: run in your own interactive terminal; do not pipe credentials.')
        return 2
    config = load_live_config('config/local.json')
    api = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    status, settings = api.call('GET', '/auth/v1/settings')
    if (status != 200 or not isinstance(settings, dict)
            or settings.get('mailer_autoconfirm') is not False
            or not settings.get('external', {}).get('email')
            or settings.get('disable_signup')):
        print('BLOCKED: could not confirm email signup with confirmation required.')
        return 2
    print('Email confirmation is enabled. This sends ONE signup request; do not rerun to resend.')
    print('Use your exact organization-member inbox and a new application-account password.')
    email = input('Organization-member email: ').strip()
    password = getpass('New BakeQuote password (hidden): ')
    if '@' not in email or len(password) < 8:
        print('BLOCKED: enter an email and password of at least eight characters; nothing sent.')
        return 2
    if password != getpass('Repeat password (hidden): '):
        print('BLOCKED: passwords differ; nothing sent.')
        return 2
    print('Request UTC:', datetime.now(timezone.utc).isoformat(timespec='seconds'))
    status, _ = api.call('POST', '/auth/v1/signup?redirect_to=' +
                        quote(config['AUTH_CALLBACK_BASE'] + '/verify', safe=''),
                        {'email': email, 'password': password})
    print('Signup HTTP status:', status)
    print('Receipt UNVERIFIED. Check inbox/spam; do not rerun or share the email link.')
    print('An accepted response alone does not prove delivery or a newly created account.')
    return 0 if 200 <= status < 300 else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SetupError as error:
        print('BLOCKED:', error)
        sys.exit(2)
    except (KeyboardInterrupt, EOFError):
        print('Stopped. If a request had started, its outcome may be unknown; do not retry automatically.')
        sys.exit(2)
    except Exception as error:
        print('Request outcome unknown:', type(error).__name__, '(details withheld). Do not retry automatically.')
        sys.exit(1)
