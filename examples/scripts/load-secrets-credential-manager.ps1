<#######################################################################
# load-secrets-credential-manager.ps1
#
# Sample helper that reads SQL passwords from Windows Credential Manager
# and exposes them as environment variables for the current process.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File load-secrets-credential-manager.ps1
#
# Before running, store credentials using cmdkey:
#   cmdkey /generic:sql/local-sa /user:sa /pass:P@ssword1
#   cmdkey /generic:sql/qa-user   /user:qa_mcp_user /pass:P@ssword2
#######################################################################>

param([switch]$UserScope)

function Set-SecretEnv {
  param(
    [Parameter(Mandatory)] [string]$EnvName,
    [Parameter(Mandatory)] [string]$CredentialTarget
  )

  $credential = Get-StoredCredential -Target $CredentialTarget
  if (-not $credential) {
    throw "Credential '$CredentialTarget' not found in Windows Credential Manager."
  }

  $scope = if ($UserScope) { 'User' } else { 'Process' }
  $value = $credential.GetNetworkCredential().Password
  [Environment]::SetEnvironmentVariable($EnvName, $value, $scope)
  Write-Host "Set $EnvName from Credential Manager target '$CredentialTarget'"
}

Set-SecretEnv -EnvName 'SQL_LOCAL_PASSWORD' -CredentialTarget 'sql/local-sa'
Set-SecretEnv -EnvName 'SQL_QA_PASSWORD'    -CredentialTarget 'sql/qa-user'
Write-Host "Credential Manager secrets loaded."
