> ⚠️ **EXPERIMENTAL USE ONLY** - This .NET implementation is provided as an example for educational and experimental purposes. The Node.js version is recommended for production use.

# MSSQL MCP Server (.NET 8)

This is the .NET 8 implementation of the MSSQL MCP server using the official [MCP C# SDK](https://github.com/modelcontextprotocol/csharp-sdk). For the production-ready Node.js version, see [../node](../node).

## Features

- Provide connection string via environment variable `CONNECTION_STRING`.
- **MCP Tools Implemented**:
  - ListTables: List all tables in the database.
  - DescribeTable: Get schema/details for a table.
  - CreateTable: Create new tables.
  - DropTable: Drop existing tables.
  - InsertData: Insert data into tables.
  - ReadData: Read/query data from tables.
  - UpdateData: Update values in tables.
- **Logging**: Console logging using Microsoft.Extensions.Logging.
- **Unit Tests**: xUnit-based unit tests for all major components.

## Getting Started

### Prerequisites

- .NET 8 SDK or runtime ([install instructions](https://dotnet.microsoft.com/download/dotnet/8.0))
- Access to a SQL Server or Azure SQL Database

### Setup

1. **Build**

```sh
cd src/dotnet/MssqlMcp
dotnet build
```


2. VSCode: **Start VSCode, and add MCP Server config to VSCode Settings**

Load the settings file in VSCode (Ctrl+Shift+P > Preferences: Open Settings (JSON)).

Add a new MCP Server with the following settings:

---
```json
    "MSSQL MCP": {
        "type": "stdio",
        "command": "C:\\src\\MssqlMcp\\MssqlMcp\\bin\\Debug\\net8.0\\MssqlMcp.exe",
        "env": {
            "CONNECTION_STRING": "Server=.;Database=test;Trusted_Connection=True;TrustServerCertificate=True"
            }
}
```
---

NOTE: Replace the path with the location of your mssql-mcp-server repo build output.

An example of using a connection string for Azure SQL Database:

```json
"mcp": {
    "servers": {
        "MSSQL MCP": {
            "type": "stdio",
            "command": "C:\\path\\to\\mssql-mcp-server\\src\\dotnet\\MssqlMcp\\bin\\Debug\\net8.0\\MssqlMcp.exe",
            "env": {
                "CONNECTION_STRING": "Server=tcp:<servername>.database.windows.net,1433;Initial Catalog=<databasename>;Encrypt=Mandatory;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Interactive"
            }
        }
    }
}
```

**Run the MCP Server**

Save the Settings file, and then you should see the "Start" button appear in the settings.json.  Click "Start" to start the MCP Server. (You can then click on "Running" to view the Output window).

Start Chat (Ctrl+Shift+I), make sure Agent Mode is selected.

Click the tools icon, and ensure the "MSSQL MCP" tools are selected.

Then type in the chat window "List tables in the database" and hit enter. (If you have other tools loaded, you may need to specify "MSSQL MCP" in the initial prompt, e.g. "Using MSSQL MCP, list tables").

3. **Claude Desktop / Windsurf: Add MCP Server config**

Add a new MCP Server with the following settings:

```json
{
    "mcpServers": {
        "mssql-dotnet": {
            "command": "C:\\path\\to\\mssql-mcp-server\\src\\dotnet\\MssqlMcp\\bin\\Debug\\net8.0\\MssqlMcp.exe",
            "env": {
                "CONNECTION_STRING": "Server=.;Database=test;Trusted_Connection=True;TrustServerCertificate=True"
            }
        }
    }
}
```

Save the file, restart your MCP client, and the MSSQL MCP tools will be available.

## Troubleshooting

1. If you get a "Task canceled" error using "Active Directory Default", try "Active Directory Interactive".
2. Ensure .NET 8 runtime is installed: `dotnet --version` should show 8.x

---

**Full documentation:** See the [main README](../../README.md) for complete feature list and configuration options.

**Repository:** https://github.com/ConnorBritain/mssql-mcp-server



