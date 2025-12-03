import * as fs from "fs";
import * as path from "path";
import { InteractiveBrowserCredential } from "@azure/identity";
import sql from "mssql";

export interface EnvironmentConfig {
  name: string;
  server: string;
  database: string;
  port?: number;
  authMode: "sql" | "windows" | "aad";
  username?: string;
  password?: string;
  domain?: string;
  trustServerCertificate?: boolean;
  connectionTimeout?: number;
  readonly?: boolean;
  allowedTools?: string[];
  maxRowsDefault?: number;
  description?: string;
}

export interface EnvironmentsConfig {
  defaultEnvironment?: string;
  environments: EnvironmentConfig[];
}

export class EnvironmentManager {
  private readonly environments: Map<string, EnvironmentConfig>;
  private defaultEnvironment?: string;
  private readonly connections: Map<string, { pool: sql.ConnectionPool; expiresOn?: Date }>;

  constructor(configPath?: string) {
    this.environments = new Map();
    this.connections = new Map();

    // Try to load from config file first
    if (configPath) {
      this.loadFromFile(configPath);
    } else {
      // Fall back to environment variables for single environment
      this.loadFromEnvVars();
    }
  }

  private loadFromFile(configPath: string): void {
    try {
      const resolvedPath = path.resolve(configPath);
      if (!fs.existsSync(resolvedPath)) {
        console.warn(`Environment config file not found at ${resolvedPath}, falling back to env vars`);
        this.loadFromEnvVars();
        return;
      }

      const configContent = fs.readFileSync(resolvedPath, "utf-8");
      const config: EnvironmentsConfig = JSON.parse(configContent);

      this.defaultEnvironment = config.defaultEnvironment;

      for (const env of config.environments) {
        this.environments.set(env.name, env);
      }

      console.log(`Loaded ${this.environments.size} environment(s) from ${resolvedPath}`);
    } catch (error) {
      console.error(`Failed to load environment config: ${error}`);
      this.loadFromEnvVars();
    }
  }

  private loadFromEnvVars(): void {
    const server = process.env.SERVER_NAME;
    const database = process.env.DATABASE_NAME;

    if (!server || !database) {
      throw new Error(
        "No environment config file provided and SERVER_NAME/DATABASE_NAME env vars not set"
      );
    }

    const defaultEnv: EnvironmentConfig = {
      name: "default",
      server,
      database,
      port: process.env.SQL_PORT ? parseInt(process.env.SQL_PORT, 10) : undefined,
      authMode: (process.env.SQL_AUTH_MODE?.toLowerCase() as any) ?? "aad",
      username: process.env.SQL_USERNAME,
      password: process.env.SQL_PASSWORD,
      domain: process.env.SQL_DOMAIN,
      trustServerCertificate: process.env.TRUST_SERVER_CERTIFICATE?.toLowerCase() === "true",
      connectionTimeout: process.env.CONNECTION_TIMEOUT
        ? parseInt(process.env.CONNECTION_TIMEOUT, 10)
        : 30,
      readonly: process.env.READONLY === "true",
    };

    this.environments.set("default", defaultEnv);
    this.defaultEnvironment = "default";
    console.log("Loaded default environment from environment variables");
  }

  getEnvironment(name?: string): EnvironmentConfig {
    const targetName = name || this.defaultEnvironment || "default";
    const env = this.environments.get(targetName);

    if (!env) {
      throw new Error(
        `Environment '${targetName}' not found. Available: ${Array.from(this.environments.keys()).join(", ")}`
      );
    }

    return env;
  }

  listEnvironments(): EnvironmentConfig[] {
    return Array.from(this.environments.values());
  }

  async getConnection(environmentName?: string): Promise<sql.ConnectionPool> {
    const env = this.getEnvironment(environmentName);
    const cached = this.connections.get(env.name);

    // Check if we have a valid cached connection
    if (
      cached &&
      cached.pool.connected &&
      (!cached.expiresOn || cached.expiresOn > new Date(Date.now() + 2 * 60 * 1000))
    ) {
      return cached.pool;
    }

    // Create new connection
    const { config, expiresOn } = await this.createSqlConfig(env);

    // Close old connection if exists
    if (cached?.pool && cached.pool.connected) {
      await cached.pool.close();
    }

    const pool = await sql.connect(config);
    this.connections.set(env.name, { pool, expiresOn });

    return pool;
  }

  private async createSqlConfig(
    env: EnvironmentConfig
  ): Promise<{ config: sql.config; expiresOn?: Date }> {
    const baseConfig = {
      server: env.server,
      database: env.database,
      port: env.port,
      connectionTimeout: (env.connectionTimeout || 30) * 1000,
    };

    if (env.authMode === "sql") {
      if (!env.username || !env.password) {
        throw new Error(`Environment '${env.name}' requires username and password for SQL auth`);
      }

      return {
        config: {
          ...baseConfig,
          user: env.username,
          password: env.password,
          options: {
            encrypt: false,
            trustServerCertificate: env.trustServerCertificate ?? false,
          },
        },
      };
    }

    if (env.authMode === "windows") {
      if (!env.username || !env.password) {
        throw new Error(
          `Environment '${env.name}' requires username and password for Windows auth`
        );
      }

      return {
        config: {
          ...baseConfig,
          options: {
            encrypt: false,
            trustServerCertificate: env.trustServerCertificate ?? false,
          },
          authentication: {
            type: "ntlm",
            options: {
              userName: env.username,
              password: env.password,
              domain: env.domain || "",
            },
          },
        },
      };
    }

    // Azure AD auth
    const credential = new InteractiveBrowserCredential({
      redirectUri: "http://localhost",
    });
    const accessToken = await credential.getToken("https://database.windows.net/.default");

    if (!accessToken?.token) {
      throw new Error(`Failed to acquire Azure AD token for environment '${env.name}'`);
    }

    return {
      config: {
        ...baseConfig,
        options: {
          encrypt: true,
          trustServerCertificate: env.trustServerCertificate ?? false,
        },
        authentication: {
          type: "azure-active-directory-access-token",
          options: {
            token: accessToken.token,
          },
        },
      },
      expiresOn: accessToken?.expiresOnTimestamp
        ? new Date(accessToken.expiresOnTimestamp)
        : new Date(Date.now() + 30 * 60 * 1000),
    };
  }

  async closeAll(): Promise<void> {
    for (const [name, { pool }] of this.connections.entries()) {
      if (pool.connected) {
        await pool.close();
        console.log(`Closed connection for environment '${name}'`);
      }
    }
    this.connections.clear();
  }
}

// Singleton instance
let environmentManager: EnvironmentManager;

export function getEnvironmentManager(): EnvironmentManager {
  if (!environmentManager) {
    const configPath = process.env.ENVIRONMENTS_CONFIG_PATH;
    environmentManager = new EnvironmentManager(configPath);
  }
  return environmentManager;
}
