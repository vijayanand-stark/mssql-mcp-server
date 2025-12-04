# GOVERNANCE ROADMAP

> **Internal planning document – not committed to repo**

This document outlines the strategic approach to credential security, tiered authority levels, and enterprise governance for the MSSQL MCP Server.

---

## 1. Credential Security Options

### Tier 1: Basic (Developer/Personal Use)
**Risk tolerance:** Low-stakes, local development

| Approach | Implementation | Pros | Cons |
|----------|----------------|------|------|
| **Inline env vars** | Hardcode in `mcp_config.json` | Simple, fast setup | Credentials in plaintext; risky if file is shared |
| **`.env` file** | External file loaded at startup | Separates secrets from config; gitignored | Still plaintext on disk |
| **Environment variables** | Set via shell before launching | No file storage | Must set every session; can leak via `env` command |

### Tier 2: Professional (Team/Corporate)
**Risk tolerance:** Moderate; shared machines, version control concerns

| Approach | Implementation | Pros | Cons |
|----------|----------------|------|------|
| **Windows Credential Manager** | `cmdkey` + PowerShell retrieval | Encrypted at rest; per-user | Windows-only; requires startup script |
| **macOS Keychain** | `security` CLI commands | Native encryption | macOS-only |
| **1Password / Bitwarden CLI** | Fetch secrets via CLI | Cross-platform, encrypted | Requires subscription; extra dependency |

### Tier 3: Enterprise (Regulated/Production)
**Risk tolerance:** Minimal; audit requirements, SOC2/HIPAA considerations

| Approach | Implementation | Pros | Cons |
|----------|----------------|------|------|
| **Azure Key Vault** | `az keyvault secret show` | Full audit trail, RBAC, rotation | Requires Azure subscription |
| **HashiCorp Vault** | Vault CLI or API | Self-hosted option, fine-grained policies | Operational overhead |
| **AWS Secrets Manager** | `aws secretsmanager get-secret-value` | Native AWS integration | AWS-only |
| **Doppler / Infisical** | CLI sync to env vars | Easy team sync, audit logs | SaaS dependency |

### Implementation Plan

**Phase 1 (v0.2.x):** Document all options in README with examples
- [ ] Add "Credential Security" section to README
- [ ] Create `examples/` folder with sample scripts:
  - `load-env.ps1` (PowerShell)
  - `load-env.sh` (Bash)
  - `load-from-keyvault.ps1`
  - `load-from-credential-manager.ps1`

**Phase 2 (v0.3.x):** Native secret provider support
- [ ] Add `SECRETS_PROVIDER` env var (`none`, `env`, `credman`, `keyvault`, `vault`)
- [ ] Implement pluggable secret resolver in `src/node/src/config/`
- [ ] Auto-resolve `${secret:NAME}` syntax in config values

**Phase 3 (v0.4.x):** Credential rotation & refresh
- [ ] Token refresh for Azure AD connections
- [ ] Secret TTL awareness (re-fetch from vault if expired)
- [ ] Graceful reconnection on credential change

---

## 2. Tiered Authority Builds

### The Problem

Current `READONLY=true` is runtime-only—the code for write operations still ships. An attacker or misconfigured client could potentially bypass the flag. Enterprises want **compile-time guarantees** that certain builds physically cannot perform destructive operations.

### Proposed Build Tiers

| Tier | npm Package | Tools Included | Use Case |
|------|-------------|----------------|----------|
| **Reader** | `@connorbritain/mssql-mcp-reader` | `read_data`, `describe_table`, `list_table`, `search_schema`, `profile_table`, `inspect_relationships`, `explain_query` | Analysts, auditors, read-only exploration |
| **Standard** | `@connorbritain/mssql-mcp-server` | All Reader tools + `insert_data`, `update_data`, `delete_data` (with preview/confirm) | Data engineers, ETL developers |
| **Admin** | `@connorbritain/mssql-mcp-admin` | All Standard tools + `create_table`, `create_index`, `drop_table` | DBAs, schema architects |

