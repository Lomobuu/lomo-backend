param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerName,

    [Parameter(Mandatory = $true)]
    [string]$Location
)

Write-Host "Creating Terraform backend resources..."

#
# Resource Group
#

$rg = Get-AzResourceGroup `
    -Name $ResourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $rg) {

    Write-Host "Creating Resource Group..."

    New-AzResourceGroup `
        -Name $ResourceGroupName `
        -Location $Location
}

#
# Storage Account
#

$storage = Get-AzStorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName `
    -ErrorAction SilentlyContinue

if (-not $storage) {

    Write-Host "Creating Storage Account..."

    $storage = New-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -Location $Location `
        -SkuName Standard_LRS `
        -Kind StorageV2 `
        -AllowBlobPublicAccess $false `
        -MinimumTlsVersion TLS1_2

    Update-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -AllowSharedKeyAccess $false
}

#
# Blob Data Contributor
#

try {

    $principal = Get-AzADUser -SignedIn

    New-AzRoleAssignment `
        -ObjectId $principal.Id `
        -RoleDefinitionName "Storage Blob Data Contributor" `
        -Scope $storage.Id `
        -ErrorAction Stop
}
catch {
    Write-Host "Role assignment already exists."
}

#
# Container
#

$ctx = New-AzStorageContext `
    -StorageAccountName $StorageAccountName `
    -UseConnectedAccount

$container = Get-AzStorageContainer `
    -Name $ContainerName `
    -Context $ctx `
    -ErrorAction SilentlyContinue

if (-not $container) {

    Write-Host "Creating container..."

    New-AzStorageContainer `
        -Name $ContainerName `
        -Permission Off `
        -Context $ctx
}

#
# Lock Resource Group
#

$lock = Get-AzResourceLock `
    -ResourceGroupName $ResourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $lock) {

    Write-Host "Applying CanNotDelete lock..."

    New-AzResourceLock `
        -LockName "cannot-delete" `
        -LockLevel CanNotDelete `
        -ResourceGroupName $ResourceGroupName
}

#
# Outputs
#

"resource_group_name=$ResourceGroupName" >> $env:GITHUB_OUTPUT
"storage_account_name=$StorageAccountName" >> $env:GITHUB_OUTPUT
"container_name=$ContainerName" >> $env:GITHUB_OUTPUT