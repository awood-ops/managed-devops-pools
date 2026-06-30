#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Estimates monthly cost for a Managed DevOps Pool resource group using
    the Azure Retail Prices API. Outputs a table to the console and saves
    CSV, JSON, and Markdown artifacts.

.PARAMETER ResourceGroupName
    Resource group to analyse.

.PARAMETER Location
    Azure region (ARM name, e.g. 'uksouth').

.PARAMETER Currency
    ISO currency code (default GBP).

.PARAMETER OutputPath
    Directory to write cost-estimate.csv / .json / .md into.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [string] $Location   = 'uksouth',
    [string] $Currency   = 'GBP',
    [string] $OutputPath = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RetailPrices {
    param([string] $Filter)
    $uri = 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview' +
           "&`$filter=$([Uri]::EscapeDataString($Filter))"
    try {
        $r = Invoke-RestMethod -Uri $uri -TimeoutSec 20
        return $r.Items | Where-Object priceType -eq 'Consumption'
    }
    catch {
        Write-Warning "Retail Prices API lookup failed: $_"
        return @()
    }
}

$estimates = [System.Collections.Generic.List[PSCustomObject]]::new()
$resources = Get-AzResource -ResourceGroupName $ResourceGroupName

foreach ($r in $resources) {
    switch -Wildcard ($r.ResourceType.ToLower()) {

        'microsoft.devcenter/devcenters' {
            $prices = Get-RetailPrices -Filter (
                "armRegionName eq '$Location' and currencyCode eq '$Currency' " +
                "and serviceName eq 'Dev Center' and meterName eq 'Dev Center'"
            )
            $price = $prices | Select-Object -First 1
            $estimates.Add([PSCustomObject]@{
                Resource   = $r.Name
                Type       = 'Dev Center'
                SKU        = 'Standard'
                UnitPrice  = if ($price) { "$Currency $($price.retailPrice)/hr" } else { 'lookup failed' }
                EstMonthly = if ($price) { [math]::Round($price.retailPrice * 730, 2) } else { 'N/A' }
                Notes      = 'Billed per hour while active'
            })
        }

        'microsoft.devcenter/projects' {
            $estimates.Add([PSCustomObject]@{
                Resource   = $r.Name
                Type       = 'Dev Center Project'
                SKU        = 'N/A'
                UnitPrice  = 'Free'
                EstMonthly = 0
                Notes      = 'No charge for DC projects'
            })
        }

        'microsoft.devopsinfrastructure/pools' {
            $poolJson = az resource show `
                --resource-group $ResourceGroupName `
                --name $r.Name `
                --resource-type 'Microsoft.DevOpsInfrastructure/pools' `
                --query 'properties' -o json 2>$null | ConvertFrom-Json

            $vmSize  = $poolJson.fabricProfile.sku.name
            $maxConc = $poolJson.maximumConcurrency

            if ($vmSize) {
                $sku = $vmSize -replace '^(Standard|Basic)_', '' -replace '_', ' '
                $prices = Get-RetailPrices -Filter (
                    "armRegionName eq '$Location' and currencyCode eq '$Currency' " +
                    "and serviceName eq 'Virtual Machines' and skuName eq '$sku'"
                )
                $price = $prices |
                    Where-Object { $_.meterName -notmatch 'Spot|Low Priority|Windows' } |
                    Select-Object -First 1
                $perVm = if ($price) { $price.retailPrice } else { $null }
                $monthly = if ($perVm) { [math]::Round($perVm * 730 * $maxConc, 2) } else { 'N/A' }
                $estimates.Add([PSCustomObject]@{
                    Resource   = $r.Name
                    Type       = 'Managed DevOps Pool'
                    SKU        = $vmSize
                    UnitPrice  = if ($price) { "$Currency $perVm/hr per agent" } else { 'lookup failed' }
                    EstMonthly = $monthly
                    Notes      = "Max concurrency $maxConc agents × 730 hrs (all agents running 24/7)"
                })
            }
        }
    }
}

Write-Host "`n=== Cost Estimate: $ResourceGroupName ===" -ForegroundColor Cyan
Write-Host "Region: $Location  |  Currency: $Currency`n" -ForegroundColor Gray

if ($estimates.Count -eq 0) {
    Write-Warning 'No priceable resources found.'
}
else {
    $estimates | Format-Table Resource, Type, SKU, UnitPrice, EstMonthly, Notes -AutoSize
}

$numericTotal = ($estimates |
    Where-Object { $_.EstMonthly -is [double] -or $_.EstMonthly -is [int] } |
    Measure-Object -Property EstMonthly -Sum).Sum

Write-Host "Subtotal (all agents 24/7): $Currency $([math]::Round($numericTotal, 2))/month" -ForegroundColor Green
Write-Host "MDP agents are stateless — actual cost = (jobs run × avg duration × hourly rate)`n"

$null = New-Item -ItemType Directory -Force -Path $OutputPath
$estimates | Export-Csv  -Path "$OutputPath/cost-estimate.csv" -NoTypeInformation -Force
$estimates | ConvertTo-Json -Depth 3 | Out-File -FilePath "$OutputPath/cost-estimate.json" -Force

$rows = $estimates | ForEach-Object {
    "| $($_.Resource) | $($_.Type) | $($_.SKU) | $($_.UnitPrice) | $($_.EstMonthly) | $($_.Notes) |"
}
$md = @"
## Cost Estimate — $ResourceGroupName

> **Region:** `$Location` | **Currency:** `$Currency` | Max agents 24/7 assumption

| Resource | Type | SKU | Unit Price | Est. Monthly | Notes |
|---|---|---|---|---|---|
$($rows -join "`n")

**Subtotal (all agents 24/7):** $Currency $([math]::Round($numericTotal, 2))/month
> MDP pools are on-demand — actual cost scales with job frequency and duration, not max concurrency.
"@

$md | Out-File -FilePath "$OutputPath/cost-estimate.md" -Force
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $md
}
Write-Host "Artifacts saved to: $OutputPath (csv / json / md)"
