/* ──────────────────────────────────────────
   Audit Trail – Type Definitions
   ────────────────────────────────────────── */

export type ActivityType =
  | 'scan'
  | 'reward'
  | 'redeem'
  | 'wallet_create'
  | 'wallet_topup'
  | 'wallet_withdraw'
  | 'login'
  | 'register';

export type AuditStatus = 'approved' | 'denied' | 'pending' | 'error';

export type WasteType =
  | 'plastic'
  | 'paper'
  | 'glass'
  | 'metal'
  | 'organic'
  | 'e-waste'
  | 'textile'
  | 'unknown';

/** Single audit log entry (list view) */
export interface AuditLog {
  id: string;
  timestamp: string;
  userEmail: string;
  userId: string;
  activityType: ActivityType;
  status: AuditStatus;
  wasteType?: WasteType;
  confidence?: number;
  points?: number;
  txHash?: string;
}

/** Full audit detail (detail view) */
export interface AuditDetail extends AuditLog {
  user: {
    id: string;
    email: string;
    name: string;
    walletAddress?: string;
  };
  aiClassification?: {
    wasteType: WasteType;
    confidence: number;
    modelVersion: string;
    imageHash?: string;
    rawPredictions?: Record<string, number>;
  };
  reward?: {
    points: number;
    calculation: string;
    bonusApplied: boolean;
  };
  blockchain?: {
    txHash: string;
    blockNumber: number;
    chainId: number;
    contractAddress: string;
    gasUsed: string;
    status: 'success' | 'failed' | 'pending';
  };
  eventHash?: string;
  imageHash?: string;
  adminNotes?: string;
  metadata?: Record<string, unknown>;
}

/** Query filters for the audit list */
export interface AuditFilters {
  page?: number;
  limit?: number;
  startDate?: string;
  endDate?: string;
  status?: AuditStatus | '';
  activityType?: ActivityType | '';
  wasteType?: WasteType | '';
  search?: string;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

/** Paginated response wrapper */
export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

/** Dashboard stats */
export interface DashboardStats {
  totalUsers: number;
  totalScansToday: number;
  approvedScans: number;
  deniedScans: number;
  totalPointsMinted: number;
  blockchain: {
    chainId: number;
    contractAddress: string;
    status: 'connected' | 'disconnected';
  };
  aiService: {
    status: 'online' | 'offline';
    modelVersion?: string;
  };
}

/** Archive record */
export interface Archive {
  id: string;
  createdAt: string;
  startDate: string;
  endDate: string;
  recordCount: number;
  fileSize: number;
  status: 'ready' | 'processing' | 'error';
  downloadUrl?: string;
}

/** Export request */
export interface ExportRequest {
  format: 'csv' | 'json';
  filters: AuditFilters;
}

/** Auth */
export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'superadmin';
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  user: AdminUser;
}
