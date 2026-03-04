import { useEffect, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Download } from 'lucide-react';
import { format } from 'date-fns';
import Navbar from '../components/Navbar';
import DataTable, { StatusBadge } from '../components/DataTable';
import FilterPanel from '../components/FilterPanel';
import Pagination from '../components/Pagination';
import { fetchAuditLogs, exportAuditLogs } from '../services/auditService';
import type { AuditLog, AuditFilters, PaginatedResponse } from '../types/audit';

const DEFAULT_FILTERS: AuditFilters = {
  page: 1,
  limit: 20,
  status: '',
  activityType: '',
  wasteType: '',
  search: '',
  startDate: '',
  endDate: '',
};

export default function AuditLogs() {
  const navigate = useNavigate();
  const [filters, setFilters] = useState<AuditFilters>(DEFAULT_FILTERS);
  const [result, setResult] = useState<PaginatedResponse<AuditLog> | null>(null);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetchAuditLogs(filters);
      setResult(res);
    } catch {
      /* handled by interceptor */
    } finally {
      setLoading(false);
    }
  }, [filters]);

  useEffect(() => { load(); }, [load]);

  /* Export handler */
  const handleExport = async (fmt: 'csv' | 'json') => {
    setExporting(true);
    try {
      const blob = await exportAuditLogs({ format: fmt, filters });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `audit-export-${Date.now()}.${fmt}`;
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      alert('Export failed. Please try again.');
    } finally {
      setExporting(false);
    }
  };

  const columns = [
    {
      key: 'timestamp',
      header: 'Timestamp',
      render: (r: AuditLog) => (
        <span className="text-xs text-slate-600">
          {format(new Date(r.timestamp), 'MMM dd, yyyy HH:mm:ss')}
        </span>
      ),
    },
    {
      key: 'userEmail',
      header: 'User',
      render: (r: AuditLog) => (
        <span className="font-medium text-slate-700">{r.userEmail}</span>
      ),
    },
    {
      key: 'activityType',
      header: 'Activity',
      render: (r: AuditLog) => (
        <span className="rounded bg-slate-100 px-2 py-0.5 text-xs font-medium capitalize text-slate-600">
          {r.activityType.replace('_', ' ')}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: AuditLog) => <StatusBadge status={r.status} />,
    },
    {
      key: 'wasteType',
      header: 'Waste',
      render: (r: AuditLog) => (
        <span className="capitalize text-slate-600">{r.wasteType ?? '-'}</span>
      ),
    },
    {
      key: 'confidence',
      header: 'Confidence',
      render: (r: AuditLog) =>
        r.confidence != null ? (
          <span className="text-slate-600">{(r.confidence * 100).toFixed(1)}%</span>
        ) : (
          <span className="text-slate-400">-</span>
        ),
    },
    {
      key: 'points',
      header: 'Points',
      render: (r: AuditLog) => (
        <span className="font-semibold text-slate-700">{r.points ?? '-'}</span>
      ),
    },
    {
      key: 'txHash',
      header: 'TxHash',
      render: (r: AuditLog) =>
        r.txHash ? (
          <span className="font-mono text-xs text-info">
            {r.txHash.slice(0, 8)}…{r.txHash.slice(-6)}
          </span>
        ) : (
          <span className="text-slate-400">-</span>
        ),
    },
  ];

  return (
    <div>
      <Navbar title="Audit Logs" />

      <div className="space-y-5 p-6">
        {/* Filters */}
        <FilterPanel
          filters={filters}
          onChange={setFilters}
          onReset={() => setFilters(DEFAULT_FILTERS)}
        />

        {/* Toolbar */}
        <div className="flex items-center justify-between">
          <p className="text-sm text-slate-500">
            {result ? `${result.total.toLocaleString()} records` : '—'}
          </p>
          <div className="flex gap-2">
            <button
              disabled={exporting}
              onClick={() => handleExport('csv')}
              className="flex items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
            >
              <Download className="h-4 w-4" />
              CSV
            </button>
            <button
              disabled={exporting}
              onClick={() => handleExport('json')}
              className="flex items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
            >
              <Download className="h-4 w-4" />
              JSON
            </button>
          </div>
        </div>

        {/* Table */}
        <DataTable
          columns={columns}
          data={result?.data ?? []}
          loading={loading}
          onRowClick={(row) => navigate(`/audit/${row.id}`)}
          emptyMessage="No audit logs match your filters."
        />

        {/* Pagination */}
        {result && (
          <Pagination
            page={result.page}
            totalPages={result.totalPages}
            onPageChange={(p) => setFilters((f) => ({ ...f, page: p }))}
          />
        )}
      </div>
    </div>
  );
}
