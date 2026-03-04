/**
 * Comprehensive error types and classes for robust error handling
 */

export enum ErrorType {
  // Authentication & Authorization
  AUTHENTICATION_REQUIRED = 'AUTHENTICATION_REQUIRED',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  TOKEN_INVALID = 'TOKEN_INVALID',
  INSUFFICIENT_PERMISSIONS = 'INSUFFICIENT_PERMISSIONS',
  ACCOUNT_DEACTIVATED = 'ACCOUNT_DEACTIVATED',
  EMAIL_NOT_VERIFIED = 'EMAIL_NOT_VERIFIED',

  // Validation Errors
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  INVALID_INPUT = 'INVALID_INPUT',
  MISSING_REQUIRED_FIELD = 'MISSING_REQUIRED_FIELD',
  INVALID_FORMAT = 'INVALID_FORMAT',
  FILE_TOO_LARGE = 'FILE_TOO_LARGE',
  INVALID_FILE_TYPE = 'INVALID_FILE_TYPE',

  // Database Errors
  DATABASE_CONNECTION_ERROR = 'DATABASE_CONNECTION_ERROR',
  DATABASE_QUERY_ERROR = 'DATABASE_QUERY_ERROR',
  RECORD_NOT_FOUND = 'RECORD_NOT_FOUND',
  DUPLICATE_RECORD = 'DUPLICATE_RECORD',
  CONSTRAINT_VIOLATION = 'CONSTRAINT_VIOLATION',

  // External Service Errors
  EXTERNAL_SERVICE_ERROR = 'EXTERNAL_SERVICE_ERROR',
  API_RATE_LIMIT = 'API_RATE_LIMIT',
  API_TIMEOUT = 'API_TIMEOUT',
  SERVICE_UNAVAILABLE = 'SERVICE_UNAVAILABLE',
  NETWORK_ERROR = 'NETWORK_ERROR',

  // Business Logic Errors
  BUSINESS_RULE_VIOLATION = 'BUSINESS_RULE_VIOLATION',
  OPERATION_NOT_ALLOWED = 'OPERATION_NOT_ALLOWED',
  RESOURCE_CONFLICT = 'RESOURCE_CONFLICT',
  QUOTA_EXCEEDED = 'QUOTA_EXCEEDED',

  // System Errors
  INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR',
  CONFIGURATION_ERROR = 'CONFIGURATION_ERROR',
  DEPENDENCY_ERROR = 'DEPENDENCY_ERROR',
  CIRCUIT_BREAKER_OPEN = 'CIRCUIT_BREAKER_OPEN'
}

export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

export interface ErrorContext {
  userId?: string;
  requestId?: string;
  operation?: string;
  resource?: string;
  metadata?: Record<string, any>;
}

export interface ErrorDetails {
  type: ErrorType;
  severity: ErrorSeverity;
  context?: ErrorContext;
  retryable: boolean;
  userMessage: string;
  technicalMessage: string;
  suggestions?: string[];
  timestamp: Date;
}

/**
 * Base error class with enhanced features
 */
export class BaseError extends Error {
  public readonly type: ErrorType;
  public readonly severity: ErrorSeverity;
  public readonly context?: ErrorContext;
  public readonly retryable: boolean;
  public readonly userMessage: string;
  public readonly suggestions?: string[];
  public readonly timestamp: Date;
  public readonly isOperational: boolean = true;

  constructor(
    message: string,
    type: ErrorType,
    severity: ErrorSeverity = ErrorSeverity.MEDIUM,
    context?: ErrorContext,
    retryable: boolean = false,
    userMessage?: string,
    suggestions?: string[]
  ) {
    super(message);
    this.name = this.constructor.name;
    this.type = type;
    this.severity = severity;
    if (context) {
      this.context = context;
    }
    this.retryable = retryable;
    this.userMessage = userMessage || message;
    this.suggestions = suggestions || [];
    this.timestamp = new Date();

    Error.captureStackTrace(this, this.constructor);
  }

  toJSON(): ErrorDetails {
    return {
      type: this.type,
      severity: this.severity,
      ...(this.context && { context: this.context }),
      retryable: this.retryable,
      userMessage: this.userMessage,
      technicalMessage: this.message,
      suggestions: this.suggestions || [],
      timestamp: this.timestamp
    };
  }
}

/**
 * Authentication and Authorization Errors
 */
export class AuthenticationError extends BaseError {
  constructor(message: string, context?: ErrorContext) {
    super(
      message,
      ErrorType.AUTHENTICATION_REQUIRED,
      ErrorSeverity.HIGH,
      context,
      false,
      'Authentication required. Please log in to continue.',
      ['Please log in with valid credentials', 'Contact support if you continue to have issues']
    );
  }
}

