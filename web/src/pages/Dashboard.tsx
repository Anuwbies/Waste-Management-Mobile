import { useEffect, useState } from 'react';
import {
  Users,
  ScanLine,
  CheckCircle2,
  XCircle,
  Coins,
  Link2,
  Brain,
} from 'lucide-react';
import Navbar from '../components/Navbar';
import { fetchDashboard } from '../services/auditService';
import type { DashboardStats } from '../types/audit';

/* Single stat card */
function StatCard({
  label,
  value,
  icon: Icon,
  accent = 'text-primary',
}: {
  label: string;
  value: string | number;
  icon: React.ElementType;
  accent?: string;
}) {
  return (
    <div className="flex items-center gap-4 rounded-xl border border-slate-200 bg-white p-5">
      <div className={`flex h-12 w-12 items-center justify-center rounded-lg bg-slate-50 ${accent}`}>
        <Icon className="h-6 w-6" />
      </div>
      <div>
        <p className="text-sm text-slate-500">{label}</p>
        <p className="text-2xl font-bold text-slate-800">{value}</p>
      </div>
    </div>
  );
}

/* Status pill */
function StatusPill({ online, label }: { online: boolean; label: string }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold ${
        online ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'
      }`}
    >
      <span className={`h-2 w-2 rounded-full ${online ? 'bg-emerald-500' : 'bg-red-500'}`} />
      {label}
    </span>
  );
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchDashboard()
      .then(setStats)
      .catch(() => setError('Failed to load dashboard data.'))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <Navbar title="Dashboard" />

      <div className="p-6">
        {loading && (
          <div className="flex items-center justify-center py-32 text-slate-400">
            Loading dashboard…
          </div>
        )}

        {error && (
          <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">
            {error}
          </div>
        )}

        {stats && (
          <>
            {/* Top stats */}
            <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
              <StatCard label="Total Users" value={stats.totalUsers} icon={Users} />
              <StatCard label="Scans Today" value={stats.totalScansToday} icon={ScanLine} accent="text-info" />
              <StatCard label="Approved" value={stats.approvedScans} icon={CheckCircle2} accent="text-emerald-600" />
              <StatCard label="Denied" value={stats.deniedScans} icon={XCircle} accent="text-danger" />
              <StatCard label="Points Minted" value={stats.totalPointsMinted.toLocaleString()} icon={Coins} accent="text-warning" />
            </div>

            {/* Service status */}
            <div className="mt-8 grid gap-5 md:grid-cols-2">
              {/* AI Service */}
              <div className="rounded-xl border border-slate-200 bg-white p-5">
                <div className="mb-3 flex items-center gap-2">
                  <Brain className="h-5 w-5 text-purple-500" />
                  <h3 className="text-sm font-semibold text-slate-700">AI Classification</h3>
                </div>
                <div className="space-y-2 text-sm">
                  <StatusPill
                    online={stats.aiService.status === 'online'}
                    label={stats.aiService.status}
                  />
                  {stats.aiService.modelVersion && (
                    <p className="text-slate-500">
                      Model: <span className="font-mono text-slate-700">{stats.aiService.modelVersion}</span>
                    </p>
                  )}
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
