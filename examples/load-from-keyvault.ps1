# load-from-keyvault.ps1
# Load SQL Server credentials from Azure Key Vault
# Usage: . .\load-from-keyvault.ps1 -VaultName "my-vault"
#
# Prerequisites:
# 1. Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
# 2. Login to Azure: az login
# 3. Ensure you have access to the Key Vault secrets
#
# Store your secrets in Key Vault:
#   az keyvault secret set --vault-name "my-vault" --name "sql-prod-username" --value "myuser"
#   az keyvault secret set --vault-name "my-vault" --name "sql-prod-password" --value "mypassword"

param(
    [Parameter(Mandatory = $true)]
    [string]$VaultName,

    # Map of Key Vault secret names to environment variable names
    [hashtable]$SecretMap = @{
        "sql-prod-username" = "PROD_SQL_USERNAME"
        "sql-prod-password" = "PROD_SQL_PASSWORD"
        "sql-dev-username"  = "DEV_SQL_USERNAME"
        "sql-dev-password"  = "DEV_SQL_PASSWORD"
    }
)

# Check if Azure CLI is installed
$azPath = Get-Command az -ErrorAction SilentlyContinue
if (-not $azPath) {
    Write-Error "Azure CLI not found. Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in to Azure. Running 'az login'..."
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure login failed"
        exit 1
    }
}

Write-Host "Loading secrets from Azure Key Vault: $VaultName"
Write-Host ""

foreach ($secretName in $SecretMap.Keys) {
    $envVarName = $SecretMap[$secretName]

    try {
        $secretValue = az keyvault secret show `
            --vault-name $VaultName `
            --name $secretName `
            --query "value" `
            --output tsv 2>&1

        if ($LASTEXITCODE -eq 0 -and $secretValue) {
            [Environment]::SetEnvironmentVariable($envVarName, $secretValue, "Process")
            Write-Host "  Loaded: $secretName -> $envVarName"
        }
        else {
            Write-Warning "  Secret not found or access denied: $secretName"
        }
    }
    catch {
        Write-Warning "  Failed to load secret '$secretName': $_"
    }
}

Write-Host ""
Write-Host "Secrets loaded. You can now start the MCP server."
Write-Host ""
Write-Host "Your environments.json can reference these as:"
Write-Host '  "username": "${secret:PROD_SQL_USERNAME}"'
Write-Host '  "password": "${secret:PROD_SQL_PASSWORD}"'
Write-Host ""
Write-Host "Example MCP server start:"
Write-Host "  npx @connorbritain/mssql-mcp-server"
