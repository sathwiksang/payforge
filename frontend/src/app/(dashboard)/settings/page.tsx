"use client";

import { useState, useEffect, useCallback } from "react";
import { Key, Users, Shield, Eye, EyeOff, Loader2 } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn, formatDate } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

const tabs = [
  { id: "api-keys", label: "API Keys", icon: Key },
  { id: "team", label: "Account", icon: Users },
  { id: "security", label: "Security", icon: Shield },
] as const;

type Tab = (typeof tabs)[number]["id"];

interface ApiKeyData {
  id: string;
  name: string;
  key_prefix: string;
  environment: string;
  last_used_at: string | null;
  expires_at: string | null;
  revoked_at: string | null;
  created_at: string;
}

export default function SettingsPage() {
  const { apiFetch, user } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>("api-keys");
  const [showKey, setShowKey] = useState<string | null>(null);
  const [apiKeys, setApiKeys] = useState<ApiKeyData[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchKeys = useCallback(async () => {
    setLoading(true);
    try {
      const res = await apiFetch<{ data: ApiKeyData[] }>("/api/v1/api_keys");
      setApiKeys(res.data);
    } catch {
      // handled
    } finally {
      setLoading(false);
    }
  }, [apiFetch]);

  useEffect(() => { fetchKeys(); }, [fetchKeys]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Settings</h1>
        <p className="mt-1 text-sm text-slate-500">Manage API keys, account, and security</p>
      </div>

      <div className="flex gap-1 border-b border-slate-200">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={cn(
              "flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors",
              activeTab === tab.id
                ? "border-indigo-600 text-indigo-600"
                : "border-transparent text-slate-500 hover:text-slate-700"
            )}
          >
            <tab.icon size={16} />
            {tab.label}
          </button>
        ))}
      </div>

      {activeTab === "api-keys" && (
        <div className="space-y-4">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
            </div>
          ) : apiKeys.length === 0 ? (
            <Card>
              <div className="text-center py-8">
                <Key size={32} className="mx-auto text-slate-300" />
                <p className="mt-2 text-sm text-slate-500">No API keys created yet</p>
                <p className="text-xs text-slate-400 mt-1">API keys can be created via the Rails console</p>
              </div>
            </Card>
          ) : (
            apiKeys.map((key) => (
              <Card key={key.id}>
                <div className="flex items-center gap-4">
                  <div className="rounded-lg bg-slate-100 p-2.5">
                    <Key size={18} className="text-slate-600" />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <p className="font-medium text-slate-900">{key.name || "API Key"}</p>
                      <Badge className={key.environment === "live" ? "bg-emerald-50 text-emerald-700" : "bg-slate-100 text-slate-600"}>
                        {key.environment}
                      </Badge>
                    </div>
                    <p className="mt-0.5 font-mono text-xs text-slate-400">
                      {showKey === key.id ? `${key.key_prefix}${"x".repeat(32)}` : `${key.key_prefix}${"•".repeat(32)}`}
                    </p>
                    <p className="mt-1 text-xs text-slate-400">
                      Created {formatDate(key.created_at)}
                      {key.last_used_at && ` \u00b7 Last used ${formatDate(key.last_used_at)}`}
                    </p>
                  </div>
                  <Button variant="ghost" size="sm" onClick={() => setShowKey(showKey === key.id ? null : key.id)}>
                    {showKey === key.id ? <EyeOff size={14} /> : <Eye size={14} />}
                  </Button>
                </div>
              </Card>
            ))
          )}
        </div>
      )}

      {activeTab === "team" && (
        <Card>
          <CardTitle>Your Account</CardTitle>
          <div className="mt-4 space-y-3">
            <div className="flex items-center gap-4">
              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-indigo-100 text-lg font-semibold text-indigo-600">
                {user?.email?.charAt(0).toUpperCase()}
              </div>
              <div>
                <p className="font-medium text-slate-900">{user?.email}</p>
                <Badge className="bg-slate-100 text-slate-600 capitalize mt-1">{user?.role}</Badge>
              </div>
            </div>
          </div>
        </Card>
      )}

      {activeTab === "security" && (
        <div className="space-y-4">
          <Card>
            <CardTitle>Two-Factor Authentication</CardTitle>
            <p className="mt-2 text-sm text-slate-500">Add an extra layer of security with TOTP-based 2FA.</p>
            <div className="mt-4">
              <Button size="sm" variant="secondary">Enable 2FA</Button>
            </div>
          </Card>
          <Card>
            <CardTitle>Session Management</CardTitle>
            <p className="mt-2 text-sm text-slate-500">Sessions expire after 15 minutes of inactivity (PCI DSS 4.0).</p>
            <div className="mt-4">
              <Button size="sm" variant="danger">Revoke All Sessions</Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
