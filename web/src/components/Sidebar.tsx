import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  ScrollText,
  Download,
  Archive,
  LogOut,
  Recycle,
} from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

const links = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/audit', label: 'Audit Logs', icon: ScrollText },
  { to: '/export', label: 'Export Center', icon: Download },
  { to: '/archives', label: 'Archives', icon: Archive },
];

export default function Sidebar() {
  const { logout, user } = useAuth();

  return (
    <aside className="fixed inset-y-0 left-0 z-30 flex w-64 flex-col bg-sidebar text-white">
      {/* Brand */}
      <div className="flex h-16 items-center gap-2 px-6">
        <Recycle className="h-7 w-7 text-primary" />
        <span className="text-lg font-bold tracking-tight">RecyClean</span>
        <span className="ml-1 rounded bg-primary/20 px-1.5 py-0.5 text-[10px] font-semibold text-primary">
          ADMIN
        </span>
      </div>

      {/* Navigation */}
      <nav className="mt-4 flex-1 space-y-1 px-3">
        {links.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-sidebar-active text-primary'
                  : 'text-slate-300 hover:bg-sidebar-hover hover:text-white'
              }`
            }
          >
            <Icon className="h-5 w-5" />
            {label}
          </NavLink>
        ))}
      </nav>

      {/* User / Logout */}
      <div className="border-t border-white/10 px-4 py-4">
        <p className="truncate text-xs text-slate-400">{user?.email}</p>
        <button
          onClick={logout}
          className="mt-2 flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-300 transition-colors hover:bg-sidebar-hover hover:text-white"
        >
          <LogOut className="h-4 w-4" />
          Sign out
        </button>
      </div>
    </aside>
  );
}
