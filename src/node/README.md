# @connorbritain/mssql-mcp-server

Model Context Protocol server for SQL Server. This is the Node.js implementation.

## Install

```bash
npm install -g @connorbritain/mssql-mcp-server@latest
# or run ad-hoc
npx @connorbritain/mssql-mcp-server@latest
```

## CLI

```
mssql-mcp-server
```

The entrypoint expects env vars:

| Variable | Required | Notes |
| --- | --- | --- |
| `SERVER_NAME` | ✅ | SQL Server hostname/IP |
| `DATABASE_NAME` | ✅ | Database to target |
| `SQL_AUTH_MODE` |  | `sql`, `windows`, or `aad` (default `aad`) |
| `SQL_USERNAME`/`SQL_PASSWORD` |  | Required for `sql`/`windows` modes |
| `SQL_DOMAIN` |  | Optional for NTLM |
| `SQL_PORT` |  | Defaults to `1433` |
| `TRUST_SERVER_CERTIFICATE` |  | Set `true` for dev/self-signed |
| `CONNECTION_TIMEOUT` |  | Seconds, default `30` |
| `READONLY` |  | `true` disables write tools |
| `PROFILE_SAMPLE_SIZE_DEFAULT` |  | Default profiling sample size (default `50`) |
| `PROFILE_SAMPLE_RETURN_LIMIT` |  | Max sample rows returned (default `10`) |
| `SEARCH_SCHEMA_DEFAULT_LIMIT` |  | Default pagination size for `search_schema` (default `50`) |

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
