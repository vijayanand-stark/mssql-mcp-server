# SQL Server MCP 🛢

A **Model Context Protocol (MCP) server for Microsoft SQL Server** built for real-world enterprise database work.

I'm a data architect and engineer working in national-scale, highly regulated environments. This server powers my daily workflows—exploring unfamiliar schemas, prototyping queries, validating data pipelines in UAT, then porting that work to production with confidence. If you spend your days inside SQL Server and want AI tooling that actually understands your database, this is for you.

---

## Why this exists

Most SQL + AI demos stop at "generate a query." That's table stakes. Real database work means:

- **Navigating massive schemas** you didn't design, often with cryptic naming conventions
- **Understanding data shape** before writing anything
- **Working safely** in regulated environments where one bad UPDATE can trigger an incident
- **Moving fast in UAT** so you can validate changes before they hit production

This server is built around those realities. It's stable, secure by default, and designed to make AI assistants genuinely useful on enterprise SQL Server instances.

---

## What's here today

- **Semantic schema discovery** – `search_schema` finds tables/columns via wildcards with fuzzy matching and paginated results so large databases don’t blow up your context window.
- **Table profiling** – `profile_table` summarizes column shape (null %, cardinality, min/max/avg/median/p90) and can return a capped sample of rows.
- **Relationship mapping** – `inspect_relationships` enumerates inbound/outbound FKs with column mappings, so you can follow dependencies before touching data.
- **Flexible authentication** – SQL auth, Windows auth, and Azure AD are supported; pick what matches your infra.
- **Safe data operations** – `read_data`, `describe_table`, `list_table`, plus write tools (`insert_data`, `update_data`, `delete_data`, `create_table`, `create_index`, `drop_table`) when you need full agent-mode workflows.
- **Preview + Confirm for mutations** – `update_data` and `delete_data` show affected rows before execution; require explicit confirmation to proceed.
- **Multi-environment support** – Define named database environments (prod, staging, dev) in a JSON config; switch between them per request.
- **Audit logging** – Every tool invocation logged to JSON Lines format with timestamps, arguments (auto-redacted), and results.
- **MCP-native** – Works with Windsurf, Claude Desktop, and any MCP-compatible client.

### Key tools at a glance

- `search_schema` (read) – Wildcard/fuzzy discovery with pagination + fuzzy suggestions.
- `profile_table` (read) – Column stats, percentile metrics, limited sample exposure.
- `inspect_relationships` (read) – FK maps in both directions.
- `read_data` / `describe_table` / `list_table` (read) – Bread-and-butter querying + schema inspection.
- `insert_data`, `update_data`, `delete_data`, `create_table`, `create_index`, `drop_table` (write) – Opt-in CRUD/DDL helpers for agent workflows (auto-disabled when `READONLY=true`). UPDATE and DELETE require preview confirmation.

---

## Prerequisites

You’ll need a current Node.js runtime (minimum 18, recommended 20 LTS). The tooling now shims legacy APIs so it also works on the newest Node releases, but installing an LTS build avoids surprises on fresh machines.

| Platform | Command (installs Node 20 LTS) |
| --- | --- |
| Windows | `winget install --id OpenJS.NodeJS.LTS -e` |
| macOS | `brew install node@20 && brew link --overwrite --force node@20` |
| Ubuntu/Debian | `curl -fsSL https://deb.nodesource.com/setup_20.x \| sudo -E bash - && sudo apt-get install -y nodejs` |

Verify with `node -v` (should show `v20.x`). If you already have a newer Node version installed, the server will still run thanks to the built-in SlowBuffer shim.

## Quick start

### Option 1: Install from npm (recommended)

```bash
npm install -g @connorbritain/mssql-mcp-server@latest
```

Then configure your MCP client:

```json
{
  "mcpServers": {
    "mssql": {
      "command": "npx",
      "args": ["@connorbritain/mssql-mcp-server@latest"],
      "env": { "SERVER_NAME": "localhost", "DATABASE_NAME": "mydb", "READONLY": "true" }
    }
  }
}
```

### Option 2: Build from source

```bash
git clone https://github.com/ConnorBritain/mssql-mcp-server.git
cd mssql-mcp-server/src/node
npm install
npm run build
```