export class InvalidCredentialsError extends BaseError {
  constructor(context?: ErrorContext) {
    super(
      'Invalid credentials provided',
      ErrorType.INVALID_CREDENTIALS,
      ErrorSeverity.MEDIUM,
      context,
      false,
      'Invalid email or password. Please check your credentials and try again.',
      ['Verify your email and password', 'Use the "Forgot Password" feature if needed']
    );
  }
}

export class TokenExpiredError extends BaseError {
  constructor(context?: ErrorContext) {
    super(
      'Token has expired',
      ErrorType.TOKEN_EXPIRED,
      ErrorSeverity.MEDIUM,
      context,
      false,
      'Your session has expired. Please log in again.',
      ['Please log in again', 'Enable "Remember Me" for longer sessions']
    );
  }
}

export class InsufficientPermissionsError extends BaseError {
  constructor(operation: string, context?: ErrorContext) {
    super(
      `Insufficient permissions for operation: ${operation}`,
      ErrorType.INSUFFICIENT_PERMISSIONS,
      ErrorSeverity.HIGH,
      context,
      false,
      'You do not have permission to perform this action.',
      ['Contact your administrator for access', 'Check if you have the required role']
    );
  }
}

/**
 * Validation Errors
 */
export class ValidationError extends BaseError {
  constructor(message: string, field?: string, context?: ErrorContext) {
    super(
      message,
      ErrorType.VALIDATION_ERROR,
      ErrorSeverity.MEDIUM,
      { ...context, resource: field || 'unknown' },
      false,
      `Invalid input: ${message}`,
      ['Check the input format', 'Refer to the API documentation for valid formats']
    );
  }
}

export class MissingRequiredFieldError extends BaseError {
  constructor(field: string, context?: ErrorContext) {
    super(
      `Required field '${field}' is missing`,
      ErrorType.MISSING_REQUIRED_FIELD,
      ErrorSeverity.MEDIUM,
      { ...context, resource: field },
      false,
      `The field '${field}' is required but was not provided.`,
      ['Include all required fields in your request', 'Check the API documentation']
    );
  }
}

export class FileTooLargeError extends BaseError {
  constructor(maxSize: string, context?: ErrorContext) {
    super(
      `File size exceeds maximum allowed size of ${maxSize}`,
      ErrorType.FILE_TOO_LARGE,
      ErrorSeverity.MEDIUM,
      context,
      false,
      `File is too large. Maximum size allowed is ${maxSize}.`,
      ['Compress the file', 'Split the file into smaller parts', 'Use a different file format']
    );
  }
}

/**
 * Database Errors
 */
export class DatabaseError extends BaseError {
  constructor(message: string, operation: string, context?: ErrorContext) {
    super(
      message,
      ErrorType.DATABASE_QUERY_ERROR,
      ErrorSeverity.HIGH,
      { ...context, operation },
      true,
      'A database error occurred. Please try again.',
      ['Try the operation again', 'Contact support if the issue persists']
    );
  }
}

export class RecordNotFoundError extends BaseError {
  constructor(resource: string, id: string, context?: ErrorContext) {
    super(
      `${resource} with ID '${id}' not found`,
      ErrorType.RECORD_NOT_FOUND,
      ErrorSeverity.MEDIUM,
      { ...context, resource, metadata: { id } },
      false,
      `The requested ${resource.toLowerCase()} was not found.`,
      ['Verify the ID is correct', 'Check if the resource exists', 'Contact support if needed']
    );
  }
}

export class DuplicateRecordError extends BaseError {
  constructor(resource: string, field: string, context?: ErrorContext) {
    super(
      `${resource} with ${field} already exists`,
      ErrorType.DUPLICATE_RECORD,
      ErrorSeverity.MEDIUM,
      { ...context, resource, metadata: { field } },
      false,
      `A ${resource.toLowerCase()} with this ${field} already exists.`,
      ['Use a different value', 'Update the existing record instead', 'Contact support if needed']
    );
  }
}

/**
 * External Service Errors
 */
export class ExternalServiceError extends BaseError {
  constructor(service: string, message: string, context?: ErrorContext) {
    super(
      `${service} service error: ${message}`,
      ErrorType.EXTERNAL_SERVICE_ERROR,
      ErrorSeverity.HIGH,
      { ...context, resource: service },
      true,
      'An external service is temporarily unavailable.',
      ['Try again in a few minutes', 'Contact support if the issue persists']
    );
  }
}

