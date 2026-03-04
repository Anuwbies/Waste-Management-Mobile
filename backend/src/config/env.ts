import dotenv from "dotenv";

dotenv.config();

interface EnvironmentConfig {
  // Database
  MONGODB_URI: string;
  
  // Server
  PORT: number;
  NODE_ENV: string;
  
  // JWT
  JWT_SECRET: string;
  JWT_EXPIRES_IN: string;
  
  // CORS
  FRONTEND_URL: string;
  
  // File Upload
  MAX_FILE_SIZE: number;
  UPLOAD_PATH: string;
  
  // Logging
  LOG_LEVEL: string;
  
  // OpenRouter API
  OPENROUTER_API_KEY: string;
  OPENROUTER_MODEL: string;
  SITE_URL: string;
  SITE_NAME: string;
  
  // Email Configuration
  EMAIL_HOST?: string | undefined;
  EMAIL_PORT?: number;
  EMAIL_USER?: string | undefined;
  EMAIL_PASS?: string | undefined;
  EMAIL_FROM?: string;
  EMAIL_SECURE?: boolean;
  
  // Web Push Notifications
  WEB_PUSH_PUBLIC_KEY?: string | undefined;
  WEB_PUSH_PRIVATE_KEY?: string | undefined;
  WEB_PUSH_CONTACT?: string | undefined;
  
  // Security & Encryption
  ENCRYPTION_MASTER_KEY?: string | undefined;
  ENCRYPTION_KEY_ID?: string;
  REDIS_URL?: string;
  RATE_LIMIT_WINDOW_MS?: number;
  RATE_LIMIT_MAX_REQUESTS?: number;
}

