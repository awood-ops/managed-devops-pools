<#
.SYNOPSIS
    Reports the current agent status for a Managed DevOps Pool.

.PARAMETER ResourceGroupName
    Resource group containing the pool.

.PARAMETER PoolName
    Name of the Managed DevOps Pool.

.EXAMPLE
    .\Get-PoolAgentStatus.ps1 -ResourceGroupName rg-devops-agents-prd -PoolName mdp-windows-prd
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$PoolName
)

$pool = az resource show `
    --resource-group $ResourceGroupName `
    --name $PoolName `
    --resource-type 'Microsoft.DevOpsInfrastructure/pools' `
    --query 'properties' `
    -o json 2>&1 | ConvertFrom-Json

if (-not $pool) {
    Write-Error "Pool '$PoolName' not found in resource group '$ResourceGroupName'"
    exit 1
}

Write-Output ""
Write-Output "=== Managed DevOps Pool: $PoolName ==="
Write-Output "  Max concurrency : $($pool.maximumConcurrency)"
Write-Output "  Agent lifecycle : $($pool.agentProfile.kind)"
Write-Output "  Organisation    : $($pool.organizationProfile.organizations[0].url)"
Write-Output ""

# Agent instances (preview API)
$agents = az rest `
    --method GET `
    --uri "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/$ResourceGroupName/providers/Microsoft.DevOpsInfrastructure/pools/$PoolName/agents?api-version=2024-04-04-preview" `
    -o json 2>&1 | ConvertFrom-Json

if ($agents.value) {
    Write-Output "Active agents:"
    $agents.value | ForEach-Object {
        Write-Output "  [$($_.properties.status)] $($_.name) — $($_.properties.requestedAt)"
    }
} else {
    Write-Output "No active agents (pool is idle)."
}
