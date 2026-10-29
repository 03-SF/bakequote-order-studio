param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Setup', 'Preflight', 'List', 'Fixtures', 'Phase5', 'Phase6', 'CrossAccount')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$credentialPath = Join-Path $projectDirectory 'config/acceptance-accounts.local.xml'
$fixturePath = Join-Path $projectDirectory 'config/phase6-fixtures.local.json'
$roles = @('CUSTOMER', 'BAKER_A', 'BAKER_B')
Set-Location -LiteralPath $projectDirectory

if ($Mode -eq 'Setup') {
    if (Test-Path -LiteralPath $credentialPath) {
        throw 'The local acceptance credential file already exists. Keep it or replace it explicitly after verifying its contents.'
    }
    $accountEntries = @{}
    foreach ($role in $roles) {
        $existingCustomer = Join-Path $projectDirectory 'config/email-check.local.json'
        if ($role -eq 'CUSTOMER' -and (Test-Path -LiteralPath $existingCustomer)) {
            $reuse = Read-Host 'Reuse the existing local customer fixture? Type YES to reuse it'
            if ($reuse -ceq 'YES') {
                $storedCustomer = Get-Content -LiteralPath $existingCustomer -Raw | ConvertFrom-Json
                if ([string]::IsNullOrWhiteSpace($storedCustomer.email) -or [string]::IsNullOrWhiteSpace($storedCustomer.password)) {
                    throw 'The local customer fixture lacks an email or password.'
                }
                $protectedCustomer = ConvertTo-SecureString $storedCustomer.password -AsPlainText -Force
                $accountEntries[$role] = [System.Management.Automation.PSCredential]::new($storedCustomer.email.Trim(), $protectedCustomer)
                $storedCustomer = $null
                $protectedCustomer = $null
                continue
            }
        }
        $email = Read-Host "$role email"
        if ([string]::IsNullOrWhiteSpace($email)) { throw "$role email is required." }
        $password = Read-Host "$role password" -AsSecureString
        $accountEntries[$role] = [System.Management.Automation.PSCredential]::new($email.Trim(), $password)
    }
    $accountEntries | Export-Clixml -LiteralPath $credentialPath
    Write-Host 'Saved user-bound Windows-protected credentials locally. No account login or email verification was performed.'
    exit 0
}

if ($Mode -eq 'Fixtures') {
    $first = Read-Host 'First dedicated Pending order UUID'
    $second = Read-Host 'Second dedicated Pending order UUID'
    $id1 = [guid]::Empty
    $id2 = [guid]::Empty
    if (-not [guid]::TryParse($first, [ref]$id1) -or -not [guid]::TryParse($second, [ref]$id2) -or $id1 -eq $id2) {
        throw 'Two different order UUIDs are required; no fixture configuration was saved.'
    }
    if (Test-Path -LiteralPath $fixturePath) {
        throw 'The fixture file already exists. Keep it or explicitly remove it before entering a new pair.'
    }
    @{ order_one = $id1.ToString(); order_two = $id2.ToString() } |
        ConvertTo-Json | Set-Content -LiteralPath $fixturePath -Encoding UTF8
    Write-Host 'Saved local test order identifiers; no live request was made.'
    exit 0
}

if (-not (Test-Path -LiteralPath $credentialPath)) {
    throw 'Missing local acceptance accounts. Run scripts/acceptance_accounts.ps1 -Mode Setup in your own Windows account.'
}

if ($Mode -in @('Phase5', 'Phase6', 'CrossAccount')) {
    $localConfig = Get-Content -LiteralPath (Join-Path $projectDirectory 'config/local.json') -Raw | ConvertFrom-Json
    $linkPath = Join-Path $projectDirectory 'supabase/.temp/project-ref'
    if (-not (Test-Path -LiteralPath $linkPath)) { throw 'Link the confirmed development project before running mutating acceptance checks.' }
    $projectReference = (Get-Content -LiteralPath $linkPath -Raw).Trim()
    $apiHost = ([uri]$localConfig.SUPABASE_URL).Host
    if ($localConfig.APP_MODE -cne 'live' -or $apiHost -cne "$projectReference.supabase.co") {
        throw 'The live configuration does not match the CLI-linked hosted project.'
    }
}

try {
    $accountEntries = Import-Clixml -LiteralPath $credentialPath
    foreach ($role in $roles) {
        $credential = $accountEntries[$role]
        if ($credential -isnot [System.Management.Automation.PSCredential] -or [string]::IsNullOrWhiteSpace($credential.UserName)) {
            throw "The $role local credential is missing or cannot be decrypted by this Windows account."
        }
        [Environment]::SetEnvironmentVariable("BQ_TEST_${role}_EMAIL", $credential.UserName, 'Process')
        [Environment]::SetEnvironmentVariable("BQ_TEST_${role}_PASSWORD", $credential.GetNetworkCredential().Password, 'Process')
    }
    if ($Mode -eq 'Phase6') {
        if (-not (Test-Path -LiteralPath $fixturePath)) {
            throw 'Missing test order identifiers. Run -Mode List, then -Mode Fixtures locally.'
        }
        $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
        [Environment]::SetEnvironmentVariable('BQ_PHASE6_ORDER_ONE', $fixture.order_one, 'Process')
        [Environment]::SetEnvironmentVariable('BQ_PHASE6_ORDER_TWO', $fixture.order_two, 'Process')
    }
    switch ($Mode) {
        'Preflight' { & python scripts/verify_cross_account.py --preflight-only }
        'List' { & python scripts/verify_phase6.py --list-candidates }
        'Phase5' { & python scripts/verify_phase5.py --record-fixture }
        'Phase6' { & python scripts/verify_phase6.py --confirm-dedicated-fixtures }
        'CrossAccount' { & python scripts/verify_cross_account.py }
    }
    $runnerExit = $LASTEXITCODE
    if ($runnerExit -ne 0) { exit $runnerExit }
} finally {
    foreach ($role in $roles) {
        [Environment]::SetEnvironmentVariable("BQ_TEST_${role}_EMAIL", $null, 'Process')
        [Environment]::SetEnvironmentVariable("BQ_TEST_${role}_PASSWORD", $null, 'Process')
    }
    [Environment]::SetEnvironmentVariable('BQ_PHASE6_ORDER_ONE', $null, 'Process')
    [Environment]::SetEnvironmentVariable('BQ_PHASE6_ORDER_TWO', $null, 'Process')
    $accountEntries = $null
    $credential = $null
}
