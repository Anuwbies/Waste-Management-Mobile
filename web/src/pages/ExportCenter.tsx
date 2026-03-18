import { useState } from 'react';
import {
  Download,
  FileJson,
  FileSpreadsheet,
  CheckCircle2,
  AlertCircle,
  Loader2,
  RotateCcw,
  Calendar,
  Filter,
} from 'lucide-react';
import Navbar from '../components/Navbar';
import { exportAuditLogs } from '../services/auditService';
import type { AuditFilters, AuditStatus, ActivityType, WasteType } from '../types/audit';

export default function ExportCenter() {
  const [format, setFormat] = useState<'csv' | 'json'>('csv');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [status, setStatus] = useState<AuditStatus | ''>('');
  const [activityType, setActivityType] = useState<ActivityType | ''>('');
  const [wasteType, setWasteType] = useState<WasteType | ''>('');
  const [exporting, setExporting] = useState(false);
  const [result, setResult] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  const hasFilters = startDate || endDate || status || activityType || wasteType;

  const handleReset = () => {
    setStartDate('');
    setEndDate('');
    setStatus('');
    setActivityType('');
    setWasteType('');
    setResult(null);
  };

  const handleExport = async () => {
    setExporting(true);
    setResult(null);
    try {
      // Build clean filters — only include non-empty values
      const filters: AuditFilters = {};
      if (startDate) filters.startDate = startDate;
      if (endDate) filters.endDate = endDate;
      if (status) filters.status = status;
      if (activityType) filters.activityType = activityType;
      if (wasteType) filters.wasteType = wasteType;

      const blob = await exportAuditLogs({ format, filters });

      // Validate that we received actual blob data
      if (!blob || blob.size === 0) {
        setResult({ type: 'error', message: 'Export returned empty data. There may be no records matching your filters.' });
        return;
      }

      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `audit-export-${new Date().toISOString().slice(0, 10)}.${format}`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      const sizeMB = (blob.size / (1024 * 1024)).toFixed(2);
      setResult({
        type: 'success',
        message: `Export downloaded successfully! (${sizeMB} MB)`,
      });
    } catch (err: unknown) {
      const message =
        err instanceof Error ? err.message : 'Export failed. Please check your connection and try again.';
      setResult({ type: 'error', message });
    } finally {
      setExporting(false);
    }
  };

  const selectClass =
    'w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-sm text-slate-700 outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary/20';

  const labelClass = 'text-xs font-semibold uppercase tracking-wide text-slate-500';

  return (
    <div>
      <Navbar title="Export Center" />

      <div className="mx-auto max-w-2xl space-y-6 p-6">
        {/* ── Main Card ── */}
        <div className="rounded-xl border border-slate-200 bg-white shadow-sm">
          {/* Header */}
          <div className="border-b border-slate-100 px-6 pt-6 pb-4">
            <h2 className="text-lg font-semibold text-slate-800">Export Audit Logs</h2>
            <p className="mt-1 text-sm text-slate-500">
              Configure filters and download audit data in CSV or JSON format.
            </p>
          </div>

          <div className="space-y-6 p-6">
            {/* ── Format picker ── */}
            <div>
              <p className={labelClass + ' mb-2'}>Export Format</p>
              <div className="flex gap-3">
                <button
                  onClick={() => setFormat('csv')}
                  className={`flex flex-1 items-center justify-center gap-2 rounded-xl border-2 py-4 text-sm font-medium transition-all ${
                    format === 'csv'
                      ? 'border-primary bg-primary/5 text-primary-dark shadow-sm'
                      : 'border-slate-200 text-slate-500 hover:border-slate-300 hover:bg-slate-50'
                  }`}
                >
                  <FileSpreadsheet className="h-5 w-5" />
                  CSV
                </button>
                <button
                  onClick={() => setFormat('json')}
                  className={`flex flex-1 items-center justify-center gap-2 rounded-xl border-2 py-4 text-sm font-medium transition-all ${
                    format === 'json'
                      ? 'border-primary bg-primary/5 text-primary-dark shadow-sm'
                      : 'border-slate-200 text-slate-500 hover:border-slate-300 hover:bg-slate-50'
                  }`}
                >
                  <FileJson className="h-5 w-5" />
                  JSON
                </button>
              </div>
            </div>

            {/* ── Date Range ── */}
            <div>
              <div className="mb-2 flex items-center gap-1.5">
                <Calendar className="h-3.5 w-3.5 text-slate-400" />
                <p className={labelClass}>Date Range</p>
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="flex flex-col gap-1">
                  <label className="text-xs text-slate-400">From</label>
                  <input
                    type="date"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className={selectClass}
                  />
                </div>
                <div className="flex flex-col gap-1">
                  <label className="text-xs text-slate-400">To</label>
                  <input
                    type="date"
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                    className={selectClass}
                  />
                </div>
              </div>
            </div>

            {/* ── Filters ── */}
            <div>
              <div className="mb-2 flex items-center gap-1.5">
                <Filter className="h-3.5 w-3.5 text-slate-400" />
                <p className={labelClass}>Filters</p>
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="flex flex-col gap-1">
                  <label className="text-xs text-slate-400">Status</label>
                  <select
                    value={status}
                    onChange={(e) => setStatus(e.target.value as AuditStatus | '')}
                    className={selectClass}
                  >
                    <option value="">All</option>
                    <option value="approved">Approved</option>
                    <option value="denied">Denied</option>
                    <option value="pending">Pending</option>
                    <option value="error">Error</option>
                  </select>
                </div>
                <div className="flex flex-col gap-1">
                  <label className="text-xs text-slate-400">Activity Type</label>
                  <select
                    value={activityType}
                    onChange={(e) => setActivityType(e.target.value as ActivityType | '')}
                    className={selectClass}
                  >
                    <option value="">All</option>
                    <option value="scan">Scan</option>
                    <option value="reward">Reward</option>
                    <option value="redeem">Redeem</option>
                    <option value="wallet_create">Wallet Create</option>
                    <option value="wallet_topup">Wallet Top-up</option>
                    <option value="wallet_withdraw">Wallet Withdraw</option>
                  </select>
                </div>
                <div className="flex flex-col gap-1 sm:col-span-2">
                  <label className="text-xs text-slate-400">Waste Type</label>
                  <select
                    value={wasteType}
                    onChange={(e) => setWasteType(e.target.value as WasteType | '')}
                    className={selectClass}
                  >
                    <option value="">All</option>
                    <option value="plastic">Plastic</option>
                    <option value="paper">Paper</option>
                    <option value="glass">Glass</option>
                    <option value="metal">Metal</option>
                    <option value="organic">Organic</option>
                    <option value="e-waste">E-Waste</option>
                    <option value="textile">Textile</option>
                  </select>
                </div>
              </div>
            </div>

            {/* ── Action buttons ── */}
            <div className="flex flex-col gap-3 pt-2">
              <button
                onClick={handleExport}
                disabled={exporting}
                className="flex w-full items-center justify-center gap-2 rounded-lg bg-primary py-3 text-sm font-semibold text-white shadow-sm transition-all hover:bg-primary-dark hover:shadow-md active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50"
              >
                {exporting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    Exporting…
                  </>
                ) : (
                  <>
                    <Download className="h-4 w-4" />
                    Export as {format.toUpperCase()}
                  </>
                )}
              </button>

              {hasFilters && (
                <button
                  onClick={handleReset}
                  disabled={exporting}
                  className="flex items-center justify-center gap-2 rounded-lg border border-slate-200 bg-white py-2.5 text-sm font-medium text-slate-600 transition-all hover:bg-slate-50 disabled:opacity-50"
                >
                  <RotateCcw className="h-3.5 w-3.5" />
                  Reset Filters
                </button>
              )}
            </div>

            {/* ── Result feedback ── */}
            {result && (
              <div
                className={`flex items-start gap-3 rounded-lg px-4 py-3 text-sm ${
                  result.type === 'success'
                    ? 'bg-emerald-50 text-emerald-700'
                    : 'bg-red-50 text-red-700'
                }`}
              >
                {result.type === 'success' ? (
                  <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
                ) : (
                  <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
                )}
                <span>{result.message}</span>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
