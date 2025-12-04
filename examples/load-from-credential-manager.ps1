# load-from-credential-manager.ps1
# Load SQL Server credentials from Windows Credential Manager
# Usage: . .\load-from-credential-manager.ps1
#
# Prerequisites:
# 1. Store your credentials in Windows Credential Manager first:
#    cmdkey /generic:MSSQL_PROD /user:myuser /pass:mypassword
#    cmdkey /generic:MSSQL_DEV /user:sa /pass:devpassword
#
# 2. Run this script to load them as environment variables:
#    . .\load-from-credential-manager.ps1
#
# 3. Start the MCP server - ${secret:*} placeholders will resolve

param(
    # Credential names to load (map credential name -> env var prefix)
    [hashtable]$CredentialMap = @{
        "MSSQL_PROD" = "PROD_SQL"
        "MSSQL_DEV"  = "DEV_SQL"
    }
)

# Function to retrieve credential from Windows Credential Manager
function Get-StoredCredential {
    param([string]$Target)

    try {
        # Use .NET CredentialManager via Add-Type
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CredentialManager {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool CredFree(IntPtr credential);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public long LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static string[] GetCredential(string target) {
        IntPtr credPtr;
        if (CredRead(target, 1, 0, out credPtr)) {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
            string password = Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2);
            string username = cred.UserName;
            CredFree(credPtr);
            return new string[] { username, password };
        }
        return null;
    }
}
"@ -ErrorAction SilentlyContinue

        $result = [CredentialManager]::GetCredential($Target)
        return $result
    }
    catch {
        Write-Warning "Failed to read credential '$Target': $_"
        return $null
    }
}

Write-Host "Loading credentials from Windows Credential Manager..."
Write-Host ""

foreach ($credName in $CredentialMap.Keys) {
    $envPrefix = $CredentialMap[$credName]

    $cred = Get-StoredCredential -Target $credName
    if ($cred) {
        $username = $cred[0]
        $password = $cred[1]

        # Set environment variables
        [Environment]::SetEnvironmentVariable("${envPrefix}_USERNAME", $username, "Process")
        [Environment]::SetEnvironmentVariable("${envPrefix}_PASSWORD", $password, "Process")

        Write-Host "  Loaded: $credName -> ${envPrefix}_USERNAME, ${envPrefix}_PASSWORD"
    }
    else {
        Write-Warning "  Credential not found: $credName"
        Write-Host "    To store: cmdkey /generic:$credName /user:USERNAME /pass:PASSWORD"
    }
}

Write-Host ""
Write-Host "Credentials loaded. You can now start the MCP server."
Write-Host ""
Write-Host "Your environments.json can reference these as:"
Write-Host '  "username": "${secret:PROD_SQL_USERNAME}"'
Write-Host '  "password": "${secret:PROD_SQL_PASSWORD}"'
