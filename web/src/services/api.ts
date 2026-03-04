import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api';

const api = axios.create({
  baseURL: API_BASE,
  withCredentials: true,
  headers: { 'Content-Type': 'application/json' },
});

/* ── Attach JWT from memory on every request ── */
let _token: string | null = null;

export function setToken(token: string | null) {
  _token = token;
  if (token) {
    localStorage.setItem('admin_token', token);
  } else {
    localStorage.removeItem('admin_token');
  }
}

export function getToken(): string | null {
  if (_token) return _token;
  const stored = localStorage.getItem('admin_token');
  if (stored) _token = stored;
  return _token;
}

api.interceptors.request.use((config) => {
  const token = getToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

/* ── Auto-redirect on 401 ── */
api.interceptors.response.use(
  (res) => res,
  (err) => {
    const status = err.response?.status;
    const requestUrl = String(err.config?.url ?? '');
    const isAdminLoginRequest = /\/admin\/login(?:\?.*)?$/.test(requestUrl);
    const isAlreadyOnLogin = window.location.pathname === '/login';

    if (status === 401 && !isAdminLoginRequest) {
      setToken(null);
      if (!isAlreadyOnLogin) {
        window.location.assign('/login');
      }
    }
    return Promise.reject(err);
  },
);

export default api;
