# load-env.ps1
# Load environment variables from a .env file for the MSSQL MCP Server
# Usage: . .\load-env.ps1 [path-to-env-file]
#
# This script loads key=value pairs from a .env file into the current
# PowerShell session's environment variables.

param(
    [string]$EnvFile = ".env"
)

if (-not (Test-Path $EnvFile)) {
    Write-Warning "Environment file not found: $EnvFile"
    Write-Host "Create a .env file with your credentials:"
    Write-Host ""
    Write-Host "  # .env example"
    Write-Host "  PROD_SQL_USERNAME=myuser"
    Write-Host "  PROD_SQL_PASSWORD=mypassword"
    Write-Host "  DEV_SQL_PASSWORD=devpassword"
    Write-Host ""
    exit 1
}

Write-Host "Loading environment from: $EnvFile"

Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()

    # Skip empty lines and comments
    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }

    # Parse key=value pairs
    if ($line -match "^([^=]+)=(.*)$") {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()

        # Remove surrounding quotes if present
        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        # Set environment variable
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
        Write-Host "  Set: $key"
    }
}

Write-Host ""
Write-Host "Environment loaded. You can now start the MCP server."
Write-Host "Example: npx @connorbritain/mssql-mcp-server"
