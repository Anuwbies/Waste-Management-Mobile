import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Recycle, AlertCircle, Eye, EyeOff } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [fieldErrors, setFieldErrors] = useState<{ email?: string; password?: string }>({});
  const [loading, setLoading] = useState(false);
  const passwordInputRef = useRef<HTMLInputElement>(null);

  const onEmailChange = (value: string) => {
    setEmail(value);
    setFieldErrors((prev) => (prev.email ? { ...prev, email: undefined } : prev));
    setError((prev) => (prev ? '' : prev));
  };

  const onPasswordChange = (value: string) => {
    setPassword(value);
    setFieldErrors((prev) => (prev.password ? { ...prev, password: undefined } : prev));
    setError((prev) => (prev ? '' : prev));
  };

  const handleSubmit = async (e: React.SubmitEvent) => {
    e.preventDefault();
    if (loading) return;

    const nextFieldErrors: { email?: string; password?: string } = {};
    const normalizedEmail = email.trim();

    if (!normalizedEmail) {
      nextFieldErrors.email = 'Email is required.';
    } else if (!/^\S+@\S+\.\S+$/.test(normalizedEmail)) {
      nextFieldErrors.email = 'Please enter a valid email address.';
    }

    if (!password) {
      nextFieldErrors.password = 'Password is required.';
    }

    if (nextFieldErrors.email || nextFieldErrors.password) {
      setFieldErrors(nextFieldErrors);
      return;
    }

    setFieldErrors({});
    setError('');
    setLoading(true);
    try {
      await login({ email: normalizedEmail, password });
      navigate('/dashboard', { replace: true });
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? 'Invalid credentials. Please try again.';

      const isCredentialError = /invalid credentials|email|password/i.test(msg);
      if (isCredentialError) {
        setFieldErrors({
          email: 'Email or password is incorrect.',
          password: 'Email or password is incorrect.',
        });
        setError('Email or password does not exist or is invalid. Please try again.');
        passwordInputRef.current?.focus();
      } else {
        setError(msg);
        passwordInputRef.current?.focus();
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-linear-to-br from-slate-900 via-slate-800 to-slate-900 px-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="mb-8 flex flex-col items-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/20">
            <Recycle className="h-8 w-8 text-primary" />
          </div>
          <h1 className="mt-4 text-2xl font-bold text-white">RecyClean Admin</h1>
          <p className="mt-1 text-sm text-slate-400">
            Audit Trail &amp; Management Portal
          </p>
        </div>

        {/* Card */}
        <form
          onSubmit={handleSubmit}
          className="rounded-2xl border border-white/10 bg-white/5 p-8 shadow-2xl backdrop-blur-md"
        >
          <h2 className="mb-6 text-lg font-semibold text-white">Sign in to your account</h2>

          {error && (
            <div className="mb-4 flex items-center gap-2 rounded-lg border border-red-400/40 bg-red-500/20 px-4 py-3 text-sm font-medium text-red-200">
              <AlertCircle className="h-4 w-4 shrink-0" />
              {error}
            </div>
          )}

          <div className="space-y-4">
            {/* Email */}
            <div>
              <label className="mb-1.5 block text-sm font-medium text-slate-300">
                Email
              </label>
              <input
                type="email"
                required
                autoFocus
                value={email}
                onChange={(e) => onEmailChange(e.target.value)}
                placeholder="admin@recyclean.io"
                className={`w-full rounded-lg border bg-white/5 px-4 py-2.5 text-sm text-white outline-none placeholder:text-slate-500 focus:ring-2 ${
                  fieldErrors.email
                    ? 'border-red-400 focus:border-red-400 focus:ring-red-400/30'
                    : 'border-white/10 focus:border-primary focus:ring-primary/30'
                }`}
              />
              {fieldErrors.email && (
                <p className="mt-1 text-xs text-red-300">{fieldErrors.email}</p>
              )}
            </div>

            {/* Password */}
            <div>
              <label className="mb-1.5 block text-sm font-medium text-slate-300">
                Password
              </label>
              <div className="relative">
                <input
                  ref={passwordInputRef}
                  type={showPassword ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={(e) => onPasswordChange(e.target.value)}
                  placeholder="••••••••"
                  className={`w-full rounded-lg border bg-white/5 px-4 py-2.5 pr-11 text-sm text-white outline-none placeholder:text-slate-500 focus:ring-2 ${
                    fieldErrors.password
                      ? 'border-red-400 focus:border-red-400 focus:ring-red-400/30'
                      : 'border-white/10 focus:border-primary focus:ring-primary/30'
                  }`}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((prev) => !prev)}
                  className="absolute inset-y-0 right-0 flex items-center px-3 text-slate-400 transition hover:text-slate-200"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
              {fieldErrors.password && (
                <p className="mt-1 text-xs text-red-300">{fieldErrors.password}</p>
              )}
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="mt-6 flex w-full items-center justify-center rounded-lg bg-primary py-2.5 text-sm font-semibold text-white transition-colors hover:bg-primary-dark disabled:opacity-60"
          >
            {loading ? (
              <svg className="h-5 w-5 animate-spin" viewBox="0 0 24 24" fill="none">
                <circle
                  className="opacity-25"
                  cx="12" cy="12" r="10"
                  stroke="currentColor" strokeWidth="4"
                />
                <path
                  className="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
                />
              </svg>
            ) : (
              'Sign In'
            )}
          </button>
        </form>

        <p className="mt-6 text-center text-xs text-slate-500">
          &copy; 2026 RecyClean &mdash; Waste Sorting &amp; Recycling Reward System
        </p>
      </div>
    </div>
  );
}
