import type { AuditStatus } from '../types/audit';

interface Column<T> {
  key: string;
  header: string;
  render?: (row: T) => React.ReactNode;
  className?: string;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  onRowClick?: (row: T) => void;
  loading?: boolean;
  emptyMessage?: string;
}

/* Badge helper */
export function StatusBadge({ status }: { status: AuditStatus }) {
  const map: Record<AuditStatus, string> = {
    approved: 'bg-emerald-100 text-emerald-800',
    denied: 'bg-red-100 text-red-800',
    pending: 'bg-yellow-100 text-yellow-800',
    error: 'bg-slate-100 text-slate-600',
  };
  return (
    <span
      className={`inline-block rounded-full px-2.5 py-0.5 text-xs font-semibold capitalize ${map[status] ?? map.error}`}
    >
      {status}
    </span>
  );
}

export default function DataTable<T extends { id?: string }>({
  columns,
  data,
  onRowClick,
  loading = false,
  emptyMessage = 'No records found.',
}: DataTableProps<T>) {
  if (loading) {
    return (
      <div className="flex items-center justify-center py-20 text-slate-400">
        <svg
          className="mr-2 h-5 w-5 animate-spin"
          viewBox="0 0 24 24"
          fill="none"
        >
          <circle
            className="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="4"
          />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
          />
        </svg>
        Loading…
      </div>
    );
  }

  if (data.length === 0) {
    return (
      <div className="flex items-center justify-center py-20 text-sm text-slate-400">
        {emptyMessage}
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
      <table className="min-w-full text-sm">
        <thead>
          <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-medium uppercase tracking-wider text-slate-500">
            {columns.map((col) => (
              <th key={col.key} className={`px-4 py-3 ${col.className ?? ''}`}>
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {data.map((row, idx) => (
            <tr
              key={(row as Record<string, unknown>).id as string ?? idx}
              onClick={() => onRowClick?.(row)}
              className={`transition-colors ${onRowClick ? 'cursor-pointer hover:bg-slate-50' : ''}`}
            >
              {columns.map((col) => (
                <td
                  key={col.key}
                  className={`whitespace-nowrap px-4 py-3 ${col.className ?? ''}`}
                >
                  {col.render
                    ? col.render(row)
                    : String((row as Record<string, unknown>)[col.key] ?? '-')}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
