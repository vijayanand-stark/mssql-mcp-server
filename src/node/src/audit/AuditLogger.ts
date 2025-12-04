import * as fs from "fs";
import * as path from "path";

export interface AuditLogEntry {
  timestamp: string;
  toolName: string;
  arguments?: Record<string, any>;
  result?: {
    success: boolean;
    recordCount?: number;
    error?: string;
  };
  durationMs?: number;
  sessionId?: string;
  userId?: string;
}

export class AuditLogger {
  private readonly logFilePath: string;
  private readonly enabled: boolean;
  private readonly redactSensitiveData: boolean;

  constructor() {
    // Read config from env vars
    const logPath = process.env.AUDIT_LOG_PATH;
    this.enabled = process.env.AUDIT_LOGGING !== "false"; // Enabled by default
    this.redactSensitiveData = process.env.AUDIT_REDACT_SENSITIVE !== "false"; // Redact by default

    if (this.enabled && logPath) {
      this.logFilePath = path.resolve(logPath);
      this.ensureLogDirectory();
    } else if (this.enabled) {
      // Default to logs/audit.jsonl in the project root
      this.logFilePath = path.resolve(process.cwd(), "logs", "audit.jsonl");
      this.ensureLogDirectory();
    } else {
      this.logFilePath = "";
    }
  }

  private ensureLogDirectory() {
    if (!this.logFilePath) return;
    
    const dir = path.dirname(this.logFilePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  private redactArguments(args: Record<string, any>): Record<string, any> {
    if (!this.redactSensitiveData) {
      return args;
    }

    const redacted = { ...args };
    const sensitiveKeys = [
      "password",
      "secret",
      "token",
      "key",
      "authorization",
      "auth",
      "credential",
    ];

    for (const [key, value] of Object.entries(redacted)) {
      const lowerKey = key.toLowerCase();
      if (sensitiveKeys.some((sensitive) => lowerKey.includes(sensitive))) {
        redacted[key] = "[REDACTED]";
      } else if (typeof value === "string" && value.length > 500) {
        // Truncate very long strings (likely large query results)
        redacted[key] = value.substring(0, 500) + "... [TRUNCATED]";
      }
    }

    return redacted;
  }

  log(entry: AuditLogEntry): void {
    if (!this.enabled || !this.logFilePath) {
      return;
    }

    try {
      const logEntry = {
        ...entry,
        arguments: entry.arguments ? this.redactArguments(entry.arguments) : undefined,
      };

      const logLine = JSON.stringify(logEntry) + "\n";
      fs.appendFileSync(this.logFilePath, logLine, { encoding: "utf-8" });
    } catch (error) {
      console.error("Failed to write audit log:", error);
    }
  }

  logToolInvocation(
    toolName: string,
    args: any,
    result: any,
    durationMs: number,
    sessionId?: string,
    userId?: string
  ): void {
    const entry: AuditLogEntry = {
      timestamp: new Date().toISOString(),
      toolName,
      arguments: args || {},
      result: {
        success: result?.success ?? false,
        recordCount: result?.recordCount ?? result?.rowsAffected,
        error: result?.error,
      },
      durationMs: Math.round(durationMs),
      sessionId,
      userId,
    };

    this.log(entry);
  }
}

// Singleton instance
export const auditLogger = new AuditLogger();