### Implementation Strategy

**Option A: Separate npm packages (publish-time separation)**

Pros:
- Hard separation at package level
- Can't accidentally install wrong tier
- Clear audit trail ("we only allow `mssql-mcp-reader` in prod")

Cons:
- Three packages to maintain
- Version sync complexity

**Option B: Single package with build flags (compile-time separation)**

```bash
# Build read-only version
npm run build:reader   # Outputs dist-reader/

# Build standard version
npm run build:standard # Outputs dist/

# Build admin version  
npm run build:admin    # Outputs dist-admin/
```

Pros:
- Single codebase
- Enterprises can build their own tier

Cons:
- Requires build step
- Trust that build was done correctly

**Option C: Runtime tier enforcement with code verification (hybrid)**

Package includes all code but:
1. `AUTHORITY_TIER` env var (`reader`, `standard`, `admin`)
2. Server validates tier at startup
3. Cryptographic signature of tool manifest
4. (Optional) Code attestation via SLSA/Sigstore

Pros:
- Single package
- Verifiable via signatures

Cons:
- More complex
- Runtime still has all code (just disabled)

### Recommended Approach: **Option A** (Separate packages)

For regulated environments, physical separation is the clearest governance model. Implement as:

```
src/node/
├── src/
│   ├── tools/
│   │   ├── read/           # Always included
│   │   │   ├── ReadDataTool.ts
│   │   │   ├── DescribeTableTool.ts
│   │   │   ├── ListTableTool.ts
│   │   │   ├── SearchSchemaTool.ts
│   │   │   ├── ProfileTableTool.ts
│   │   │   ├── InspectRelationshipsTool.ts
│   │   │   └── ExplainQueryTool.ts
│   │   ├── write/          # Standard tier
│   │   │   ├── InsertDataTool.ts
│   │   │   ├── UpdateDataTool.ts
│   │   │   └── DeleteDataTool.ts
│   │   └── admin/          # Admin tier
│   │       ├── CreateTableTool.ts
│   │       ├── CreateIndexTool.ts
│   │       └── DropTableTool.ts
│   ├── index.reader.ts     # Entry point: read tools only
│   ├── index.standard.ts   # Entry point: read + write tools
│   └── index.admin.ts      # Entry point: all tools
├── package.reader.json
├── package.standard.json
└── package.admin.json
```

Build script generates three separate packages from shared code:

```bash
npm run build:all
# Outputs:
#   dist/reader/    → publishes as @connorbritain/mssql-mcp-reader
#   dist/standard/  → publishes as @connorbritain/mssql-mcp-server
#   dist/admin/     → publishes as @connorbritain/mssql-mcp-admin
```

### Implementation Plan

**Phase 1 (v0.3.x):** Refactor tool organization
- [ ] Move tools into `read/`, `write/`, `admin/` subdirectories
- [ ] Create tier-specific entry points
- [ ] Test that reader build has no write imports

**Phase 2 (v0.4.x):** Multi-package publishing
- [ ] Create build script for tier separation
- [ ] Publish `mssql-mcp-reader` package
- [ ] Publish `mssql-mcp-admin` package
- [ ] Update MCP Registry with all three

**Phase 3 (v0.5.x):** Enterprise distribution
- [ ] Create signed releases for each tier
- [ ] Document enterprise deployment patterns
- [ ] Add SBOM (Software Bill of Materials) generation

---

## 3. Per-Environment Policy Controls

Beyond global `READONLY`, enterprises want per-environment restrictions:

```json
{
  "environments": [
    {
      "name": "prod",
      "server": "prod-server.database.windows.net",
      "readonly": true,
      "allowedTools": ["read_data", "describe_table", "search_schema"],
      "deniedSchemas": ["dbo.audit_*", "security.*"],
      "maxRowsReturned": 100,
      "requireApproval": true
    },
    {
      "name": "dev",
      "server": "localhost",
      "readonly": false,
      "allowedTools": "*",
      "maxRowsReturned": 10000
    }
  ]
}
```

