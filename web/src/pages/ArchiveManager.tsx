import { useEffect, useState } from 'react';
import {
  Archive,
  Download,
  Trash2,
  Plus,
  Calendar,
  HardDrive,
  Loader2,
} from 'lucide-react';
import { format } from 'date-fns';
import Navbar from '../components/Navbar';
import {
  listArchives,
  createArchive,
  downloadArchive,
  deleteArchive,
} from '../services/auditService';
import type { Archive as ArchiveType } from '../types/audit';

/* Format bytes */
function fmtSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1048576).toFixed(2)} MB`;
}

export default function ArchiveManager() {
  const [archives, setArchives] = useState<ArchiveType[]>([]);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [showForm, setShowForm] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const data = await listArchives();
      setArchives(data);
    } catch {
      /* ignore */
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  const handleCreate = async () => {
    if (!startDate || !endDate) return;
    setCreating(true);
    try {
      await createArchive(startDate, endDate);
      setShowForm(false);
      setStartDate('');
      setEndDate('');
      await load();
    } catch {
      alert('Failed to create archive.');
    } finally {
      setCreating(false);
    }
  };

  const handleDownload = async (id: string) => {
    try {
      const blob = await downloadArchive(id);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `archive-${id}.zip`;
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      alert('Download failed.');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this archive permanently?')) return;
    try {
      await deleteArchive(id);
      setArchives((prev) => prev.filter((a) => a.id !== id));
    } catch {
      alert('Delete failed.');
    }
  };

  const statusStyles: Record<string, string> = {
    ready: 'bg-emerald-100 text-emerald-700',
    processing: 'bg-yellow-100 text-yellow-700',
    error: 'bg-red-100 text-red-700',
  };

  return (
    <div>
      <Navbar title="Archive Manager" />

      <div className="p-6">
        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-slate-800">Archives</h2>
            <p className="text-sm text-slate-500">
              Create and manage downloadable ZIP archives of audit logs.
            </p>
          </div>
          <button
            onClick={() => setShowForm(!showForm)}
            className="flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark"
          >
            <Plus className="h-4 w-4" />
            New Archive
          </button>
        </div>

        {/* Create form */}
        {showForm && (
          <div className="mb-6 rounded-xl border border-slate-200 bg-white p-5">
            <h3 className="mb-3 text-sm font-semibold text-slate-700">
              Create New Archive
            </h3>
            <div className="flex flex-wrap items-end gap-3">
              <div className="flex flex-col gap-1">
                <label className="text-xs font-medium text-slate-500">Start Date</label>
                <input
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary"
                />
              </div>
              <div className="flex flex-col gap-1">
                <label className="text-xs font-medium text-slate-500">End Date</label>
                <input
                  type="date"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary"
                />
              </div>
              <button
                onClick={handleCreate}
                disabled={creating || !startDate || !endDate}
                className="flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark disabled:opacity-50"
              >
                {creating ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Archive className="h-4 w-4" />
                )}
                {creating ? 'Creating…' : 'Create'}
              </button>
            </div>
          </div>
        )}

        {/* List */}
        {loading ? (
          <div className="flex items-center justify-center py-20 text-slate-400">
            Loading archives…
          </div>
        ) : archives.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-slate-400">
            <Archive className="mb-3 h-10 w-10" />
            <p className="text-sm">No archives yet. Create one to get started.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {archives.map((arch) => (
              <div
                key={arch.id}
                className="flex items-center justify-between rounded-xl border border-slate-200 bg-white px-5 py-4"
              >
                <div className="flex items-center gap-4">
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-50 text-slate-500">
                    <Archive className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-sm font-medium text-slate-700">
                        <Calendar className="mr-1 inline h-3.5 w-3.5" />
                        {format(new Date(arch.startDate), 'MMM dd, yyyy')} →{' '}
                        {format(new Date(arch.endDate), 'MMM dd, yyyy')}
                      </p>
                      <span
                        className={`rounded-full px-2 py-0.5 text-[10px] font-semibold capitalize ${statusStyles[arch.status] ?? ''}`}
                      >
                        {arch.status}
                      </span>
                    </div>
                    <p className="mt-0.5 text-xs text-slate-500">
                      {arch.recordCount.toLocaleString()} records &middot;{' '}
                      <HardDrive className="mr-0.5 inline h-3 w-3" />
                      {fmtSize(arch.fileSize)} &middot; Created{' '}
                      {format(new Date(arch.createdAt), 'PPp')}
                    </p>
                  </div>
                </div>

                <div className="flex gap-2">
                  {arch.status === 'ready' && (
                    <button
                      onClick={() => handleDownload(arch.id)}
                      className="rounded-lg p-2 text-slate-500 hover:bg-slate-100 hover:text-info"
                      title="Download"
                    >
                      <Download className="h-4 w-4" />
                    </button>
                  )}
                  <button
                    onClick={() => handleDelete(arch.id)}
                    className="rounded-lg p-2 text-slate-500 hover:bg-red-50 hover:text-danger"
                    title="Delete"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
