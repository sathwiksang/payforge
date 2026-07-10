"use client";

import { useState, useCallback } from "react";
import { cn } from "@/lib/utils";
import { Play, Copy, Check, Loader2, ChevronDown, ChevronRight, Terminal } from "lucide-react";

function getApiBase(): string {
  if (typeof window !== "undefined") {
    const host = window.location.hostname;
    if (host === "payforge.sathwiksangeethamproject.dev") {
      return "https://payforge-api.sathwiksangeethamproject.dev";
    }
  }
  return process.env.NEXT_PUBLIC_API_URL || "http://localhost:3200";
}



interface ApiPlaygroundProps {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  description?: string;
  defaultBody?: string;
  defaultParams?: Record<string, string>;
}

const METHOD_COLORS: Record<string, string> = {
  GET: "bg-emerald-500",
  POST: "bg-blue-500",
  PUT: "bg-amber-500",
  PATCH: "bg-amber-500",
  DELETE: "bg-red-500",
};

export function ApiPlayground({
  method,
  path,
  description,
  defaultBody,
  defaultParams = {},
}: ApiPlaygroundProps) {
  const [token, setToken] = useState("");
  const [body, setBody] = useState(defaultBody || "");
  const [params, setParams] = useState<Record<string, string>>(defaultParams);
  const [response, setResponse] = useState<string | null>(null);
  const [statusCode, setStatusCode] = useState<number | null>(null);
  const [responseTime, setResponseTime] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);
  const [showAuth, setShowAuth] = useState(true);

  const resolvedPath = Object.entries(params).reduce(
    (p, [key, value]) => p.replace(`:${key}`, value),
    path
  );

  const executeRequest = useCallback(async () => {
    if (!token) {
      setResponse(JSON.stringify({ error: "Please provide a JWT token. Sign in first to get one." }, null, 2));
      setStatusCode(401);
      return;
    }

    setLoading(true);
    setResponse(null);
    const start = performance.now();

    try {
      const options: RequestInit = {
        method,
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      };

      if (body && method !== "GET") {
        options.body = body;
      }

      const res = await fetch(`${getApiBase()}${resolvedPath}`, options);
      const elapsed = Math.round(performance.now() - start);
      const data = await res.json();

      setStatusCode(res.status);
      setResponseTime(elapsed);
      setResponse(JSON.stringify(data, null, 2));
    } catch (err) {
      setStatusCode(0);
      setResponseTime(null);
      setResponse(
        JSON.stringify(
          { error: err instanceof Error ? err.message : "Network error — is the backend running?" },
          null,
          2
        )
      );
    } finally {
      setLoading(false);
    }
  }, [token, body, method, resolvedPath]);

  const quickLogin = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch(`${getApiBase()}/api/v1/auth/sign_in`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user: { email: "admin@payforge.dev", password: "PayForge2026Secure" } }),
      });
      const jwt = res.headers.get("Authorization")?.replace("Bearer ", "") || "";
      if (jwt) {
        setToken(jwt);
        setResponse(JSON.stringify({ message: "Authenticated! You can now make API calls." }, null, 2));
        setStatusCode(200);
      } else {
        setResponse(JSON.stringify({ error: "Login failed — check if the backend is running on port 3200" }, null, 2));
        setStatusCode(401);
      }
    } catch {
      setResponse(JSON.stringify({ error: "Cannot connect to backend. Make sure it is running." }, null, 2));
      setStatusCode(0);
    } finally {
      setLoading(false);
    }
  }, []);

  const handleCopy = () => {
    if (response) {
      navigator.clipboard.writeText(response);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="rounded-xl border border-slate-200 overflow-hidden my-6 bg-white shadow-sm">
      {/* Header */}
      <div className="flex items-center justify-between px-5 py-3.5 bg-slate-900">
        <div className="flex items-center gap-3">
          <Terminal size={14} className="text-slate-400" />
          <span className="text-xs font-medium text-slate-400 uppercase tracking-wider">
            API Playground
          </span>
        </div>
        <div className="flex items-center gap-2">
          <span className={cn("h-2 w-2 rounded-full", token ? "bg-emerald-400" : "bg-slate-600")} />
          <span className="text-[11px] text-slate-500">
            {token ? "Authenticated" : "Not authenticated"}
          </span>
        </div>
      </div>

      {/* Endpoint */}
      <div className="flex items-center gap-3 px-5 py-3 border-b border-slate-200 bg-slate-50">
        <span className={cn("px-2 py-0.5 rounded text-[10px] font-bold text-white uppercase", METHOD_COLORS[method])}>
          {method}
        </span>
        <code className="text-sm font-mono text-slate-700 flex-1">{resolvedPath}</code>
        <button
          onClick={executeRequest}
          disabled={loading}
          className="flex items-center gap-1.5 rounded-lg bg-indigo-600 px-3.5 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700 disabled:opacity-50 transition-colors"
        >
          {loading ? <Loader2 size={12} className="animate-spin" /> : <Play size={12} />}
          Send
        </button>
      </div>

      <div className="p-5 space-y-4">
        {description && (
          <p className="text-sm text-slate-600">{description}</p>
        )}

        {/* Auth */}
        <div>
          <button
            onClick={() => setShowAuth(!showAuth)}
            className="flex items-center gap-1.5 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2"
          >
            {showAuth ? <ChevronDown size={12} /> : <ChevronRight size={12} />}
            Authentication
          </button>
          {showAuth && (
            <div className="flex items-center gap-2">
              <input
                type="text"
                placeholder="Paste JWT token here..."
                value={token}
                onChange={(e) => setToken(e.target.value)}
                className="flex-1 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-xs font-mono text-slate-700 placeholder:text-slate-400 focus:border-indigo-300 focus:outline-none focus:ring-2 focus:ring-indigo-100"
              />
              <button
                onClick={quickLogin}
                disabled={loading}
                className="whitespace-nowrap rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-medium text-slate-700 hover:bg-slate-50 transition-colors"
              >
                Quick Login
              </button>
            </div>
          )}
        </div>

        {/* Request body */}
        {method !== "GET" && (
          <div>
            <label className="text-xs font-semibold text-slate-500 uppercase tracking-wider block mb-2">
              Request Body
            </label>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              rows={6}
              spellCheck={false}
              className="w-full rounded-lg border border-slate-200 bg-slate-900 px-4 py-3 text-xs font-mono text-emerald-300 placeholder:text-slate-600 focus:border-indigo-400 focus:outline-none focus:ring-2 focus:ring-indigo-100 resize-y"
              placeholder='{ "key": "value" }'
            />
          </div>
        )}

        {/* Response */}
        {response !== null && (
          <div>
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
                  Response
                </span>
                {statusCode !== null && (
                  <span
                    className={cn(
                      "px-2 py-0.5 rounded-full text-[10px] font-bold",
                      statusCode >= 200 && statusCode < 300
                        ? "bg-emerald-100 text-emerald-700"
                        : statusCode >= 400
                        ? "bg-red-100 text-red-700"
                        : "bg-amber-100 text-amber-700"
                    )}
                  >
                    {statusCode}
                  </span>
                )}
                {responseTime !== null && (
                  <span className="text-[10px] text-slate-400">{responseTime}ms</span>
                )}
              </div>
              <button
                onClick={handleCopy}
                className="text-slate-400 hover:text-slate-600 transition-colors"
              >
                {copied ? <Check size={14} className="text-emerald-500" /> : <Copy size={14} />}
              </button>
            </div>
            <pre className="rounded-lg bg-slate-900 p-4 overflow-x-auto text-xs font-mono leading-relaxed text-slate-300 max-h-96 overflow-y-auto">
              <code>{response}</code>
            </pre>
          </div>
        )}
      </div>
    </div>
  );
}