### Policy Fields

| Field | Type | Description |
|-------|------|-------------|
| `readonly` | bool | Disable all write tools |
| `allowedTools` | string[] | Whitelist of permitted tools |
| `deniedTools` | string[] | Blacklist of blocked tools |
| `allowedSchemas` | string[] | Schema patterns user can access |
| `deniedSchemas` | string[] | Schema patterns to block (e.g., `audit_*`) |
| `maxRowsReturned` | int | Cap results regardless of query |
| `requireApproval` | bool | Force preview/confirm for ALL operations |
| `auditLevel` | string | `none`, `basic`, `verbose` |

### Implementation Plan

**Phase 1 (v0.3.x):**
- [ ] Add `allowedTools` / `deniedTools` to environment schema
- [ ] Enforce at tool registration time

**Phase 2 (v0.4.x):**
- [ ] Add schema-level access control
- [ ] Implement `maxRowsReturned` enforcement

**Phase 3 (v0.5.x):**
- [ ] Add `requireApproval` override
- [ ] Per-environment audit level configuration

---

## 4. Audit & Compliance

### Current State
- JSON Lines audit log (`logs/audit.jsonl`)
- Auto-redaction of sensitive parameters
- Timestamp, tool name, arguments, results

### Future Enhancements

**Phase 1:** Log enrichment
- [ ] Add session ID / correlation ID
- [ ] Include client info (MCP client name, version)
- [ ] Add environment name to every log entry

**Phase 2:** External log shipping
- [ ] Syslog support
- [ ] Azure Monitor / Application Insights integration
- [ ] Splunk / Datadog webhook

**Phase 3:** Compliance reporting
- [ ] Generate audit reports (JSON → PDF)
- [ ] Query history dashboard
- [ ] Anomaly detection (unusual query patterns)

---

## 5. Distribution & Deployment Patterns

### Pattern A: npm install (public)
```bash
npm install -g @connorbritain/mssql-mcp-reader@latest
```
Best for: Individual developers, small teams

### Pattern B: Private npm registry (enterprise)
```bash
npm install -g @mycompany/mssql-mcp-reader --registry https://npm.mycompany.com
```
Best for: Enterprises with internal package management

### Pattern C: Container image (air-gapped)
```bash
docker run -e SERVER_NAME=... mycompany/mssql-mcp-reader:v0.3.0
```
Best for: Air-gapped environments, Kubernetes deployments

### Pattern D: Signed binary (high-security)
```bash
# Verify signature before running
gpg --verify mssql-mcp-reader.sig mssql-mcp-reader
./mssql-mcp-reader
```
Best for: Regulated industries requiring code signing

---

## 6. Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| Credential security docs | High | Low | **P0 - Next release** |
| Tiered tool builds | High | Medium | **P1 - v0.3.x** |
| Per-environment policies | High | Medium | **P1 - v0.3.x** |
| Secret provider plugins | Medium | Medium | P2 - v0.4.x |
| Signed releases | Medium | Low | P2 - v0.4.x |
| External log shipping | Medium | Medium | P3 - v0.5.x |
| Container distribution | Low | Low | P3 - v0.5.x |

---

## 7. Next Actions

1. **Immediate (this week):**
   - [ ] Add credential security section to README
   - [ ] Create `examples/` folder with loader scripts

2. **Short-term (v0.3.x):**
   - [ ] Refactor tools into tier directories
   - [ ] Create reader-only build
   - [ ] Publish `@connorbritain/mssql-mcp-reader`

3. **Medium-term (v0.4.x):**
   - [ ] Implement `SECRETS_PROVIDER` system
   - [ ] Add per-environment `allowedTools` enforcement
   - [ ] Create signed release workflow

---

*Last updated: December 3, 2025*
