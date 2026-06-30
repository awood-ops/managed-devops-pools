#Requires -Version 7.0
<#
.SYNOPSIS
    Pester v5 assertions for the managed-devops-pools defaults e2e scenario.
    Uses az CLI for all assertions — no Az PowerShell modules required.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()

BeforeAll {
    $script:rg   = $env:TEST_RG
    $p           = $env:TEST_NAME_PREFIX

    # Derive names from namePrefix (must match main.test.bicep)
    $script:dc   = "$p-dc"
    $script:proj = "$p-proj"
    $script:pool = "$p-pool"
}

Describe 'Resource Group' {
    It 'should exist and be provisioned' {
        $state = az group show --name $script:rg `
            --query 'properties.provisioningState' -o tsv 2>$null
        $state | Should -Be 'Succeeded'
    }
}

Describe 'Dev Center' {
    It 'should exist' {
        $state = az resource show `
            --resource-group $script:rg `
            --name $script:dc `
            --resource-type 'Microsoft.DevCenter/devcenters' `
            --query 'properties.provisioningState' -o tsv 2>$null
        $state | Should -Be 'Succeeded'
    }
}

Describe 'Dev Center Project' {
    It 'should exist' {
        $state = az resource show `
            --resource-group $script:rg `
            --name $script:proj `
            --resource-type 'Microsoft.DevCenter/projects' `
            --query 'properties.provisioningState' -o tsv 2>$null
        $state | Should -Be 'Succeeded'
    }
}

Describe 'Managed DevOps Pool' {
    BeforeAll {
        $script:poolProps = az resource show `
            --resource-group $script:rg `
            --name $script:pool `
            --resource-type 'Microsoft.DevOpsInfrastructure/pools' `
            --query 'properties' -o json 2>$null | ConvertFrom-Json
    }

    It 'should exist and be provisioned' {
        $script:poolProps            | Should -Not -BeNullOrEmpty
        $script:poolProps.provisioningState | Should -Be 'Succeeded'
    }

    It 'organisation URL should be set' {
        $url = $script:poolProps.organizationProfile.organizations[0].url
        $url | Should -Not -BeNullOrEmpty
    }

    It 'maximum concurrency should be at least 1' {
        $script:poolProps.maximumConcurrency | Should -BeGreaterOrEqual 1
    }

    It 'agent lifecycle should be Stateless' {
        $script:poolProps.agentProfile.kind | Should -Be 'Stateless'
    }

    It 'fabric profile should be Managed' {
        $script:poolProps.fabricProfile.kind | Should -Be 'Managed'
    }
}