// ---------------------------------------------------------------------------
// Validate critical env vars at startup (fail fast)
// ---------------------------------------------------------------------------
const required = ["JWT_SECRET", "MONGODB_URI"] as const;
for (const key of required) {
  if (!process.env[key]) {
    // eslint-disable-next-line no-console
    console.error(`❌  Missing required env var: ${key}`);
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// Optional env vars used by auth features (documented here for clarity):
//
//  GOOGLE_CLIENT_ID        – Primary Google OAuth client ID
//  GOOGLE_CLIENT_IDS       – Comma-separated list of additional audience IDs
//                            (Android / iOS / web)
//
//  SMTP_HOST               – SMTP server hostname
//  SMTP_PORT               – SMTP port (465 = TLS, 587 = STARTTLS)
//  SMTP_USER               – SMTP username
//  SMTP_PASS               – SMTP password
//  SMTP_FROM               – "From" address for outgoing mail
//
// If SMTP vars are missing the email service falls back to console logging
// (dev-only), so the forgot-password flow still works during development.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// AI / Classification Config
// ---------------------------------------------------------------------------

/**
 * Minimum CNN confidence (0..1) required to approve a reward.
 * Submissions below this threshold are denied — no blockchain tx, no points.
 * Override via CNN_CONFIDENCE_THRESHOLD env var.
 */
export const CNN_CONFIDENCE_THRESHOLD: number = parseFloat(
  process.env.CNN_CONFIDENCE_THRESHOLD ?? "0.80"
);


class Environment {
  private config: EnvironmentConfig;

  constructor() {
    this.config = this.validateAndLoadConfig();
  }

  private validateAndLoadConfig(): EnvironmentConfig {
    const requiredVars = [
      'MONGODB_URI',
      'JWT_SECRET'
    ];

    // Check for required environment variables
    const missingVars = requiredVars.filter(varName => !process.env[varName]);
    
    if (missingVars.length > 0) {
      const error = `Missing required environment variables: ${missingVars.join(', ')}`;
      // Use logger instead of console.error for better security
      throw new Error(error);
    }

    // Validate JWT secret strength
    const jwtSecret = process.env.JWT_SECRET;
    if (jwtSecret && jwtSecret.length < 32) {
      throw new Error('JWT_SECRET must be at least 32 characters long for security');
    }

    // Validate and parse environment variables
    try {
      return {
        // Database
        MONGODB_URI: this.getString('MONGODB_URI'),
        
        // Server
        PORT: this.getNumber('PORT', 5000),
        NODE_ENV: this.getString('NODE_ENV', 'development'),
        
        // JWT
        JWT_SECRET: this.getString('JWT_SECRET'),
        JWT_EXPIRES_IN: this.getString('JWT_EXPIRES_IN', '24h'),
        
        // CORS
        FRONTEND_URL: this.getString('FRONTEND_URL', 'http://localhost:3000'),
        
        // File Upload
        MAX_FILE_SIZE: this.getNumber('MAX_FILE_SIZE', 52428800), // 50MB in bytes
        UPLOAD_PATH: this.getString('UPLOAD_PATH', './uploads'),
        
        // Logging
        LOG_LEVEL: this.getString('LOG_LEVEL', 'info'),
        
        // OpenRouter API
        OPENROUTER_API_KEY: this.getString('OPENROUTER_API_KEY'),
        OPENROUTER_MODEL: this.getString('OPENROUTER_MODEL', 'x-ai/grok-4-fast:free'),
        SITE_URL: this.getString('SITE_URL', 'http://localhost:3000'),
        SITE_NAME: this.getString('SITE_NAME', 'RecyClean'),
        
        // Email Configuration (Optional)
        EMAIL_HOST: this.getOptionalString('EMAIL_HOST'),
        EMAIL_PORT: this.getNumber('EMAIL_PORT', 587),
        EMAIL_USER: this.getOptionalString('EMAIL_USER'),
        EMAIL_PASS: this.getOptionalString('EMAIL_PASS'),
        EMAIL_FROM: this.getString('EMAIL_FROM', 'RecyClean <noreply@recyclean.com>'),
        EMAIL_SECURE: this.getBoolean('EMAIL_SECURE', false),
        
        // Web Push Notifications (Optional)
        WEB_PUSH_PUBLIC_KEY: this.getOptionalString('WEB_PUSH_PUBLIC_KEY'),
        WEB_PUSH_PRIVATE_KEY: this.getOptionalString('WEB_PUSH_PRIVATE_KEY'),
        WEB_PUSH_CONTACT: this.getOptionalString('WEB_PUSH_CONTACT'),
        
        // Security & Encryption (Optional)
        ENCRYPTION_MASTER_KEY: this.getOptionalString('ENCRYPTION_MASTER_KEY'),
        ENCRYPTION_KEY_ID: this.getString('ENCRYPTION_KEY_ID', 'default'),
        REDIS_URL: this.getString('REDIS_URL', 'redis://localhost:6379'),
        RATE_LIMIT_WINDOW_MS: this.getNumber('RATE_LIMIT_WINDOW_MS', 900000), // 15 minutes
        RATE_LIMIT_MAX_REQUESTS: this.getNumber('RATE_LIMIT_MAX_REQUESTS', 100),
      };
    } catch (error) {
      // Log error through proper logging system instead of console
      throw error;
    }
  }

  private getString(key: string, defaultValue?: string): string {
    const value = process.env[key];
    if (value === undefined) {
      if (defaultValue !== undefined) {
        return defaultValue;
      }
      throw new Error(`Environment variable ${key} is required`);
    }
    return value;
  }

  private getOptionalString(key: string, defaultValue?: string): string | undefined {
    const value = process.env[key];
    if (value === undefined) {
      return defaultValue;
    }
    return value;
  }

  private getNumber(key: string, defaultValue?: number): number {
    const value = process.env[key];
    if (value === undefined) {
      if (defaultValue !== undefined) {
        return defaultValue;
      }
      throw new Error(`Environment variable ${key} is required`);
    }
    
    const numValue = parseInt(value, 10);
    if (isNaN(numValue)) {
      throw new Error(`Environment variable ${key} must be a valid number`);
    }
    return numValue;
  }

  private getBoolean(key: string, defaultValue?: boolean): boolean {
    const value = process.env[key];
    if (value === undefined) {
      if (defaultValue !== undefined) {
        return defaultValue;
      }
      throw new Error(`Environment variable ${key} is required`);
    }
    
    return value.toLowerCase() === 'true';
  }

  // Getter methods for accessing configuration
  get database() {
    return {
      uri: this.config.MONGODB_URI,
    };
  }

  get server() {
    return {
      port: this.config.PORT,
      nodeEnv: this.config.NODE_ENV,
      isProduction: this.config.NODE_ENV === 'production',
      isDevelopment: this.config.NODE_ENV === 'development',
      isTest: this.config.NODE_ENV === 'test',
    };
  }

  get jwt() {
    return {
      secret: this.config.JWT_SECRET,
      expiresIn: this.config.JWT_EXPIRES_IN,
    };
  }

  get cors() {
    return {
      frontendUrl: this.config.FRONTEND_URL,
    };
  }

  get fileUpload() {
    return {
      maxSize: this.config.MAX_FILE_SIZE,
      uploadPath: this.config.UPLOAD_PATH,
    };
  }

  get logging() {
    return {
      level: this.config.LOG_LEVEL,
    };
  }

  get openRouter() {
    return {
      apiKey: this.config.OPENROUTER_API_KEY,
      model: this.config.OPENROUTER_MODEL,
      siteUrl: this.config.SITE_URL,
      siteName: this.config.SITE_NAME,
    };
  }

  get email() {
    return {
      host: this.config.EMAIL_HOST,
      port: this.config.EMAIL_PORT,
      user: this.config.EMAIL_USER,
      pass: this.config.EMAIL_PASS,
      from: this.config.EMAIL_FROM,
      secure: this.config.EMAIL_SECURE,
    };
  }

  get webPush() {
    return {
      publicKey: this.config.WEB_PUSH_PUBLIC_KEY,
      privateKey: this.config.WEB_PUSH_PRIVATE_KEY,
      contact: this.config.WEB_PUSH_CONTACT,
    };
  }

  get security() {
    return {
      encryptionMasterKey: this.config.ENCRYPTION_MASTER_KEY,
      encryptionKeyId: this.config.ENCRYPTION_KEY_ID,
      redisUrl: this.config.REDIS_URL,
      rateLimitWindowMs: this.config.RATE_LIMIT_WINDOW_MS,
      rateLimitMaxRequests: this.config.RATE_LIMIT_MAX_REQUESTS,
    };
  }

  get encryption() {
    return {
      masterKey: this.config.ENCRYPTION_MASTER_KEY,
      currentKeyId: this.config.ENCRYPTION_KEY_ID,
    };
  }

  // Method to get all config (for debugging - be careful not to log sensitive data)
  getConfig(includeSensitive: boolean = false): Partial<EnvironmentConfig> {
    const config = { ...this.config };
    
    if (!includeSensitive) {
      // Remove sensitive data
      delete (config as any).JWT_SECRET;
      delete (config as any).OPENROUTER_API_KEY;
      delete (config as any).MONGODB_URI;
      delete (config as any).EMAIL_PASS;
      delete (config as any).WEB_PUSH_PRIVATE_KEY;
    }
    
    return config;
  }
}

// Create singleton instance
export const env = new Environment();
export default env;