import { Bell } from 'lucide-react';
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
