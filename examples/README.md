# Credential & Environment Configuration Examples

This folder contains sample templates that demonstrate different ways to wire up credentials and database environments for the MSSQL MCP server. Every file uses **generic placeholders** so you can safely check these examples into version control and share them internally.

> ⚠️ None of these files contain real secrets. Replace the placeholders with values that map to **your** infrastructure.

## Files

| File | Description |
|------|-------------|
| `environments.template.json` | Example `ENVIRONMENTS_CONFIG_PATH` file showing how to reference secrets via environment variables for local, QA, and production tiers. |
| `scripts/load-secrets-credential-manager.ps1` | PowerShell helper that loads passwords from Windows Credential Manager into environment variables. |
| `scripts/load-secrets-keyvault.ps1` | PowerShell helper that pulls secrets from Azure Key Vault. |
| `scripts/generate-environments.ps1` | Utility that lets you paste a list of database names and emits an `environments.json` with consistent naming and placeholder credentials. |

## Usage Pattern

1. **Store secrets** using your preferred tool (Credential Manager, Azure Key Vault, etc.).
2. **Run one of the loader scripts** to populate environment variables like `SQL_LOCAL_PASSWORD`.
3. **Copy `environments.template.json`** to a secure location (e.g., `C:/mcp/environments.json`) and edit the placeholder values.
4. Point your MCP client to the generated file via `ENVIRONMENTS_CONFIG_PATH`.

```json
{
  "mcpServers": {
    "mssql": {
      "command": "npx",
      "args": ["@connorbritain/mssql-mcp-server@latest"],
      "env": {
        "ENVIRONMENTS_CONFIG_PATH": "C:/mcp/environments.json",
        "AUDIT_LOG_PATH": "C:/mcp/logs/audit.jsonl"
      }
    }
  }
}
```

Feel free to adapt the scripts for other secret providers (1Password CLI, HashiCorp Vault, etc.). Contributions that add additional providers are welcome—just keep real hostnames, usernames, and passwords out of the repo.
