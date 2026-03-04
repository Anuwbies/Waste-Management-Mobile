import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from 'react';
import type { AdminUser, LoginCredentials } from '../types/audit';
import { adminLogin, adminLogout } from '../services/auditService';
import { setToken, getToken } from '../services/api';

/* ── Context shape ── */
interface AuthCtx {
  user: AdminUser | null;
  loading: boolean;
  login: (creds: LoginCredentials) => Promise<void>;
  logout: () => void;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthCtx | undefined>(undefined);

/* ── Provider ── */
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [loading, setLoading] = useState(true);

  /* Rehydrate from localStorage on mount */
  useEffect(() => {
    const token = getToken();
    const saved = localStorage.getItem('admin_user');
    if (token && saved) {
      try {
        setUser(JSON.parse(saved) as AdminUser);
      } catch {
        setToken(null);
        localStorage.removeItem('admin_user');
      }
    }
    setLoading(false);
  }, []);

  const login = useCallback(async (creds: LoginCredentials) => {
    try {
      const res = await adminLogin(creds);
      setToken(res.token);
      localStorage.setItem('admin_user', JSON.stringify(res.user));
      setUser(res.user);
    } catch (error) {
      throw error;
    }
  }, []);

  const logout = useCallback(() => {
    adminLogout();
    setToken(null);
    localStorage.removeItem('admin_user');
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{ user, loading, login, logout, isAuthenticated: !!user }}
    >
      {children}
    </AuthContext.Provider>
  );
}

/* ── Hook ── */
export function useAuth(): AuthCtx {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
