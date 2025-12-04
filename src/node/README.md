# @connorbritain/mssql-mcp-server

Model Context Protocol server for SQL Server. Enterprise-ready schema discovery, profiling, and safe data operations.

## Features

- **Multi-environment support** - Define named database environments (prod, staging, dev) with per-environment policies
- **Governance controls** - `allowedTools`, `deniedTools`, `allowedSchemas`, `deniedSchemas`, `requireApproval`
- **Server-level access** - Query across multiple databases on a single SQL Server instance
- **Audit logging** - JSON Lines logs with session IDs, auto-redaction of sensitive data
- **Secret management** - `${secret:NAME}` placeholders resolve from environment variables
- **Safe by default** - `READONLY` mode, preview/confirm for mutations, automatic row limits

## Install

```bash
npm install -g @connorbritain/mssql-mcp-server@latest
# or run ad-hoc
npx @connorbritain/mssql-mcp-server@latest
```

## Quick Start

| Variable | Required | Notes |
| --- | --- | --- |
| `SERVER_NAME` | ✅ | SQL Server hostname/IP |
| `DATABASE_NAME` | ✅ | Database to target |
| `SQL_AUTH_MODE` |  | `sql`, `windows`, or `aad` (default `aad`) |
| `SQL_USERNAME`/`SQL_PASSWORD` |  | Required for `sql`/`windows` modes |
| `READONLY` |  | `true` disables write tools |
| `ENVIRONMENTS_CONFIG_PATH` |  | Path to multi-environment JSON config |

## Example MCP config

```json
{
  "mcpServers": {
    "mssql": {
      "command": "npx",
      "args": ["@connorbritain/mssql-mcp-server@latest"],
      "env": {
        "SERVER_NAME": "127.0.0.1",
        "DATABASE_NAME": "sampledb",
        "SQL_AUTH_MODE": "sql",
        "SQL_USERNAME": "sa",
        "SQL_PASSWORD": "YourPassword123",
        "READONLY": "false"
      }
    }
  }
}
```

This package ships precompiled JS under `dist/`. 

**Full documentation:** See the [main README](../../README.md) for complete feature list, configuration options, and safety guidance.

**Repository:** https://github.com/ConnorBritain/mssql-mcp-server
