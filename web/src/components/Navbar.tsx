import { Bell, Search } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

interface NavbarProps {
  title: string;
}

export default function Navbar({ title }: NavbarProps) {
  const { user } = useAuth();

  return (
    <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-slate-200 bg-white px-6">
      <h1 className="text-lg font-semibold text-slate-800">{title}</h1>

      <div className="flex items-center gap-4">
        {/* Quick search */}
        <div className="hidden items-center gap-2 rounded-lg bg-slate-100 px-3 py-2 text-sm text-slate-500 md:flex">
          <Search className="h-4 w-4" />
          <span className="text-xs">Search…</span>
          <kbd className="ml-4 rounded bg-white px-1.5 py-0.5 text-[10px] font-semibold text-slate-400 shadow-sm">
            ⌘K
          </kbd>
        </div>

        {/* Notifications bell */}
        <button className="relative rounded-lg p-2 text-slate-500 hover:bg-slate-100">
          <Bell className="h-5 w-5" />
        </button>

        {/* Avatar */}
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary text-sm font-bold text-white">
            {user?.name?.charAt(0).toUpperCase() ?? 'A'}
          </div>
          <span className="hidden text-sm font-medium text-slate-700 lg:block">
            {user?.name ?? 'Admin'}
          </span>
        </div>
      </div>
    </header>
  );
}
