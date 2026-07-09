<#
.SYNOPSIS
    Grants a workload identity (federated service principal) the permissions it needs to deploy
    this repo's Managed DevOps Pool resources.

.DESCRIPTION
    Two independent permission systems are involved, and both are required:

      1. Azure RBAC — Contributor on the target resource group, so the identity can create/update
         Microsoft.DevCenter/devcenters, Microsoft.DevCenter/projects and
         Microsoft.DevOpsInfrastructure/pools (bicep/main.bicep). Resource provider registration
         for Microsoft.DevCenter and Microsoft.DevOpsInfrastructure is a subscription-level
         operation and is handled here too (skip with -SkipResourceProviderRegistration if
         providers are already registered and the caller only has RG-scoped rights).

      2. Azure DevOps organisation permission — membership of the built-in
         "DevOps Infrastructure Pool Administrators" group, so the deployed pool can be linked to
         and manage agents within the ADO organisation (see docs/Getting-Started.md). This is
         separate from Azure RBAC and is granted through the Azure DevOps CLI extension.

    The e2e test identity (GitHub Actions, awood-ops/platform-workflows e2e.reusable.yml) deploys
    at subscription scope and creates/deletes its own resource groups per run — pass
    -IncludeSubscriptionScope for that identity. The production/dev deploy identity behind the
    ADO service connection only needs -IncludeSubscriptionScope on first-ever run if resource
    providers aren't registered yet; ongoing deploys only need RG scope.

    Run this once per identity (production service connection SP, and separately for the e2e
    GitHub OIDC app) with an account that itself has Owner (or User Access Administrator +
    Contributor) on the subscription and organisation-level permissions in Azure DevOps.

.PARAMETER SubscriptionId
    Target Azure subscription ID.

.PARAMETER ServicePrincipalObjectId
    Object (principal) ID of the workload identity's enterprise application — NOT the
    application (client) ID. Find it with:
    az ad sp show --id <app-id-or-client-id> --query id -o tsv

.PARAMETER ResourceGroupName
    Resource group to grant Contributor on. Default: rg-devops-agents-prd

.PARAMETER Location
    Location used only if the resource group needs to be created. Default: uksouth

.PARAMETER IncludeSubscriptionScope
    Also grant Contributor at subscription scope. Required for the e2e test identity (deploys via
    `az deployment sub create` and creates its own resource groups). Not required for the
    production/dev deploy identity, which deploys at fixed RG scope.

.PARAMETER OrganizationUrl
    Azure DevOps organisation URL, e.g. https://dev.azure.com/my-org. Required unless
    -SkipAdoGroupMembership is set.

.PARAMETER ServicePrincipalAppId
    Application (client) ID of the workload identity — required for the Azure DevOps group
    membership step, since ADO identifies service principals by application ID, not object ID.
    Required unless -SkipAdoGroupMembership is set.

.PARAMETER SkipResourceProviderRegistration
    Skip checking/registering Microsoft.DevCenter and Microsoft.DevOpsInfrastructure. Use this if
    the caller only has resource-group-scoped rights (registration is a subscription operation).

.PARAMETER SkipAdoGroupMembership
    Skip the Azure DevOps "DevOps Infrastructure Pool Administrators" group membership step.

.EXAMPLE
    # Production deploy identity — RG scope only
    .\Grant-WorkloadIdentityAccess.ps1 `
        -SubscriptionId        11111111-1111-1111-1111-111111111111 `
        -ServicePrincipalObjectId 22222222-2222-2222-2222-222222222222 `
        -ServicePrincipalAppId    33333333-3333-3333-3333-333333333333 `
        -OrganizationUrl       https://dev.azure.com/my-org

.EXAMPLE
    # e2e test identity — subscription scope, no ADO group (uses a separate GitHub OIDC app)
    .\Grant-WorkloadIdentityAccess.ps1 `
        -SubscriptionId        11111111-1111-1111-1111-111111111111 `
        -ServicePrincipalObjectId 44444444-4444-4444-4444-444444444444 `
        -IncludeSubscriptionScope `
        -SkipAdoGroupMembership

.EXAMPLE
    # Preview only, no changes made
    .\Grant-WorkloadIdentityAccess.ps1 -SubscriptionId ... -ServicePrincipalObjectId ... -OrganizationUrl ... -ServicePrincipalAppId ... -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $SubscriptionId,

    [Parameter(Mandatory)]
    [string] $ServicePrincipalObjectId,

    [string] $ResourceGroupName = 'rg-devops-agents-prd',
    [string] $Location          = 'uksouth',

    [switch] $IncludeSubscriptionScope,

    [string] $OrganizationUrl,
    [string] $ServicePrincipalAppId,

    [switch] $SkipResourceProviderRegistration,
    [switch] $SkipAdoGroupMembership
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $SkipAdoGroupMembership -and (-not $OrganizationUrl -or -not $ServicePrincipalAppId)) {
    throw "OrganizationUrl and ServicePrincipalAppId are required unless -SkipAdoGroupMembership is set."
}

$results = @()
$check = { param($name, $pass, $detail)
    [PSCustomObject]@{ Step = $name; Status = if ($pass) { 'OK' } else { 'FAILED' }; Detail = $detail }
}

Write-Host "`n=== Granting workload identity access ===" -ForegroundColor Cyan
Write-Host "Service principal (object id): $ServicePrincipalObjectId"
Write-Host "Subscription:                  $SubscriptionId"
Write-Host "Resource group:                $ResourceGroupName`n"

