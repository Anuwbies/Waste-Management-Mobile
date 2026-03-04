import { useState } from 'react';
import { Download, FileJson, FileSpreadsheet } from 'lucide-react';
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
  const [success, setSuccess] = useState(false);

  const handleExport = async () => {
    setExporting(true);
    setSuccess(false);
    try {
      const filters: AuditFilters = { startDate, endDate, status, activityType, wasteType };
      const blob = await exportAuditLogs({ format, filters });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `audit-export-${Date.now()}.${format}`;
      a.click();
      URL.revokeObjectURL(url);
      setSuccess(true);
    } catch {
      alert('Export failed. Please try again.');
    } finally {
      setExporting(false);
    }
  };

  const selectClass =
    'rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary';

  return (
    <div>
      <Navbar title="Export Center" />

      <div className="mx-auto max-w-2xl space-y-6 p-6">
        <div className="rounded-xl border border-slate-200 bg-white p-6">
          <h2 className="mb-1 text-lg font-semibold text-slate-800">Export Audit Logs</h2>
          <p className="mb-6 text-sm text-slate-500">
            Configure filters and download audit data in CSV or JSON format.
          </p>

          {/* Format picker */}
          <div className="mb-6 flex gap-3">
            <button
              onClick={() => setFormat('csv')}
              className={`flex flex-1 items-center justify-center gap-2 rounded-xl border-2 py-4 text-sm font-medium transition-colors ${
                format === 'csv'
                  ? 'border-primary bg-primary-light text-primary-dark'
                  : 'border-slate-200 text-slate-500 hover:border-slate-300'
              }`}
            >
              <FileSpreadsheet className="h-5 w-5" />
              CSV
            </button>
            <button
              onClick={() => setFormat('json')}
              className={`flex flex-1 items-center justify-center gap-2 rounded-xl border-2 py-4 text-sm font-medium transition-colors ${
                format === 'json'
                  ? 'border-primary bg-primary-light text-primary-dark'
                  : 'border-slate-200 text-slate-500 hover:border-slate-300'
              }`}
            >
              <FileJson className="h-5 w-5" />
              JSON
            </button>
          </div>

          {/* Filters */}
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="flex flex-col gap-1">
              <label className="text-xs font-medium text-slate-500">Start Date</label>
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className={selectClass}
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-xs font-medium text-slate-500">End Date</label>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className={selectClass}
              />
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-xs font-medium text-slate-500">Status</label>
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
              <label className="text-xs font-medium text-slate-500">Activity Type</label>
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
              <label className="text-xs font-medium text-slate-500">Waste Type</label>
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

          {/* Export button */}
          <button
            onClick={handleExport}
            disabled={exporting}
            className="mt-6 flex w-full items-center justify-center gap-2 rounded-lg bg-primary py-3 text-sm font-semibold text-white transition-colors hover:bg-primary-dark disabled:opacity-50"
          >
            <Download className="h-4 w-4" />
            {exporting ? 'Exporting…' : `Export as ${format.toUpperCase()}`}
          </button>

          {success && (
            <p className="mt-3 text-center text-sm text-emerald-600">
              Export downloaded successfully!
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
