[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    [Parameter(Mandatory = $false)]
    [switch]$GlobalMapping,
    [Parameter(Mandatory = $true)]
    [string]$LocalPath,
    [Parameter(Mandatory = $false)]
    [switch]$Persistent,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountFileSharePath,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountSubscriptionId
)

function Get-AzureStorageAccountPrimaryKey {
    <#
        References:
            - https://learn.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service
            - https://learn.microsoft.com/en-us/rest/api/storageservices/versioning-for-the-azure-storage-services
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )

    $ErrorActionPreference = 'Stop';
    $ProgressPreference = 'SilentlyContinue';

    $webRequestResponse = Invoke-WebRequest `
        -Headers @{ Metadata = 'true' } `
        -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2023-07-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' `
        -UseBasicParsing;
    $accessToken = [Text.Json.JsonDocument]::Parse($webRequestResponse.Content).RootElement.GetProperty('access_token').GetString();
    $webRequestResponse = Invoke-WebRequest `
        -Headers @{ Authorization = "Bearer $accessToken"; } `
        -Method 'POST' `
        -Uri "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$Name/listKeys?api-version=2024-01-01" `
        -UseBasicParsing;

    foreach ($key in [Text.Json.JsonDocument]::Parse($webRequestResponse.Content).RootElement.GetProperty('keys').EnumerateArray()) {
        if ('key1' -eq $key.GetProperty('keyName').GetString()) {
            return $key.GetProperty('value').GetString();
        }
    }
}

$ErrorActionPreference = 'Stop';
$ProgressPreference = 'SilentlyContinue';

$StorageAccountFileSharePath = $StorageAccountFileSharePath.Replace('/', '\');

New-SmbMapping `
    -GlobalMapping:$GlobalMapping `
    -Password (Get-AzureStorageAccountPrimaryKey `
        -Name $StorageAccountName `
        -ResourceGroupName $StorageAccountResourceGroupName `
        -SubscriptionId $StorageAccountSubscriptionId
    ) `
    -Persistent:$Persistent `
    -RemotePath $StorageAccountFileSharePath `
    -UserName "localhost\$StorageAccountName" |
    Out-Null;

New-Item `
    -Force:$Force `
    -ItemType 'SymbolicLink' `
    -Path $LocalPath `
    -Value $StorageAccountFileSharePath |
    Out-Null;

exit 0;
