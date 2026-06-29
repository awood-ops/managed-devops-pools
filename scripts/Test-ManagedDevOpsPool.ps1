<#
.SYNOPSIS
    Validates that a Managed DevOps Pool deployment is correctly provisioned.

.DESCRIPTION
    Checks that all resources created by the MDP Bicep deployment exist and are in a healthy state:
      - Resource group
      - Dev Center
      - Dev Center Project
      - Managed DevOps Pool (Microsoft.DevOpsInfrastructure/pools)
      - Pool configuration (org URL, concurrency, lifecycle)

    Exits with code 1 if any check fails — suitable for use in CI pipelines.

    Requires Azure CLI with the devcenter extension: az extension add --name devcenter

.PARAMETER ResourceGroupName
    Resource group containing the Managed DevOps Pool resources.

.PARAMETER DevCenterName
    Name of the Dev Center. Default: dc-devops-prd

.PARAMETER DevCenterProjectName
    Name of the Dev Center Project. Default: dc-project-devops-prd

.PARAMETER PoolName
    Name of the Managed DevOps Pool. Default: mdp-windows-prd

.PARAMETER OrganizationUrl
    Expected Azure DevOps organisation URL — validated against pool config.

.EXAMPLE
    .\Test-ManagedDevOpsPool.ps1 -ResourceGroupName rg-devops-agents-prd -OrganizationUrl https://dev.azure.com/my-org
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [string] $DevCenterName        = 'dc-devops-prd',
    [string] $DevCenterProjectName = 'dc-project-devops-prd',
    [string] $PoolName             = 'mdp-windows-prd',
    [string] $OrganizationUrl      = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$results = @()
$check = { param($name, $pass, $detail)
    [PSCustomObject]@{ Check = $name; Status = if ($pass) { 'PASS' } else { 'FAIL' }; Detail = $detail }
}

# ── Resource group ────────────────────────────────────────────────────────────
$rg = az group show --name $ResourceGroupName --query 'properties.provisioningState' -o tsv 2>$null
$results += & $check "Resource group '$ResourceGroupName' exists" ($rg -eq 'Succeeded') ($rg ?? 'NOT FOUND')

# ── Dev Center ────────────────────────────────────────────────────────────────
$dc = az devcenter admin devcenter show --name $DevCenterName --resource-group $ResourceGroupName -o json 2>$null | ConvertFrom-Json
$dcState = $dc.provisioningState
$results += & $check "Dev Center '$DevCenterName' exists" ($dcState -eq 'Succeeded') ($dcState ?? 'NOT FOUND')

# ── Dev Center Project ────────────────────────────────────────────────────────
$dcProj = az devcenter admin project show --name $DevCenterProjectName --resource-group $ResourceGroupName -o json 2>$null | ConvertFrom-Json
$dcProjState = $dcProj.provisioningState
$results += & $check "Dev Center Project '$DevCenterProjectName' exists" ($dcProjState -eq 'Succeeded') ($dcProjState ?? 'NOT FOUND')

# ── Pool ──────────────────────────────────────────────────────────────────────
$pool = az resource show `
    --resource-group $ResourceGroupName `
    --name $PoolName `
    --resource-type 'Microsoft.DevOpsInfrastructure/pools' `
    --query 'properties' -o json 2>$null | ConvertFrom-Json

$poolExists = $null -ne $pool
$results += & $check "Managed DevOps Pool '$PoolName' exists" $poolExists ($poolExists ? $pool.provisioningState : 'NOT FOUND')

if ($pool) {
    $results += & $check "Pool provisioning state" ($pool.provisioningState -eq 'Succeeded') $pool.provisioningState

    $poolOrg = $pool.organizationProfile.organizations[0].url
    if ($OrganizationUrl) {
        $results += & $check "Pool organisation URL matches" ($poolOrg -eq $OrganizationUrl) "Expected: $OrganizationUrl  Actual: $poolOrg"
    } else {
        $results += & $check "Pool organisation URL set" (-not [string]::IsNullOrEmpty($poolOrg)) ($poolOrg ?? 'NOT SET')
    }

    $results += & $check "Pool max concurrency > 0" ($pool.maximumConcurrency -gt 0) "Max: $($pool.maximumConcurrency)"
    $results += & $check "Pool agent lifecycle is Stateless" ($pool.agentProfile.kind -eq 'Stateless') $pool.agentProfile.kind
}

# ── Output ────────────────────────────────────────────────────────────────────
Write-Host "`n=== Managed DevOps Pool Validation ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$pass = ($results | Where-Object Status -eq 'PASS').Count
$fail = ($results | Where-Object Status -eq 'FAIL').Count
Write-Host "Results — Pass: $pass  Fail: $fail  Total: $($results.Count)" -ForegroundColor ($fail -gt 0 ? 'Red' : 'Green')

if ($fail -gt 0) { exit 1 }
