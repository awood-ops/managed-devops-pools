param (
    [string]$resourceGroupName
)

# Create an empty array to store the resource information
$resourceInfo = @()

# Get the resources in the resource group
$resources = Get-AzResource -ResourceGroupName $resourceGroupName

# Retrieve all virtual networks in the resource group
$virtualNetworks = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName

# Iterate over each virtual network to extract subnets
foreach ($vnet in $virtualNetworks) {
    foreach ($subnet in $vnet.Subnets) {
        # Initialize variables for NSG and Route Table names
        $nsgName = $null
        $routeTableName = $null

        # Check if the subnet has an NSG associated and extract the name
        if ($subnet.NetworkSecurityGroup -ne $null) {
            $nsgName = $subnet.NetworkSecurityGroup.Id.Split('/')[-1]
        }

        # Check if the subnet has a Route Table associated and extract the name
        if ($subnet.RouteTable -ne $null) {
            $routeTableName = $subnet.RouteTable.Id.Split('/')[-1]
        }

        # Create a custom object for the subnet with NSG and Route Table names
        $subnetResource = [PSCustomObject]@{
            ResourceId = $subnet.Id
            ResourceName = $subnet.Name
            ResourceType = "Microsoft.Network/virtualNetworks/subnets"
            ResourceGroupName = $resourceGroupName
            Location = $vnet.Location
            NSGName = $nsgName  # Add NSG name to the custom object
            RouteTableName = $routeTableName  # Add Route Table name to the custom object
            # Add other properties as needed
        }
        
        # Add the subnet object to the resources array
        $resources += $subnetResource
    }
}

