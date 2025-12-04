#!/bin/bash
# load-env.sh
# Load environment variables from a .env file for the MSSQL MCP Server
# Usage: source ./load-env.sh [path-to-env-file]
#
# This script loads key=value pairs from a .env file into the current
# shell session's environment variables.

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Warning: Environment file not found: $ENV_FILE"
    echo ""
    echo "Create a .env file with your credentials:"
    echo ""
    echo "  # .env example"
    echo "  PROD_SQL_USERNAME=myuser"
    echo "  PROD_SQL_PASSWORD=mypassword"
    echo "  DEV_SQL_PASSWORD=devpassword"
    echo ""
    exit 1
fi

echo "Loading environment from: $ENV_FILE"

# Read .env file and export variables
while IFS= read -r line || [ -n "$line" ]; do
    # Trim whitespace
    line=$(echo "$line" | xargs)

    # Skip empty lines and comments
    if [ -z "$line" ] || [[ "$line" == \#* ]]; then
        continue
    fi

    # Parse key=value pairs
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        # Trim key
        key=$(echo "$key" | xargs)

        # Remove surrounding quotes from value if present
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi

        # Export the variable
        export "$key=$value"
        echo "  Set: $key"
    fi
done < "$ENV_FILE"

echo ""
echo "Environment loaded. You can now start the MCP server."
echo "Example: npx @connorbritain/mssql-mcp-server"


# macOS Keychain example (optional helper function)
# Uncomment to enable loading secrets from Keychain
#
# load_from_keychain() {
#     local service="$1"
#     local account="$2"
#     security find-generic-password -s "$service" -a "$account" -w 2>/dev/null
# }
#
# Example usage:
# export PROD_SQL_PASSWORD=$(load_from_keychain "mssql-mcp" "prod-password")
