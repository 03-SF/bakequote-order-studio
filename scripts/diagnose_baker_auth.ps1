param([Parameter(Mandatory = $true)][ValidateSet('BAKER_A', 'BAKER_B')][string]$Role)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$accounts = Import-Clixml -LiteralPath (Join-Path $root 'config/acceptance-accounts.local.xml')
$config = Get-Content -Raw -LiteralPath (Join-Path $root 'config/local.json') | ConvertFrom-Json
$credential = $accounts[$Role]
if ($credential -isnot [System.Management.Automation.PSCredential]) { throw 'Credential unavailable to this Windows account.' }
$body = @{ email = $credential.UserName; password = $credential.GetNetworkCredential().Password } | ConvertTo-Json -Compress
try {
    Add-Type -AssemblyName System.Net.Http
    $client = [System.Net.Http.HttpClient]::new()
    $client.DefaultRequestHeaders.Add('apikey', $config.SUPABASE_PUBLISHABLE_KEY)
    $content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, 'application/json')
    $response = $client.PostAsync("$($config.SUPABASE_URL)/auth/v1/token?grant_type=password", $content).GetAwaiter().GetResult()
    $status = [int]$response.StatusCode
    try { $data = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json } catch { $data = $null }
    if ($status -eq 200) {
        if ($data.user.email_confirmed_at) { Write-Output "$Role : HTTP 200; authenticated; email confirmed in Auth." }
        else { Write-Output "$Role : HTTP 200; authenticated; email confirmation timestamp absent." }
        exit 0
    }
    $code = [string]$data.error_code
    if (-not $code) { $code = [string]$data.error }
    $allowed = @('invalid_credentials', 'invalid_grant', 'email_not_confirmed', 'over_request_rate_limit', 'over_email_send_rate_limit', 'validation_failed', 'user_banned', 'user_not_found')
    if ($code -notin $allowed) { $code = 'unrecognized_or_missing' }
    $message = [string]$data.error_description
    if (-not $message) { $message = [string]$data.msg }
    $allowedMessages = @('Invalid login credentials', 'Email not confirmed', 'User not found', 'Email rate limit exceeded')
    if ($message -notin $allowedMessages) { $message = 'unrecognized_or_missing' }
    Write-Output "$Role : HTTP $status; Auth code: $code; message: $message."
    exit 1
} finally { if ($client) { $client.Dispose() }; $body = $null; $credential = $null; $accounts = $null; $data = $null }
