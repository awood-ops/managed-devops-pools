#Get All the Azure Subscriptions
$subscriptions = Get-AzSubscription

#Loop through each subscription
foreach ($subscription in $subscriptions) {
    #Set the current subscription context
    Set-AzContext -SubscriptionName $subscription.Name

    #Register the Resource Providers
    $rps = @(
    "Microsoft.Insights",
    "Microsoft.App",
    "Microsoft.Compute",
    "Microsoft.DesktopVirtualization")

    #Register feature
    $features = @(
        "EncryptionAtHost"
    )

    # Get the Resource Provider and if already registered, ignore, otherwise register, output to screen
    foreach ($rp in $rps) {
        $rpstatus = Get-AzResourceProvider -ProviderNamespace $rp
        if ($rpstatus.RegistrationState -eq "Registered") {
            Write-Host "$rp is already registered"
        } else {
            Register-AzResourceProvider -ProviderNamespace $rp
            Write-Host "$rp is now registered"
        }
    }

    # If Microsoft.Compute is not registered, wait 40 seconds and check again, if not move on
    $rpstatus = Get-AzResourceProvider -ProviderNamespace "Microsoft.Compute"
    if ($rpstatus.RegistrationState -ne "Registered") {
        Write-Host "Microsoft.Compute is not registered, waiting 40 seconds and checking again"
        Start-Sleep -s 40
        $rpstatus = Get-AzResourceProvider -ProviderNamespace "Microsoft.Compute"
        if ($rpstatus.RegistrationState -ne "Registered") {
            Write-Host "Microsoft.Compute is still not registered, moving on"
        }
    }

    # Get the feature and if already registered, ignore, otherwise register, output to screen
    foreach ($feature in $features) {
        $featurestatus = Get-AzProviderFeature -FeatureName $feature -ProviderNamespace "Microsoft.Compute"
        if ($featurestatus.RegistrationState -eq "Registered") {
            Write-Host "$feature is already registered"
        } else {
            Register-AzProviderFeature -ProviderNamespace "Microsoft.Compute" -FeatureName $feature
            Write-Host "$feature is now registered"
        }
    }
}