export class ApiRateLimitError extends BaseError {
  constructor(service: string, retryAfter?: number, context?: ErrorContext) {
    super(
      `Rate limit exceeded for ${service}`,
      ErrorType.API_RATE_LIMIT,
      ErrorSeverity.MEDIUM,
      { ...context, resource: service, metadata: { retryAfter } },
      true,
      'Too many requests. Please wait before trying again.',
      [`Wait ${retryAfter || 60} seconds before retrying`, 'Reduce request frequency']
    );
  }
}

export class ServiceUnavailableError extends BaseError {
  constructor(service: string, context?: ErrorContext) {
    super(
      `${service} service is unavailable`,
      ErrorType.SERVICE_UNAVAILABLE,
      ErrorSeverity.HIGH,
      { ...context, resource: service },
      true,
      'A required service is temporarily unavailable.',
      ['Try again later', 'Contact support if the issue persists']
    );
  }
}

/**
 * Business Logic Errors
 */
export class BusinessRuleViolationError extends BaseError {
  constructor(rule: string, context?: ErrorContext) {
    super(
      `Business rule violation: ${rule}`,
      ErrorType.BUSINESS_RULE_VIOLATION,
      ErrorSeverity.MEDIUM,
      context,
      false,
      'This action violates a business rule.',
      ['Check the requirements', 'Contact support for clarification']
    );
  }
}

export class OperationNotAllowedError extends BaseError {
  constructor(operation: string, reason: string, context?: ErrorContext) {
    super(
      `Operation '${operation}' not allowed: ${reason}`,
      ErrorType.OPERATION_NOT_ALLOWED,
      ErrorSeverity.MEDIUM,
      { ...context, operation },
      false,
      'This operation is not allowed in the current context.',
      ['Check the prerequisites', 'Contact support for assistance']
    );
  }
}

export class QuotaExceededError extends BaseError {
  constructor(resource: string, limit: number, context?: ErrorContext) {
    super(
      `Quota exceeded for ${resource}: ${limit}`,
      ErrorType.QUOTA_EXCEEDED,
      ErrorSeverity.MEDIUM,
      { ...context, resource, metadata: { limit } },
      false,
      `You have exceeded the limit for ${resource}.`,
      ['Upgrade your plan', 'Contact support for quota increase', 'Wait for quota reset']
    );
  }
}

/**
 * System Errors
 */
export class ConfigurationError extends BaseError {
  constructor(config: string, context?: ErrorContext) {
    super(
      `Configuration error: ${config}`,
      ErrorType.CONFIGURATION_ERROR,
      ErrorSeverity.CRITICAL,
      { ...context, resource: config },
      false,
      'A configuration error occurred.',
      ['Contact system administrator', 'Check system configuration']
    );
  }
}

export class CircuitBreakerOpenError extends BaseError {
  constructor(service: string, context?: ErrorContext) {
    super(
      `Circuit breaker open for ${service}`,
      ErrorType.CIRCUIT_BREAKER_OPEN,
      ErrorSeverity.HIGH,
      { ...context, resource: service },
      true,
      'Service is temporarily unavailable due to high error rate.',
      ['Try again later', 'Contact support if the issue persists']
    );
  }
}

/**
 * Error factory for creating appropriate error types
 */
export class ErrorFactory {
  static createValidationError(message: string, field?: string, context?: ErrorContext): ValidationError {
    return new ValidationError(message, field, context);
  }

  static createDatabaseError(message: string, operation: string, context?: ErrorContext): DatabaseError {
    return new DatabaseError(message, operation, context);
  }

  static createExternalServiceError(service: string, message: string, context?: ErrorContext): ExternalServiceError {
    return new ExternalServiceError(service, message, context);
  }

  static createRecordNotFoundError(resource: string, id: string, context?: ErrorContext): RecordNotFoundError {
    return new RecordNotFoundError(resource, id, context);
  }

  static createDuplicateRecordError(resource: string, field: string, context?: ErrorContext): DuplicateRecordError {
    return new DuplicateRecordError(resource, field, context);
  }

  static createBusinessRuleViolationError(rule: string, context?: ErrorContext): BusinessRuleViolationError {
    return new BusinessRuleViolationError(rule, context);
  }

  static createQuotaExceededError(resource: string, limit: number, context?: ErrorContext): QuotaExceededError {
    return new QuotaExceededError(resource, limit, context);
  }
}

/**
 * Error response interface for API responses
 */
export interface ErrorResponse {
  success: false;
  error: {
    type: ErrorType;
    message: string;
    userMessage: string;
    suggestions?: string[];
    retryable: boolean;
    timestamp: string;
    requestId?: string;
  };
  metadata?: {
    severity: ErrorSeverity;
    context?: ErrorContext;
  };
}
