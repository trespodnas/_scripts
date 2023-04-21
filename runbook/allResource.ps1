<#
    .DESCRIPTION
        Runbook which gets all the resources using the Managed Identity

    .NOTES
        AUTHOR: Tim Wolff
        LASTEDIT: Apr 3, 2023
#>

try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
#Connect to the subscription
Select-AzSubscription 9a09c126-ca50-4406-a438-899badcf2828

# Define Variables
$NameOfContainer = 'operations'
$ReportDate = (Get-Date).ToString("yyyyMMdd")

$resources = Get-AzResource
$fileName = "resources$ReportDate.txt"
$storeageAcct = Get-AzStorageAccount | Where-Object {$_.StorageAccountName -eq 'operations'}
$body = Get-AzResource

# Set variables for the Azure Storage account and container
$key = Get-AzStorageAccountKey -ResourceGroupName $storeageAcct.ResourceGroupName -Name $storeageAcct.StorageAccountName
$ctx = New-AzStorageContext -StorageAccountName $storeageAcct.StorageAccountName -StorageAccountKey $key[0].Value
$containerName = Get-AzStorageContainer -Context $ctx -Name $storeageAcct | Where-Object {$_.Name -eq $NameOfContainer}
$containerName = $containerName.Name
$storageAcctName = $storeageAcct.StorageAccountName

$sasToken = New-AzStorageBlobSASToken -Container $containerName -Context $ctx -Blob $fileName -Permission "rwa"

# Set the URI for the Azure Storage Blob service
$uri = "https://$storageAcctName.blob.core.windows.net/$containerName/$fileName$sasToken"

# Set the headers and request body for the REST API call to create a new blob
$headers = @{    
    "x-ms-blob-type" = "BlockBlob" 
}

# Populate and format the output file
#$body = $resources | Select-Object ResourceType, ResourceName, CreatedTime, CreatedOn, CreatedBy, ChangedTime | Format-Table | Out-String
$body = $resources | Select-Object  ResourceType, ResourceGroupName, ResourceName, CreatedTime, CreatedOn, CreatedBy, ChangedTime | Sort-Object -Property ResourceType, ResourceGroupName | Format-Wide | Out-String

# Invoke the REST API call to create the new blob
Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body 