az account set --subscription $SubscriptionId

# ── Resource provider registration ─────────────────────────────────────────────
if (-not $SkipResourceProviderRegistration) {
    foreach ($rp in 'Microsoft.DevCenter', 'Microsoft.DevOpsInfrastructure') {
        try {
            $state = az provider show -n $rp --query registrationState -o tsv 2>$null
            if ($state -ne 'Registered') {
                if ($PSCmdlet.ShouldProcess($rp, 'Register resource provider')) {
                    az provider register --namespace $rp --wait
                    $state = az provider show -n $rp --query registrationState -o tsv
                }
            }
            $results += & $check "Resource provider $rp registered" ($state -eq 'Registered') $state
        } catch {
            $results += & $check "Resource provider $rp registered" $false $_.Exception.Message
        }
    }
} else {
    Write-Host "Skipping resource provider registration (-SkipResourceProviderRegistration)" -ForegroundColor Yellow
}

# ── Resource group ──────────────────────────────────────────────────────────────
try {
    $rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
    if (-not $rgExists) {
        if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create resource group in $Location")) {
            az group create --name $ResourceGroupName --location $Location --output none
        }
        $rgExists = $true
    }
    $results += & $check "Resource group '$ResourceGroupName' exists" $rgExists ($rgExists ? 'present' : 'missing')
} catch {
    $results += & $check "Resource group '$ResourceGroupName' exists" $false $_.Exception.Message
}

# ── Azure RBAC: Contributor at resource group scope ────────────────────────────
$rgScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
try {
    $existing = az role assignment list `
        --assignee-object-id $ServicePrincipalObjectId `
        --scope $rgScope `
        --query "[?roleDefinitionName=='Contributor']" -o json | ConvertFrom-Json

    if (-not $existing) {
        if ($PSCmdlet.ShouldProcess($rgScope, 'Grant Contributor')) {
            az role assignment create `
                --assignee-object-id $ServicePrincipalObjectId `
                --assignee-principal-type ServicePrincipal `
                --role Contributor `
                --scope $rgScope | Out-Null
        }
    }
    $results += & $check "Contributor on $rgScope" $true (if ($existing) { 'already assigned' } else { 'assigned' })
} catch {
    $results += & $check "Contributor on $rgScope" $false $_.Exception.Message
}

# ── Azure RBAC: Contributor at subscription scope (e2e identity only) ──────────
if ($IncludeSubscriptionScope) {
    $subScope = "/subscriptions/$SubscriptionId"
    try {
        $existing = az role assignment list `
            --assignee-object-id $ServicePrincipalObjectId `
            --scope $subScope `
            --query "[?roleDefinitionName=='Contributor' && scope=='$subScope']" -o json | ConvertFrom-Json

        if (-not $existing) {
            if ($PSCmdlet.ShouldProcess($subScope, 'Grant Contributor')) {
                az role assignment create `
                    --assignee-object-id $ServicePrincipalObjectId `
                    --assignee-principal-type ServicePrincipal `
                    --role Contributor `
                    --scope $subScope | Out-Null
            }
        }
        $results += & $check "Contributor on $subScope" $true (if ($existing) { 'already assigned' } else { 'assigned' })
    } catch {
        $results += & $check "Contributor on $subScope" $false $_.Exception.Message
    }
}

# ── Azure DevOps: DevOps Infrastructure Pool Administrators ────────────────────
if (-not $SkipAdoGroupMembership) {
    try {
        az extension add --name azure-devops --only-show-errors 2>$null
        az devops configure --defaults organization=$OrganizationUrl | Out-Null

        # Service principals must exist as an ADO identity before they can be added to a group.
        # This no-ops if the SP is already known to the organisation.
        az devops user add --email-id $ServicePrincipalAppId --license-type express 2>$null | Out-Null

        $group = az devops security group list `
            --query "graphGroups[?displayName=='DevOps Infrastructure Pool Administrators']" `
            -o json | ConvertFrom-Json

        if (-not $group) {
            $results += & $check "ADO group 'DevOps Infrastructure Pool Administrators'" $false `
                "Group not found in $OrganizationUrl — it's created automatically the first time a Managed DevOps Pool is deployed in this org. Deploy once via the portal, or add the SP manually afterwards: Organization Settings -> Permissions -> DevOps Infrastructure Pool Administrators."
        } else {
            if ($PSCmdlet.ShouldProcess($ServicePrincipalAppId, "Add to 'DevOps Infrastructure Pool Administrators'")) {
                az devops security group membership add `
                    --group-id $group[0].descriptor `
                    --member-id $ServicePrincipalAppId | Out-Null
            }
            $results += & $check "Member of 'DevOps Infrastructure Pool Administrators'" $true $OrganizationUrl
        }
    } catch {
        $results += & $check "ADO group membership" $false `
            "$($_.Exception.Message) — verify manually via Organization Settings -> Permissions in $OrganizationUrl"
    }
} else {
    Write-Host "Skipping Azure DevOps group membership (-SkipAdoGroupMembership)" -ForegroundColor Yellow
}

# ── Summary ──────────────────────────────────────────────────────────────────────
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$fail = ($results | Where-Object Status -eq 'FAILED').Count
if ($fail -gt 0) {
    Write-Host "$fail step(s) need attention — see Detail column above." -ForegroundColor Red
    exit 1
}
Write-Host "All steps completed." -ForegroundColor Green
