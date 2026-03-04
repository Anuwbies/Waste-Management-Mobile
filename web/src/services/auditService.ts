import api from './api';
import type {
  AuditLog,
  AuditDetail,
  AuditFilters,
  PaginatedResponse,
  DashboardStats,
  Archive,
  ExportRequest,
  LoginCredentials,
  AuthResponse,
} from '../types/audit';

/* ═══════════════  Auth  ═══════════════ */

export async function adminLogin(creds: LoginCredentials): Promise<AuthResponse> {
  const { data } = await api.post<AuthResponse>('/admin/login', creds);
  return data;
}

export async function adminLogout(): Promise<void> {
  try { await api.post('/admin/logout'); } catch { /* best-effort */ }
}

/* ═══════════════  Dashboard  ═══════════════ */

export async function fetchDashboard(): Promise<DashboardStats> {
  const { data } = await api.get<DashboardStats>('/admin/dashboard');
  return data;
}

/* ═══════════════  Audit Logs  ═══════════════ */

export async function fetchAuditLogs(
  filters: AuditFilters,
): Promise<PaginatedResponse<AuditLog>> {
  const baseParams = Object.fromEntries(
    Object.entries(filters).filter(([, v]) => v !== '' && v !== undefined),
  ) as Record<string, unknown>;

  if (typeof filters.search === 'string' && filters.search.trim()) {
    baseParams.q = filters.search.trim();
  }

  if (import.meta.env.DEV) {
    console.debug('audit query', {
      q: baseParams.q,
      page: baseParams.page,
      limit: baseParams.limit,
      filters: baseParams,
    });
  }

  const params = baseParams;
  const { data } = await api.get<PaginatedResponse<AuditLog>>('/admin/audit', { params });
  return data;
}

export async function fetchAuditDetail(id: string): Promise<AuditDetail> {
  const { data } = await api.get<AuditDetail>(`/admin/audit/${id}`);
  return data;
}

export async function updateAdminNote(id: string, note: string): Promise<void> {
  await api.patch(`/admin/audit/${id}/note`, { note });
}

/* ═══════════════  Export  ═══════════════ */

export async function exportAuditLogs(req: ExportRequest): Promise<Blob> {
  const { data } = await api.post('/admin/export', req, { responseType: 'blob' });
  return data as Blob;
}

/* ═══════════════  Archive  ═══════════════ */

export async function createArchive(startDate: string, endDate: string): Promise<Archive> {
  const { data } = await api.post<Archive>('/admin/archive', { startDate, endDate });
  return data;
}

export async function listArchives(): Promise<Archive[]> {
  const { data } = await api.get<Archive[]>('/admin/archive/list');
  return data;
}

export async function downloadArchive(id: string): Promise<Blob> {
  const { data } = await api.get(`/admin/archive/download/${id}`, { responseType: 'blob' });
  return data as Blob;
}

export async function deleteArchive(id: string): Promise<void> {
  await api.delete(`/admin/archive/${id}`);
}
