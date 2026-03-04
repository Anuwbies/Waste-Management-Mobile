import { useEffect, useState } from 'react';
import { Search, X } from 'lucide-react';
import type { AuditFilters, ActivityType, AuditStatus, WasteType } from '../types/audit';

interface FilterPanelProps {
  filters: AuditFilters;
  onChange: (filters: AuditFilters) => void;
  onReset: () => void;
}

const activityOptions: { label: string; value: ActivityType }[] = [
  { label: 'Scan', value: 'scan' },
  { label: 'Reward', value: 'reward' },
  { label: 'Redeem', value: 'redeem' },
  { label: 'Wallet Create', value: 'wallet_create' },
  { label: 'Wallet Top-up', value: 'wallet_topup' },
  { label: 'Wallet Withdraw', value: 'wallet_withdraw' },
  { label: 'Login', value: 'login' },
  { label: 'Register', value: 'register' },
];

const statusOptions: { label: string; value: AuditStatus }[] = [
  { label: 'Approved', value: 'approved' },
  { label: 'Denied', value: 'denied' },
  { label: 'Pending', value: 'pending' },
  { label: 'Error', value: 'error' },
];

const wasteOptions: { label: string; value: WasteType }[] = [
  { label: 'Plastic', value: 'plastic' },
  { label: 'Paper', value: 'paper' },
  { label: 'Glass', value: 'glass' },
  { label: 'Metal', value: 'metal' },
  { label: 'Organic', value: 'organic' },
  { label: 'E-Waste', value: 'e-waste' },
  { label: 'Textile', value: 'textile' },
];

export default function FilterPanel({ filters, onChange, onReset }: FilterPanelProps) {
  const [localSearch, setLocalSearch] = useState(filters.search ?? '');

  const set = <K extends keyof AuditFilters>(key: K, value: AuditFilters[K]) =>
    onChange({ ...filters, [key]: value, page: 1 });

  useEffect(() => {
    setLocalSearch(filters.search ?? '');
  }, [filters.search]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const normalizedLocal = localSearch.trim();
      const normalizedFilter = (filters.search ?? '').trim();
      if (normalizedLocal !== normalizedFilter) {
        set('search', normalizedLocal);
      }
    }, 400);

    return () => window.clearTimeout(timer);
  }, [localSearch, filters.search]);

  const hasActiveFilters =
    filters.status ||
    filters.activityType ||
    filters.wasteType ||
    filters.startDate ||
    filters.endDate ||
    filters.search;

  return (
    <div className="space-y-4 rounded-xl border border-slate-200 bg-white p-4">
      {/* Search */}
      <div className="flex gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Search by email, userId, wallet, txHash, or eventHash…"
            value={localSearch}
            onChange={(e) => setLocalSearch(e.target.value)}
            className="w-full rounded-lg border border-slate-300 bg-white py-2 pl-9 pr-3 text-sm outline-none transition-colors focus:border-primary focus:ring-2 focus:ring-primary/20"
          />
        </div>
      </div>

      {/* Filter row */}
      <div className="flex flex-wrap items-end gap-3">
        {/* Date range */}
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-slate-500">Start Date</label>
          <input
            type="date"
            value={filters.startDate ?? ''}
            onChange={(e) => set('startDate', e.target.value)}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary"
          />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-slate-500">End Date</label>
          <input
            type="date"
            value={filters.endDate ?? ''}
            onChange={(e) => set('endDate', e.target.value)}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary"
          />
        </div>

        {/* Status */}
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-slate-500">Status</label>
          <select
            value={filters.status ?? ''}
            onChange={(e) => set('status', e.target.value as AuditStatus | '')}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary"
          >
            <option value="">All</option>
            {statusOptions.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>

        {/* Activity type */}
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-slate-500">Activity</label>
          <select
            value={filters.activityType ?? ''}
            onChange={(e) => set('activityType', e.target.value as ActivityType | '')}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary"
          >
            <option value="">All</option>
            {activityOptions.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>

        {/* Waste type */}
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium text-slate-500">Waste Type</label>
          <select
            value={filters.wasteType ?? ''}
            onChange={(e) => set('wasteType', e.target.value as WasteType | '')}
            className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary"
          >
            <option value="">All</option>
            {wasteOptions.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>

        {/* Reset */}
        {hasActiveFilters && (
          <button
            onClick={onReset}
            className="flex items-center gap-1 rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-600 hover:bg-slate-50"
          >
            <X className="h-3.5 w-3.5" />
            Reset
          </button>
        )}
      </div>
    </div>
  );
}