# Loop through each resource and extract the required information
foreach ($resource in $resources) {
    $name = $resource.Name
    $resourceType = $resource.ResourceType
    $tags = $resource.Tags
    $location = $resource.Location
    $sku = $null # Initialize SKU as null
    $firewallStatus = 'N/A'
    $IPAddress = 'N/A'

    # If Event Grid System Topic, take them off the report
    if ($resourceType -eq "Microsoft.EventGrid/systemTopics") {
        continue
    }

    ## SKU and Image Reference Check
    if ($resourceType -eq "Microsoft.Storage/storageAccounts") {
        # Use Get-AzStorageAccount to get detailed information including SKU
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $name
        $sku = $storageAccount.Sku.Name
        # Extract the firewall status
        $firewallEnabled = $storageAccount.NetworkRuleSet.DefaultAction -eq 'Deny'
        $firewallStatus = $firewallEnabled ? 'Enabled' : 'Disabled'
        # Check the Infrastructure Encryption status or individual services have encryption enabled
        if ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Blob, File, Table, and Queue Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled) {
            $encryptionStatus = 'Blob, File, Table, and Queue Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Blob, File, Table Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Blob, File, Queue Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Blob, Table, Queue Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'File, Table, Queue Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Blob, File Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Blob, Table Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Blob, Queue Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'File, Table Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'File, Queue Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled -and $storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Table, Queue Encryption Enabled with Infrastructure Encryption'
        } elseif ($storageAccount.Encryption.RequireInfrastructureEncryption) {
            $encryptionStatus = 'Infrastructure Encryption Enabled (All Services)'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled) {
            $encryptionStatus = 'Blob Encryption only Enabled'
        } elseif ($storageAccount.Encryption.Services.File.Enabled) {
            $encryptionStatus = 'File Encryption only Enabled'
        } elseif ($storageAccount.Encryption.Services.Table.Enabled) {
            $encryptionStatus = 'Table Encryption only Enabled'
        } elseif ($storageAccount.Encryption.Services.Queue.Enabled) {
            $encryptionStatus = 'Queue Encryption only Enabled'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled) {
            $encryptionStatus = 'Blob and File Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.Table.Enabled) {
            $encryptionStatus = 'Blob and Table Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled) {
            $encryptionStatus = 'Blob and Queue Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Table.Enabled) {
            $encryptionStatus = 'File and Table Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled) {
            $encryptionStatus = 'File and Queue Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled) {
            $encryptionStatus = 'Table and Queue Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Table.Enabled) {
            $encryptionStatus = 'Blob, File, and Table Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.File.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled) {
            $encryptionStatus = 'Blob, File, and Queue Encryption Enabled'
        } elseif ($storageAccount.Encryption.Services.Blob.Enabled -and $storageAccount.Encryption.Services.Table.Enabled -and $storageAccount.Encryption.Services.Queue.Enabled) {
            $encryptionStatus = 'Blob, Table, and Queue Encryption Enabled'
        }

        # Since the Storage Account doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Since the Storage Account can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since the Storage Account can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # Storage Account doesn't have an image reference
        $image = 'N/A'
        # DNS Settings are not applicable for Storage Accounts
        $DNSSettings = 'N/A'
        # Check if Diagnostic Settings are enabled
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $storageAccount.Id -ErrorAction SilentlyContinue
        $diagnosticStatus = if ($diagnosticSettings -ne $null) { 'Enabled' } else { 'Disabled' }
    }

    # Check if the resource is a Virtual Machine Scale Set (VMSS)
    elseif ($resourceType -eq "Microsoft.Compute/virtualMachineScaleSets") {
        # Retrieve VMSS details
        $vmss = Get-AzVmss -ResourceGroupName $resourceGroupName -VMScaleSetName $name
        # Extract the Image Reference Publisher, Offer, SKU, and Version
        $imageReference = $vmss.VirtualMachineProfile.StorageProfile.ImageReference
        $image = $imageReference.Publisher + ':' + $imageReference.Offer + ':' + $imageReference.Sku + ':' + $imageReference.Version
        # Extract the SKU name
        $sku = $vmss.Sku.Name
        # EXtract the Encrytion at Host status
        $encryptionAtHost = $vmss.VirtualMachineProfile.SecurityProfile.EncryptionAtHost
        $encryptionStatus = $encryptionAtHost ? 'Enabled' : 'Disabled'
        # Since VMSS doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Since the VMSS doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Since the VMSS can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since the VMSS can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # Check if Diagnostic Settings are enabled
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $vmss.Id -ErrorAction SilentlyContinue
        $diagnosticStatus = if ($diagnosticSettings -ne $null) { 'Enabled' } else { 'Disabled' }
    }

    # Check if the resource is a Virtual Machine (VM)
    elseif ($resourceType -eq "Microsoft.Compute/virtualMachines") {
        # Retrieve VM details
        $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $name
        # Extract the Source Image Details
        $imageReference = $vm.StorageProfile.ImageReference
        $image = $imageReference.Publisher + ':' + $imageReference.Offer + ':' + $imageReference.Sku + ':' + $imageReference.Version
        # Extract the Encryption at Host status
        $encryptionAtHost = $vm.SecurityProfile.EncryptionAtHost
        $encryptionStatus = $encryptionAtHost ? 'Enabled' : 'Disabled'
        # Extract the SKU name
        $sku = $vm.StorageProfile.ImageReference.Sku
        # Since VM doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Since the VM doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Since the VM can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since the VM can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # Check if Diagnostic Settings are enabled
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $vm.Id -ErrorAction SilentlyContinue
        $diagnosticStatus = if ($diagnosticSettings -ne $null) { 'Enabled' } else { 'Disabled' }
    }

    # Check if the resource is a KeyVault
    elseif ($resourceType -eq "Microsoft.KeyVault/vaults") {
        # Retrieve KeyVault details
        $keyVault = Get-AzKeyVault -ResourceGroupName $resourceGroupName -VaultName $name
        # Since KeyVault doesn't have a direct SKU, set to N/A or implement logic if needed
        $sku = 'N/A'
        # Extract the firewall status
        $firewallEnabled = $keyVault.NetworkAcls.DefaultAction -eq 'Deny'
        $firewallStatus = $firewallEnabled ? 'Enabled' : 'Disabled'
        # Since KeyVault doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Since KeyVault can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since KeyVault can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # KeyVault doesn't have an image reference
        $image = 'N/A'
        # DNS Settings are not applicable for KeyVault
        $DNSSettings = 'N/A'
        # KeyVault doesn't have an encryption status
        $encryptionStatus = 'N/A'
        # Check if Diagnostic Settings are enabled
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $keyVault.ResourceId -ErrorAction SilentlyContinue
        $diagnosticStatus = if ($diagnosticSettings -ne $null) { 'Enabled' } else { 'Disabled' }
    }

    # Check if the resource is a NIC
    elseif ($resourceType -eq "Microsoft.Network/networkInterfaces") {
        # Retrieve NIC details
        $nic = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $name
        # Since NIC doesn't have a direct SKU, set to N/A or implement logic if needed
        $sku = 'N/A'
        # Since NIC doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Get the IP Address
        $IPAddress = $nic.IpConfigurations.PrivateIpAddress
        # Since NIC doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Extract the NSG name if it exists
        $nsgName = if ($nic.NetworkSecurityGroup -ne $null) { $nic.NetworkSecurityGroup.Id.Split('/')[-1] } else { 'None' }
        # Since NIC can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # NIC doesn't have an image reference
        $image = 'N/A'
        # NICs don't have an encryption status
        $encryptionStatus = 'N/A'
        # Check if Diagnostic Settings are enabled
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $nic.Id -ErrorAction SilentlyContinue
        $diagnosticStatus = if ($diagnosticSettings -ne $null) { 'Enabled' } else { 'Disabled' }
    }

    # Check if the resource is a Virtual Network
    elseif ($resourceType -eq "Microsoft.Network/virtualNetworks") {
        # Retrieve Virtual Network details
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $name
        # Since Virtual Network doesn't have a direct SKU, set to N/A or implement logic if needed
        $sku = 'N/A'
        # Since Virtual Network doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Get the Address Space
        $AddressSpace = $vnet.AddressSpace.AddressPrefixes
        # Get the DNS Settings, if no specified DNS Servers state Azure DNS
        $DNSSettings = if ($vnet.DhcpOptions.DnsServers -ne $null) { $vnet.DhcpOptions.DnsServers } else { 'Azure DNS' }
        # Since the Virtual Network can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since the Virtual Network can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # Virtual Network doesn't have an image reference
        $image = 'N/A'
        # Virtual Network doesn't have an encryption status
        $encryptionStatus = 'N/A'
        # Check if Diagnostic Settings are enabled
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $vnet.Id -ErrorAction SilentlyContinue
        $diagnosticStatus = if ($diagnosticSettings -ne $null) { 'Enabled' } else { 'Disabled' }
    }

    # Check if the resource is an Application Security Group
    elseif ($resourceType -eq "Microsoft.Network/applicationSecurityGroups") {
        # Retrieve Application Security Group details
        $asg = Get-AzApplicationSecurityGroup -ResourceGroupName $resourceGroupName -Name $name
        # Since ASG doesn't have a direct SKU, set to N/A or implement logic if needed
        $sku = 'N/A'
        # Since ASG doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Since ASG doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Since ASG can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since ASG can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # ASG doesn't have an image reference
        $image = 'N/A'
        # DNS Settings are not applicable for ASG
        $DNSSettings = 'N/A'
        # ASG doesn't have an encryption status
        $encryptionStatus = 'N/A'
        # Diagnostic Settings are not applicable for ASG
        $diagnosticStatus = 'N/A'
    }

    # Check if the resource is a NSG
    elseif ($resourceType -eq "Microsoft.Network/networkSecurityGroups") {
        # Retrieve NSG details
        $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $name
        # Since NSG doesn't have a direct SKU, set to N/A or implement logic if needed
        $sku = 'N/A'
        # Since NSG doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Since NSG doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Since NSG can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since NSG can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # NSG doesn't have an image reference
        $image = 'N/A'
        # DNS Settings are not applicable for NSG
        $DNSSettings = 'N/A'
        # NSG doesn't have an encryption status
        $encryptionStatus = 'N/A'
        # Check if Diagnostic Settings are enabled
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $nsg.Id -ErrorAction SilentlyContinue
        $diagnosticStatus = if ($diagnosticSettings -ne $null) { 'Enabled' } else { 'Disabled' }
    }

    # Check if the resource is a Private Endpoint
    elseif ($resourceType -eq "Microsoft.Network/privateEndpoints") {
        # Retrieve Private Endpoint details
        $privateEndpoint = Get-AzPrivateEndpoint -ResourceGroupName $resourceGroupName -Name $name
        # Since Private Endpoint doesn't have a direct SKU, set to N/A or implement logic if needed
        $sku = 'N/A'
        # Since Private Endpoint doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Since Private Endpoint doesn't have an address space, set to N/A or implement logic if needed
        $AddressSpace = 'N/A'
        # Since Private Endpoint can't directly have an NSG associated with it, set to N/A or implement logic if needed
        $nsgName = 'N/A'
        # Since Private Endpoint can't directly have a Route Table associated with it, set to N/A or implement logic if needed
        $routeTableName = 'N/A'
        # Private Endpoint doesn't have an image reference
        $image = 'N/A'
        # DNS Settings are not applicable for Private Endpoint
        $DNSSettings = 'N/A'
        # Private Endpoint doesn't have an encryption status
        $encryptionStatus = 'N/A'
        # Diagnostic Settings are not applicable for Private Endpoint
        $diagnosticStatus = 'N/A'
    }

    # Check if the resource is a subnet
    elseif ($resourceType -eq "Microsoft.Network/virtualNetworks/subnets") {
        # Retrieve Subnet details
        $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $name
        # Since Subnet doesn't have a direct SKU, set to N/A or implement logic if needed
        $sku = 'N/A'
        # Since Subnet doesn't have a direct firewall setting, set to N/A or implement logic if needed
        $firewallStatus = 'N/A'
        # Extract the subnet address space
        $AddressSpace = $subnet.AddressPrefix
        # Use ResourceName as Name
        $name = $resource.ResourceName
        # Extract NSG and Route Table names if they exist
        $nsgName = if ($subnet.NetworkSecurityGroup -ne $null) { $subnet.NetworkSecurityGroup.Id.Split('/')[-1] } else { 'None' }
        $routeTableName = if ($subnet.RouteTable -ne $null) { $subnet.RouteTable.Id.Split('/')[-1] } else { 'None' }
        # Subnet doesn't have an image reference
        $image = 'N/A'
        # Diagnostic Settings are not applicable for Subnets
        $diagnosticStatus = 'N/A'
    }




# Create a custom object with the extracted information
$resourceObject = [PSCustomObject]@{
    Name = $name
    ResourceType = $resourceType
    Tags = if ($tags -ne $null) { ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ' } else { 'No Tags' }
    SKU = $sku
    Image = $image
    EncryptionStatus = $encryptionStatus
    Location = $location
    FirewallStatus = $firewallStatus
    IPAddress = $IPAddress
    DNSSettings = $DNSSettings -join ', ' # Ensure DNSSettings is also a string
    AddressSpace = $AddressSpace -join ', ' # Ensure AddressSpace is also a string
    NSGName = $nsgName # Add NSG name
    RouteTableName = $routeTableName # Add Route Table name
    DiagnosticStatus = $diagnosticStatus
}

    # Add the custom object to the array
    $resourceInfo += $resourceObject
}

# Output the resource information
#$resourceInfo | Format-Table -Property Name, ResourceType, Tags, SKU, Location, FirewallStatus, IPAddress, DNSSettings, AddressSpace

$resourceInfo