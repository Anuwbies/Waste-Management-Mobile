import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  User,
  Brain,
  Coins,
  Link2,
  Hash,
  Image,
  StickyNote,
  Save,
} from 'lucide-react';
import { format } from 'date-fns';
import Navbar from '../components/Navbar';
import { StatusBadge } from '../components/DataTable';
import { fetchAuditDetail, updateAdminNote } from '../services/auditService';
import type { AuditDetail as AuditDetailType } from '../types/audit';

/* Section card helper */
function Section({
  icon: Icon,
  title,
  children,
}: {
  icon: React.ElementType;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5">
      <div className="mb-4 flex items-center gap-2">
        <Icon className="h-5 w-5 text-slate-500" />
        <h3 className="text-sm font-semibold text-slate-700">{title}</h3>
      </div>
      {children}
    </div>
  );
}

/* KV row helper */
function Row({ label, value, mono }: { label: string; value?: string | number | null; mono?: boolean }) {
  return (
    <div className="flex items-start justify-between border-b border-slate-100 py-2 last:border-b-0">
      <span className="text-xs text-slate-500">{label}</span>
      <span className={`text-sm text-slate-700 ${mono ? 'font-mono text-xs' : ''}`}>
        {value ?? '-'}
      </span>
    </div>
  );
}

export default function AuditDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [detail, setDetail] = useState<AuditDetailType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [note, setNote] = useState('');
  const [savingNote, setSavingNote] = useState(false);

  useEffect(() => {
    if (!id) return;
    fetchAuditDetail(id)
      .then((d) => {
        setDetail(d);
        setNote(d.adminNotes ?? '');
      })
      .catch(() => setError('Failed to load audit detail.'))
      .finally(() => setLoading(false));
  }, [id]);

  const handleSaveNote = async () => {
    if (!id) return;
    setSavingNote(true);
    try {
      await updateAdminNote(id, note);
    } catch {
      alert('Failed to save note.');
    } finally {
      setSavingNote(false);
    }
  };

  return (
    <div>
      <Navbar title="Audit Detail" />

      <div className="p-6">
        {/* Back button */}
        <button
          onClick={() => navigate(-1)}
          className="mb-4 flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700"
        >
          <ArrowLeft className="h-4 w-4" /> Back to Audit Logs
        </button>

        {loading && (
          <div className="flex items-center justify-center py-32 text-slate-400">
            Loading…
          </div>
        )}

        {error && (
          <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">
            {error}
          </div>
        )}

        {detail && (
          <>
            {/* Header */}
            <div className="mb-6 flex flex-wrap items-center gap-3">
              <h2 className="text-lg font-bold text-slate-800">
                {detail.activityType.replace('_', ' ').toUpperCase()}
              </h2>
              <StatusBadge status={detail.status} />
              <span className="text-xs text-slate-400">
                {format(new Date(detail.timestamp), 'PPpp')}
              </span>
            </div>

            <div className="grid gap-5 lg:grid-cols-2">
              {/* User Info */}
              <Section icon={User} title="User Information">
                <Row label="Name" value={detail.user.name} />
                <Row label="Email" value={detail.user.email} />
                <Row label="User ID" value={detail.user.id} mono />
                <Row label="Wallet" value={detail.user.walletAddress} mono />
              </Section>

              {/* AI Classification */}
              <Section icon={Brain} title="AI Classification">
                {detail.aiClassification ? (
                  <>
                    <Row label="Waste Type" value={detail.aiClassification.wasteType} />
                    <Row
                      label="Confidence"
                      value={`${(detail.aiClassification.confidence * 100).toFixed(1)}%`}
                    />
                    <Row label="Model" value={detail.aiClassification.modelVersion} />
                    <Row label="Image Hash" value={detail.aiClassification.imageHash} mono />
                    {detail.aiClassification.rawPredictions && (
                      <div className="mt-2">
                        <p className="mb-1 text-xs text-slate-500">Raw Predictions</p>
                        <div className="space-y-1">
                          {Object.entries(detail.aiClassification.rawPredictions).map(
                            ([k, v]) => (
                              <div key={k} className="flex items-center gap-2">
                                <span className="w-20 text-xs capitalize text-slate-600">
                                  {k}
                                </span>
                                <div className="h-2 flex-1 overflow-hidden rounded-full bg-slate-100">
                                  <div
                                    className="h-full rounded-full bg-primary"
                                    style={{ width: `${(v as number) * 100}%` }}
                                  />
                                </div>
                                <span className="text-xs text-slate-500">
                                  {((v as number) * 100).toFixed(1)}%
                                </span>
                              </div>
                            ),
                          )}
                        </div>
                      </div>
                    )}
                  </>
                ) : (
                  <p className="text-sm text-slate-400">No AI data for this event.</p>
                )}
              </Section>

              {/* Reward */}
              <Section icon={Coins} title="Reward Calculation">
                {detail.reward ? (
                  <>
                    <Row label="Points Awarded" value={detail.reward.points} />
                    <Row label="Calculation" value={detail.reward.calculation} />
                    <Row
                      label="Bonus Applied"
                      value={detail.reward.bonusApplied ? 'Yes' : 'No'}
                    />
                  </>
                ) : (
                  <p className="text-sm text-slate-400">No reward data.</p>
                )}
              </Section>

              {/* Image preview placeholder */}
              <Section icon={Image} title="Scan Image">
                <div className="flex h-40 items-center justify-center rounded-lg bg-slate-50 text-sm text-slate-400">
                  Image preview not available
                </div>
              </Section>
            </div>

            {/* Admin Notes */}
            <div className="mt-5">
              <Section icon={StickyNote} title="Admin Notes">
                <textarea
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  rows={4}
                  placeholder="Add a note about this audit entry…"
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
                <button
                  onClick={handleSaveNote}
                  disabled={savingNote}
                  className="mt-2 flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-dark disabled:opacity-50"
                >
                  <Save className="h-4 w-4" />
                  {savingNote ? 'Saving…' : 'Save Note'}
                </button>
              </Section>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
