# SQL Server MCP – Enterprise Roadmap

This roadmap focuses on making the SQL Server MCP server production-ready for enterprise use, especially in environments with many client databases, strict security, and complex networking.

Each item is roughly ranked by **Value-Add (V)**, **Complexity (C)**, **Feasibility (F)**, and **Market Relevance (M)** on a 1–5 scale (5 = highest). Overall priority is based primarily on V + M, then adjusted by C and F. We now also track **Status** (✅ implemented, 🚧 partially implemented, ⛔ not started) so the roadmap reflects what already ships in this repo.

Scoring legend:

- **V** – How much this helps real-world enterprise workflows (RDP reduction, fewer prod incidents, faster support).
- **C** – Implementation complexity (higher = harder / more effort).
- **F** – Feasibility given typical stack / infra (higher = easier / more realistic near-term).
- **M** – How many orgs are likely to care (breadth of applicability).

---

## 1. Core, Safe Querying & Connection Management (Top Priority)

### 1.1. Environment / Connection Profiles

- **Description**: Named environments like `client_foo_prod`, `client_bar_stage`, `internal_dev` with connection strings, auth mode, default database/schema, and safety flags.
- **Why**: Mirrors how DBAs/support already think about fleets of SQL Servers; provides a single abstraction for everything else.
- **Status**: ✅ Implemented – EnvironmentManager supports JSON config files with named environments (@MssqlMcp/Node/src/config/EnvironmentManager.ts#1-250). Falls back to env vars for single-DB mode. Tools accept optional `environment` parameter to select target. Example config at @environments.example.json. Configure via ENVIRONMENTS_CONFIG_PATH env var.
- **Key capabilities**:
  - ✅ Config-driven list of environments (JSON format).
  - ✅ Per-environment: server, database, port, auth mode, read-only vs read/write, allowed tools.
  - ✅ Ability to select environment per MCP request via `environment` parameter.
- **Score**: V=5, C=2, F=5, M=5 → **Overall Priority: P0**

### 1.2. Read-Only Query Tools (Guardrailed)

- **Description**: Tools for safe, constrained `SELECT` operations, always enforcing limits.
- **Why**: 90% of support/triage is reading data. Read-only with enforced `TOP n` is low-risk, high-value, and broadly useful.
- **Status**: ✅ Implemented – `read_data` enforces SELECT-only queries with keyword/pattern blocking, result sanitization, and automatic row limiting via MAX_ROWS_DEFAULT env var (default 1000, configurable 1-100k) (@MssqlMcp/Node/src/tools/ReadDataTool.ts#1-299). Queries without TOP/LIMIT are auto-limited.
- **Key capabilities**:
  - `execute_readonly_sql` with hard-coded safeguards (e.g., automatic `TOP 1000` if none specified, configurable).
  - Helper tools: `get_table_sample`, `describe_table`, `search_tables`, `search_columns`.
  - Schema-aware typing in responses (useful for agents).
- **Score**: V=5, C=3, F=5, M=5 → **Overall Priority: P0**

### 1.3. Secrets & Credential Management Integration

- **Description**: Connect to SQL via connection strings that pull credentials from secure stores instead of plain text.
- **Why**: Non-starter for most enterprises if credentials are in config files or editor settings.
- **Status**: 🚧 Baseline support – current server relies on environment variables for SQL/Windows/AAD auth (@README.md#68-143, @MssqlMcp/Node/src/index.ts#37-138) but lacks integrations with dedicated secret stores or rotation workflows.
- **Key capabilities**:
  - Support for environment-variable-based secrets initially.
  - Design-ready hooks for external secret stores (Key Vault, Vault, etc.).
  - Clear guidance/README on NOT checking secrets into the repo.
- **Score**: V=5, C=3, F=4, M=5 → **Overall Priority: P0**

### 1.4. Basic Audit Logging (Per Command)

- **Description**: Minimal audit log of every MCP tool invocation that touches SQL.
- **Why**: Enterprises need to know who ran what, where, and when. Even a simple log file is a huge step up.
- **Status**: ✅ Implemented – all tool invocations are logged to JSON Lines format (@MssqlMcp/Node/src/audit/AuditLogger.ts#1-116) with timestamp, tool name, arguments (redacted), result status, and duration. Configurable via AUDIT_LOG_PATH env var (defaults to logs/audit.jsonl). Toggle with AUDIT_LOGGING=false.
- **Key capabilities**:
  - Log entries including: timestamp, environment, user/session ID (if available), tool name, and SQL (with parameters, optionally redacted).
  - Pluggable log sinks (start with file-based logs; later SIEM/cloud sinks).
- **Score**: V=5, C=3, F=4, M=5 → **Overall Priority: P0–P1**

### 1.5. Intelligent Tool Routing & Multi-DB Selection

- **Description**: Add an intent-routing layer that selects the correct MCP tool (read vs. write vs. metadata) and the right database profile before executing, reducing "read_data everywhere" behavior.
- **Why**: Greatly improves UX and safety, especially once configs support multiple databases or tenants. Aligns SQL MCP with the natural-language precision seen in Atlassian/Supabase MCP servers.
- **Status**: ✅ Implemented – IntentRouter infers environments from natural language prompts ("show tables in prod", "query staging"), selects appropriate tools based on intent/keywords, and gates mutations with confirmation (@MssqlMcp/Node/src/index.ts#189-231). Missing: telemetry loop and LLM-augmented classification.
- **Key capabilities**:
  - ✅ Intent classifier (heuristics) that maps prompts to tool sequences (schema discovery, safe updates, audits, etc.).
  - ✅ Metadata-rich tool registry (side effects, requirements) so routing can reason about options.
  - ✅ Environment selector that chooses the correct connection profile from prompts when multiple databases are configured.
  - ⛔ Telemetry loop to learn from mis-routed calls.
- **Score**: V=5, C=4, F=4, M=5 → **Overall Priority: P0**

---

## 2. Safe Write Operations & Change Guardrails

### 2.1. Structured Safe-Update Tool(s)

- **Description**: Tools for performing `UPDATE`/`DELETE` with baked-in safety checks and previews.
- **Why**: Biggest risk in prod is accidental destructive write queries (missing `WHERE`, wrong environment). Guardrails are where MCP can shine.
- **Status**: ✅ Implemented – `update_data` and `delete_data` enforce required `WHERE` clauses, provide automatic preview of affected rows (TOP 10), row-count limits (default 1000, configurable via `maxRows`), and require explicit confirmation (`confirmUpdate`/`confirmDelete`) before execution (@MssqlMcp/Node/src/tools/UpdateDataTool.ts, @MssqlMcp/Node/src/tools/DeleteDataTool.ts).
- **Key capabilities**:
  - ✅ Automatic `SELECT` preview of rows that will be updated/deleted.
  - ✅ Disallow `UPDATE`/`DELETE` without `WHERE`, configurable thresholds for affected rows.
  - ⛔ Transactional behavior: `BEGIN TRANSACTION`, preview, then explicit commit/rollback (not yet implemented).
- **Score**: V=5, C=4, F=4, M=5 → **Overall Priority: P1**

### 2.2. Named / Template-Based Scripts

- **Description**: Library of parameterized, reviewed SQL scripts for common operations, exposed as MCP tools.
- **Why**: Real data fixes are often repeatable playbooks; templating them increases safety and speed.
- **Status**: ⛔ Not started – no script catalog or tooling exists today; all queries are free-form per tool call.
- **Key capabilities**:
  - Scripts stored in repo (e.g., `scripts/fix_duplicate_claims_v3.sql`).
  - MCP tool `run_named_script(name, parameters)` that validates allowed parameters.
  - Optional dry-run mode with preview.
- **Score**: V=4, C=3, F=4, M=4 → **Overall Priority: P1**

### 2.3. Dry-Run / Plan-Only Execution

- **Description**: Tool that executes `SET SHOWPLAN_XML ON` or equivalent to preview execution plan/row estimates without modifying data.
- **Why**: Lets users/agents see if a query is dangerous or heavy before running it in prod.
- **Status**: ✅ Implemented – `explain_query` generates estimated execution plans via SHOWPLAN, with optional XML output and natural-language-environment routing (@MssqlMcp/Node/src/tools/ExplainQueryTool.ts, @MssqlMcp/Node/src/index.ts#553-567).
- **Key capabilities**:
  - ✅ `explain_query(sql)` that returns plan + estimated row counts.
  - ⛔ Integration into safe-update tools as a pre-step (still pending).
- **Score**: V=4, C=3, F=4, M=4 → **Overall Priority: P1–P2**

---

## 3. Authentication & Network Topologies

### 3.1. SQL Authentication Support (Baseline)

- **Description**: Allow connection strings using SQL username/password, supplied securely.
- **Why**: Many orgs still use SQL auth, especially cross-domain or legacy.
- **Status**: ✅ Implemented – Node server supports `SQL_AUTH_MODE=sql` with `SQL_USERNAME`/`SQL_PASSWORD` env vars and constructs the connection accordingly (@MssqlMcp/Node/src/index.ts#37-74, @README.md#88-144).
- **Key capabilities**:
  - Clear schema for environment configs that include `User ID` / `Password` from env vars.
  - Connection pooling & robust error handling.
- **Score**: V=4, C=2, F=5, M=4 → **Overall Priority: Complete (already shipped)**

### 3.2. Integrated / Windows Authentication (On-Prem)

- **Description**: Support Windows/AD integrated security from domain-joined machines or service accounts.
- **Why**: Critical for many on-prem enterprises that forbid SQL auth in prod.
- **Status**: ✅ Implemented – NTLM-based Windows authentication is available when `SQL_AUTH_MODE=windows` with optional `SQL_DOMAIN` (@MssqlMcp/Node/src/index.ts#76-107, @README.md#88-147).
- **Key capabilities**:
  - Use appropriate .NET provider options (`Integrated Security=SSPI;`).
  - Documentation for running MCP as a domain user on a bastion/jump host.
- **Score**: V=5, C=4, F=3, M=5 → **Overall Priority: Complete (already shipped)**

### 3.3. Azure AD / Cloud Identity Integration

- **Description**: Use AAD tokens or managed identities to connect to Azure SQL / SQL Managed Instance.
- **Why**: Must-have for cloud-first shops; reduces password management.
- **Status**: ✅ Implemented – default auth path acquires an Azure AD access token via `InteractiveBrowserCredential` (@MssqlMcp/Node/src/index.ts#109-138, @README.md#118-128).
- **Key capabilities**:
  - Token acquisition (MSAL or equivalent) in the MCP server.
  - Environment-level config for AAD auth.
- **Score**: V=4, C=4, F=3, M=4 → **Overall Priority: Complete (already shipped)**

### 3.4. Deployment & Bastion Patterns

- **Description**: Opinionated docs + scripts for running the MCP server locally, containerized, or on bastion/jump hosts that can reach production SQL.
- **Why**: Reduces friction in adopting the server in enterprise networks; replaces the "RDP + SSMS" ritual with a documented MCP deployment.
- **Status**: 🚧 Partially documented – README covers local install/build flow and MCP client config, but lacks prescriptive deployment topologies, firewall/identity callouts, or bastion examples (@README.md#43-147).
- **Key capabilities**:
  - Reference architectures: local (VPN), container, jump host, managed service.
  - Security guidance (ports, SSL, credential scope, service accounts).
  - Optional scripts/manifests (e.g., systemd unit, container compose).
- **Score**: V=4, C=2, F=5, M=5 → **Overall Priority: P1**

---

## 4. Observability, Audit, and Compliance

### 4.1. Enhanced Audit Logging & Redaction

- **Description**: More structured, configurable logging of all DB interactions with field redaction.
- **Why**: Compliance (HIPAA, SOC 2, etc.) plus easier incident reviews.
- **Status**: ⛔ Not started – beyond console logging, there is no structured log format, masking, or external sink support today.
- **Key capabilities**:
  - Structured log format (JSON) with fields: user, environment, tool, SQL, duration, row count.
  - Configurable masking for sensitive columns/parameters (PHI/PII).
  - Pluggable sinks (file, stdout, HTTP endpoint, cloud log services).
- **Score**: V=4, C=4, F=4, M=5 → **Overall Priority: P2**

### 4.2. Session / Change History Views

- **Description**: Tools to query recent actions by user/environment (e.g., “what did we run for this client last week?”).
- **Why**: Drastically improves post-incident analysis and knowledge transfer.
- **Status**: ⛔ Not started – requires the audit log foundation plus dedicated MCP tools; neither exist yet.
- **Key capabilities**:
  - MCP tools to query the audit log storage.
  - Filters by environment, user, time range, and tool.
- **Score**: V=4, C=3, F=4, M=4 → **Overall Priority: P2–P3**

---

## 5. Schema & Metadata Intelligence

### 5.1. Schema Discovery & Search Tools

- **Description**: Tools to explore databases: list tables, columns, FKs, indexes; search by name pattern.
- **Why**: Crucial in large, multi-tenant or legacy schemas where nobody remembers the exact table/column names.
- **Status**: ✅ Implemented – `list_table`, `search_schema`, `describe_table`, `profile_table`, and `inspect_relationships` already cover structured discovery with pagination, fuzzy matches, and profiling (@README.md#24-41, @MssqlMcp/Node/src/tools/ListTableTool.ts#4-44, @MssqlMcp/Node/src/tools/SearchSchemaTool.ts#1-300, @MssqlMcp/Node/src/tools/ProfileTableTool.ts#1-400, @MssqlMcp/Node/src/tools/RelationshipInspectorTool.ts#1-214).
- **Key capabilities**:
  - `list_tables`, `list_columns(table)`, `search_tables(pattern)`, `search_columns(pattern)`.
  - Include schema, data types, nullable flags.
- **Score**: V=4, C=3, F=5, M=5 → **Overall Priority: Complete (already shipped)**

### 5.2. Dependency / Reference Tools

- **Description**: Find where a table/column is referenced (FKs, views, procedures).
- **Why**: Helps assess impact of changes and understand data flow.
- **Status**: 🚧 Partially implemented – `inspect_relationships` returns inbound/outbound FK mappings but does not yet scan views/procs for references (@MssqlMcp/Node/src/tools/RelationshipInspectorTool.ts#1-214).
- **Key capabilities**:
  - `find_references(object_name)` querying system catalogs.
  - Optionally parse view/proc definitions.
- **Score**: V=4, C=4, F=4, M=4 → **Overall Priority: P2**

### 5.3. Schema Drift & Version Awareness

- **Description**: Compare live schema to an expected model (e.g., from migrations) and report differences.
- **Why**: Detects drift across many client DBs; essential for consistent behavior.
- **Status**: ⛔ Not started – no schema snapshot tooling or migration metadata integration exists.
- **Key capabilities**:
  - Configurable expected schema snapshot or migration metadata.
  - Tools like `check_schema_drift(environment)`.
- **Score**: V=3, C=4, F=3, M=4 → **Overall Priority: P3**

---

## 6. Multi-Tenant & Client-Centric Features

### 6.1. Per-Client Scoping & Safety

- **Description**: Encode tenant/client concepts into tools so queries are always scoped to the right customer.
- **Why**: Reduces risk of leaking or modifying data across clients; matches real-world workflows ("fix data for Client X").
- **Status**: ⛔ Not started – environments are single-target and tools accept arbitrary SQL without tenant scoping helpers.
- **Key capabilities**:
  - Environment profiles that bind to a specific client DB or schema.
  - Tools that require a `client_id` and automatically add appropriate filters.
- **Score**: V=4, C=4, F=4, M=4 → **Overall Priority: P2**

### 6.2. Per-Client / Per-Environment Policy Controls

- **Description**: Policy layer that determines which tools and operations are allowed per environment/client.
- **Why**: Some clients/environments may prohibit certain actions (bulk export, arbitrary updates).
- **Status**: ✅ Implemented – Environment configs now accept `readonly`, `allowedTools`, and `maxRowsDefault`, with centralized enforcement inside `wrapToolRun` (@MssqlMcp/Node/src/config/EnvironmentManager.ts, @MssqlMcp/Node/src/index.ts#391-762). Mutating tools are blocked in read-only envs, and disallowed tools are rejected before execution.
- **Key capabilities**:
  - ✅ Configurable policy per environment: read-only vs read-write, allowed tool list, row-limit overrides.
  - ✅ Central enforcement so individual tools don’t duplicate checks.
- **Score**: V=4, C=4, F=3, M=4 → **Overall Priority: P2–P3**

---

## 7. Developer Experience & Operations

### 7.1. Configuration Validation & Health Checks

- **Description**: Tools for verifying that environments are configured correctly and reachable.
- **Why**: Faster setup/onboarding; avoids confusing runtime errors. High leverage when juggling many client databases because you can validate reachability before running real queries.
- **Status**: 🚧 Partially implemented – `test_connection` verifies connectivity, latency, and server metadata per environment (@MssqlMcp/Node/src/tools/TestConnectionTool.ts, @MssqlMcp/Node/src/index.ts#542-576). Still missing: broader config validation and automated diagnostics.
- **Key capabilities**:
  - ⛔ `validate_environment_config` tool.
  - ✅ `test_connection(environment)` that runs a simple query and returns latency + status.
- **Score**: V=4, C=3, F=5, M=5 → **Overall Priority: P1**

### 7.2. Example Workflows / Playbooks

- **Description**: Documented workflows (or scripts) showing how to perform common DBA/support tasks via MCP instead of SSMS/RDP.
- **Why**: Helps teams migrate real work from RDP+SSMS to this stack.
- **Status**: ⛔ Not started – README lists capabilities but does not walk through end-to-end support scenarios or repeatable playbooks.
- **Key capabilities**:
  - Step-by-step examples (e.g., "investigate a patient record", "fix bad claim codes").
  - Potentially paired with named scripts and safe-update tools.
- **Score**: V=3, C=2, F=5, M=4 → **Overall Priority: P2–P3**

---

## 8. Suggested Implementation Order (High-Level)

1. **P0 – Foundation (highest leverage gaps)**
   - Environment/connection profiles (⛔) – unlocks multi-environment workflows without multiple MCP processes.
   - Guardrailed read-only tooling enhancements (🚧) – add automatic row limits + environment-aware defaults around the existing `read_data` tool.
   - Secrets/credential plumbing (🚧) – document best practices now, add secret-store hooks next.
   - Basic audit logging (⛔) – persistent per-command log is required before scaling usage.

2. **P1 – Safety & Operations Enablement**
   - Safe-update guardrails (🚧) – add preview + transaction control to `update_data`.
   - Named/template scripts (⛔) – reduce bespoke SQL for repeated fixes.
   - Deployment & bastion patterns (🚧) – finish the doc set/systemd examples so teams can adopt without guesswork.
   - Configuration validation & `test_connection` (⛔) – quick reachability checks before running expensive queries.

3. **P2 – Advanced Enterprise Controls**
   - Dry-run/plan-only execution (⛔).
   - Enhanced/structured audit logging + redaction (⛔).
   - Dependency/reference tooling beyond FK introspection (🚧).
   - Per-client scoping + policy controls (⛔).
   - Example workflows/playbooks to codify complex operations (⛔).

4. **P3 – Longer-Term & Analytics**
   - Schema drift/version awareness (⛔).
   - Session/change-history explorers built atop structured logs (⛔).
   - Deeper multi-tenant policy automation (⛔).

This file is intended as a living document; as the MCP server evolves and real users adopt it, revisit the scores and priorities based on feedback, incident reports, and where teams actually spend their time.