Then point your MCP client to `src/node/dist/index.js` with your connection env vars
```

---

## Configuration

### Environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `SERVER_NAME` | | SQL Server hostname or IP (e.g., `localhost`, `127.0.0.1`, `myserver.database.windows.net`) |
| `DATABASE_NAME` | | Target database name |
| `SQL_AUTH_MODE` | | Authentication mode: `sql`, `windows`, or `aad` (default: `aad`) |
| `SQL_USERNAME` | | Username for SQL or Windows auth |
| `SQL_PASSWORD` | | Password for SQL or Windows auth |
| `SQL_DOMAIN` | | Domain for Windows/NTLM auth (optional) |
| `SQL_PORT` | | Custom port (default: `1433`). Useful for named instances or Docker containers on non-standard ports. |
| `TRUST_SERVER_CERTIFICATE` | | Set to `true` for self-signed certificates or dev environments |
| `CONNECTION_TIMEOUT` | | Connection timeout in seconds (default: `30`) |
| `READONLY` | | Set to `true` to restrict to read-only tools (no INSERT, UPDATE, DELETE, DROP) |
| `MAX_ROWS_DEFAULT` | | Auto-limit for SELECT queries without TOP/LIMIT (default: `1000`, range: 1-100000) |
| `REQUIRE_MUTATION_CONFIRMATION` | | Set to `false` to skip preview/confirm for mutations (default: `true`) |
| `ENVIRONMENTS_CONFIG_PATH` | | Path to JSON file defining multiple named database environments |
| `AUDIT_LOG_PATH` | | Path for audit log file (default: `logs/audit.jsonl`) |
| `AUDIT_LOGGING` | | Set to `false` to disable audit logging (default: `true`) |
| `AUDIT_REDACT_SENSITIVE` | | Set to `false` to disable redaction of sensitive args (default: `true`) |
| `PROFILE_SAMPLE_SIZE_DEFAULT` | | Default sample size for `profile_table` (defaults to `50`, max `1000`) |
| `PROFILE_SAMPLE_RETURN_LIMIT` | | Max number of sample rows returned in responses (defaults to `10`, max `100`) |
| `SEARCH_SCHEMA_DEFAULT_LIMIT` | | Default row limit per section for `search_schema` pagination (defaults to `50`, max `200`) |

### Authentication modes

**SQL Server Authentication** (`SQL_AUTH_MODE=sql`)  
Standard username/password auth against SQL Server. Works with local instances, Docker containers, and Azure SQL with SQL auth enabled.

```json
"env": {
  "SERVER_NAME": "127.0.0.1",
  "DATABASE_NAME": "mydb",
  "SQL_AUTH_MODE": "sql",
  "SQL_USERNAME": "sa",
  "SQL_PASSWORD": "YourPassword123",
  "SQL_PORT": "1433",
  "TRUST_SERVER_CERTIFICATE": "true"
}
```

**Windows Authentication** (`SQL_AUTH_MODE=windows`)  
NTLM-based auth using domain credentials. Ideal for on-prem SQL Server in Active Directory environments.

```json
"env": {
  "SERVER_NAME": "sqlserver.corp.local",
  "DATABASE_NAME": "mydb",
  "SQL_AUTH_MODE": "windows",
  "SQL_USERNAME": "svc_account",
  "SQL_PASSWORD": "YourPassword123",
  "SQL_DOMAIN": "CORP"
}
```

**Azure AD Authentication** (`SQL_AUTH_MODE=aad` or omit)  
Interactive browser-based Azure AD authentication. Opens a browser window on first connection to authenticate. Best for Azure SQL Database with AAD-only auth.

```json
"env": {
  "SERVER_NAME": "myserver.database.windows.net",
  "DATABASE_NAME": "mydb",
  "SQL_AUTH_MODE": "aad"
}
```

### Multiple instances / Docker

If you're running multiple SQL Server instances (e.g., local dev on 1433, Docker on 1434), just change `SQL_PORT`:

```json
"env": {
  "SERVER_NAME": "127.0.0.1",
  "DATABASE_NAME": "devdb",
  "SQL_AUTH_MODE": "sql",
  "SQL_USERNAME": "sa",
  "SQL_PASSWORD": "DockerPassword123",
  "SQL_PORT": "1434",
  "TRUST_SERVER_CERTIFICATE": "true"
}
```

You can also run multiple instances of the MCP server in your config, each pointing to a different database or environment.

### Multi-environment configuration

For managing multiple databases (prod, staging, client DBs), create an `environments.json` file:

```json
{
  "defaultEnvironment": "dev",
  "environments": [
    {
      "name": "dev",
      "server": "localhost",
      "database": "DevDB",
      "authMode": "sql",
      "username": "sa",
      "password": "DevPassword123",
      "trustServerCertificate": true,
      "readonly": false
    },
    {
      "name": "prod",
      "server": "prod-server.database.windows.net",
      "database": "ProdDB",
      "authMode": "aad",
      "readonly": true,
      "description": "Production - read only"
    }
  ]
}
```

Then point to it:

```json
"env": {
  "ENVIRONMENTS_CONFIG_PATH": "/path/to/environments.json"
}
```

Tools accept an optional `environment` parameter to target a specific environment. The IntentRouter can also infer environments from natural language (e.g., "show tables in prod" → uses `prod` environment).

---

## ⚠️ Safety & Prudence

**With great power comes great responsibility.**

This MCP server exposes powerful CRUD operations including `drop_table`, `create_table`, `update_data`, and `insert_data`. If you enable full autopilot mode in your AI assistant—or simply aren't inspecting each tool call—you could trigger destructive actions you don't intend.

### Recommended Safeguards

1. **Use `READONLY=true` by default.** This globally disables all write operations, exposing only safe discovery tools. Enable write mode only when you explicitly need it.

2. **Preview before mutations.** `update_data` and `delete_data` show affected rows and require explicit confirmation (`confirmUpdate: true` / `confirmDelete: true`) before executing. Row counts are capped at 1000 by default.

3. **Be a prudent human in the loop.** Review tool calls before approval, especially for destructive operations. Don't blindly trust AI-generated queries against production data.

3. **Use dedicated credentials.** Connect with a database user that has only the permissions you intend to grant. Avoid `sa` or admin accounts in production.

4. **Test in non-production first.** Validate tool behavior against development or staging databases before pointing at production.

5. **Monitor and audit.** Audit logging is enabled by default—check `logs/audit.jsonl` for a record of all tool invocations. Sensitive parameters are auto-redacted.

The discovery tools (`search_schema`, `profile_table`, `inspect_relationships`) are designed to help you understand unfamiliar databases safely. Use them to build context before issuing any mutations.

### Tool tuning

- **Schema discovery pagination** – Use `SEARCH_SCHEMA_DEFAULT_LIMIT` to tune how many rows `search_schema` returns per page (default 50, max 200). Combine with `tableOffset`/`columnOffset` params for manual paging.
- **Profiling samples** – Use `PROFILE_SAMPLE_SIZE_DEFAULT` to control how many rows are sampled internally (default 50). Control how many rows are actually returned with `PROFILE_SAMPLE_RETURN_LIMIT` (default 10). Both respect per-request overrides via `sampleSize` and `includeSamples` args.

---

## Roadmap

See [ROADMAP.md](./ROADMAP.md) for the full enterprise roadmap with status tracking.

**Recently shipped:**
- ✅ Multi-environment connection profiles
- ✅ Automatic row limiting for SELECT queries
- ✅ Audit logging with sensitive data redaction
- ✅ Preview/confirm flows for UPDATE and DELETE
- ✅ Intent-based environment inference from natural language

**Next priorities:**
- ✅ Query plan preview (`explain_query` with SHOWPLAN) - shipped!
- Per-environment policy controls
- Named/template SQL scripts for repeatable operations
- Configuration validation and health checks

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines. If you're working with SQL Server in environments where stability and security matter, I'd love to hear what tools would help you most.

**If this project is useful to you, consider giving it a ⭐ on [GitHub](https://github.com/ConnorBritain/mssql-mcp-server) and sharing it with others who work with SQL Server.** The more eyes on it, the better it gets.

---

## License & attribution

MIT license. See [LICENSE](./LICENSE) for details.

This project was originally forked from Microsoft's [SQL-AI-samples](https://github.com/Azure-Samples/SQL-AI-samples) and has since evolved into a standalone, production-focused MCP server. Thanks to the Microsoft Azure SQL team for the initial foundation, and to the MCP community for the protocol specs that make cross-agent tooling possible.

---

## Versioning

This package follows [semver](https://semver.org/). Note: version 1.0.1 is permanently reserved on npm due to a prior publish and cannot be used for future releases.

---

**Repository:** https://github.com/ConnorBritain/mssql-mcp-server  
**npm package:** https://www.npmjs.com/package/@connorbritain/mssql-mcp-server  
**Issues & support:** https://github.com/ConnorBritain/mssql-mcp-server/issues