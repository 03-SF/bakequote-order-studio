"""Limited live Phase 4 checks with existing confirmed customer; no emails or fixtures."""
import json
import sys
from pathlib import Path
from backend_setup import load_live_config
from verify_backend import Api, check

def run():
    config = load_live_config('config/local.json')
    creds = json.loads(Path('config/email-check.local.json').read_text())
    public = Api(config['SUPABASE_URL'], config['SUPABASE_PUBLISHABLE_KEY'])
    status, login = public.call('POST','/auth/v1/token?grant_type=password', {'email': creds['email'],'password': creds['password']})
    check(status == 200 and login['user'].get('email_confirmed_at'), 'Existing customer email remains confirmed')
    api = Api(public.url,public.key,login['access_token'])
    try:
        status, profile = api.call('GET','/rest/v1/profiles?select=initial_experience')
        check(status == 200 and profile[0]['initial_experience'] == 'customer', 'Existing customer identity confirmed')
        status, result = public.call('POST','/rest/v1/rpc/bakery_availability',{'p_code':'0'*32})
        check(status == 200 and result is None,'Unknown bakery exposes no calendar')
        status, _ = api.call('POST','/rest/v1/rpc/bakery_availability',{'p_code':'0'*32,'p_days':63})
        check(status == 400,'Oversized calendar rejected')
        status, _ = api.call('POST','/rest/v1/rpc/bakery_availability',{'p_code':'0'*32,'p_start':'2026-02-30'})
        check(status == 400,'Invalid date rejected by backend')
        status, result = api.call('POST','/rest/v1/rpc/recent_bakeries',{})
        check(status == 200 and isinstance(result,list) and len(result)<=20,'Own recent list bounded and readable')
        status, _ = public.call('POST','/rest/v1/rpc/recent_bakeries',{})
        check(status in (401,403),'Anonymous recent list denied')
        status, _ = api.call('GET','/rest/v1/capacity_allocations')
        check(status in (401,403),'Raw occupancy unavailable to customer')
        status, _ = api.call('POST','/rest/v1/rpc/save_availability',{'p_business_id':'00000000-0000-4000-8000-000000000000','p_revision':0,'p_timezone':'UTC','p_lead_days':0,'p_capacity':1})
        check(status in (401,403),'Unowned settings mutation denied (missing target, limited check)')
    finally:
        api.call('POST','/auth/v1/logout?scope=local')

if __name__ == '__main__':
    try:
        run()
    except Exception as error:
        print('FAILED:', str(error) if isinstance(error,AssertionError) else type(error).__name__)
        sys.exit(1)
