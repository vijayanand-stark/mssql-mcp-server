<#######################################################################
# load-secrets-keyvault.ps1
#
# Sample helper that retrieves SQL passwords from Azure Key Vault and
# exposes them as environment variables for the current process.
#
# Prerequisites:
#   az login
#   az keyvault secret set --vault-name MyKeyVault --name sql-local-password --value P@ssword1
#   az keyvault secret set --vault-name MyKeyVault --name sql-qa-password    --value P@ssword2
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File load-secrets-keyvault.ps1 -VaultName MyKeyVault
#######################################################################>

param(
  [string]$VaultName = "MyKeyVault"
)

function Set-SecretEnvFromKeyVault {
  param(
    [Parameter(Mandatory)] [string]$EnvName,
    [Parameter(Mandatory)] [string]$SecretName
  )

  $value = az keyvault secret show `
    --vault-name $VaultName `
    --name $SecretName `
    --query value `
    -o tsv

  if (-not $value) {
    throw "Secret '$SecretName' not found in vault '$VaultName'."
  }

  [Environment]::SetEnvironmentVariable($EnvName, $value, 'Process')
  Write-Host "Set $EnvName from Azure Key Vault secret '$SecretName'"
}

Set-SecretEnvFromKeyVault -EnvName 'SQL_LOCAL_PASSWORD' -SecretName 'sql-local-password'
Set-SecretEnvFromKeyVault -EnvName 'SQL_QA_PASSWORD'    -SecretName 'sql-qa-password'
Write-Host "Key Vault secrets loaded."
