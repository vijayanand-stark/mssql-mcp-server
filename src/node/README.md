# @connorbritain/mssql-mcp-server

Model Context Protocol server for SQL Server. Enterprise-ready schema discovery, profiling, and safe data operations.

## Features

- **20+ tools** for schema discovery, data operations, profiling, and administration
- **Multi-environment support** – Named database environments (prod, staging, dev) with per-environment policies
- **Governance controls** – `allowedTools`, `deniedTools`, `allowedSchemas`, `deniedSchemas`, `requireApproval`
- **Named SQL scripts** – Pre-approved parameterized scripts with tier and environment restrictions
- **Server-level access** – Query across multiple databases on a single SQL Server instance
- **Dependency analysis** – Find all objects referencing a table before making changes
- **Audit logging** – JSON Lines logs with session IDs, auto-redaction of sensitive data
- **Secret management** – `${secret:NAME}` placeholders resolve from environment variables
- **Safe by default** – `READONLY` mode, preview/confirm for mutations, automatic row limits

## Tools

| Category | Tools |
|----------|-------|
| **Discovery** | `search_schema`, `describe_table`, `list_table`, `list_databases`, `list_environments` |
| **Profiling** | `profile_table`, `inspect_relationships`, `inspect_dependencies`, `explain_query` |
| **Data** | `read_data`, `insert_data`, `update_data`, `delete_data` |
| **DDL** | `create_table`, `create_index`, `drop_table` |
| **Scripts** | `list_scripts`, `run_script` |
| **Operations** | `test_connection`, `validate_environment_config` |

## Install

```bash
npm install -g @connorbritain/mssql-mcp-server@latest
# or run directly
npx @connorbritain/mssql-mcp-server@latest
```

## Configuration

| Variable | Required | Notes |
|----------|----------|-------|
| `SERVER_NAME` | ✅ | SQL Server hostname/IP |
| `DATABASE_NAME` | ✅ | Database to target |
| `SQL_AUTH_MODE` | | `sql`, `windows`, or `aad` (default: `aad`) |
| `SQL_USERNAME` / `SQL_PASSWORD` | | Required for `sql`/`windows` modes |
| `READONLY` | | `true` disables write tools |
| `ENVIRONMENTS_CONFIG_PATH` | | Path to multi-environment JSON config |
| `SCRIPTS_PATH` | | Path to named SQL scripts directory |
| `AUDIT_LOG_PATH` | | Custom audit log path (default: `logs/audit.jsonl`) |

## MCP Client Config

```json
{
  "mcpServers": {
    "mssql": {
      "command": "npx",
      "args": ["@connorbritain/mssql-mcp-server@latest"],
      "env": {
        "SERVER_NAME": "127.0.0.1",
        "DATABASE_NAME": "mydb",
        "SQL_AUTH_MODE": "sql",
        "SQL_USERNAME": "sa",
        "SQL_PASSWORD": "YourPassword123",
        "READONLY": "true"
      }
    }
  }
}
```

## Multi-Environment Example

Create `environments.json`:

```json
{
  "defaultEnvironment": "dev",
  "scriptsPath": "./scripts",
  "environments": [
    {
      "name": "dev",
      "server": "localhost",
      "database": "DevDB",
      "authMode": "sql",
      "username": "${secret:DEV_USER}",
      "password": "${secret:DEV_PASS}",
      "readonly": false
    },
    {
      "name": "prod",
      "server": "prod.database.windows.net",
      "database": "ProdDB",
      "authMode": "aad",
      "readonly": true,
      "requireApproval": true,
      "auditLevel": "verbose"
    }
  ]
}
```

Then set `ENVIRONMENTS_CONFIG_PATH=/path/to/environments.json`.

## Documentation

**Full documentation:** [GitHub README](https://github.com/ConnorBritain/mssql-mcp-server#readme)

**Repository:** https://github.com/ConnorBritain/mssql-mcp-server

**Issues:** https://github.com/ConnorBritain/mssql-mcp-server/issues
