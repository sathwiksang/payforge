"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  BookOpen,
  Code2,
  Webhook,
  AlertTriangle,
  Layers,
  Shield,
  Zap,
  ArrowLeft,
  Search,
} from "lucide-react";
import { useState } from "react";

const NAV_SECTIONS = [
  {
    title: "Getting Started",
    items: [
      { href: "/docs", label: "Introduction", icon: Zap },
    ],
  },
  {
    title: "API",
    items: [
      { href: "/docs/api-reference", label: "API Reference", icon: Code2 },
      { href: "/docs/webhooks", label: "Webhooks", icon: Webhook },
      { href: "/docs/error-codes", label: "Error Codes", icon: AlertTriangle },
    ],
  },
  {
    title: "Platform",
    items: [
      { href: "/docs/architecture", label: "Architecture", icon: Layers },
      { href: "/docs/security", label: "Security", icon: Shield },
    ],
  },
];

export default function DocsLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [searchQuery, setSearchQuery] = useState("");

  const filteredSections = NAV_SECTIONS.map((section) => ({
    ...section,
    items: section.items.filter((item) =>
      item.label.toLowerCase().includes(searchQuery.toLowerCase())
    ),
  })).filter((section) => section.items.length > 0);

  return (
    <div className="min-h-screen bg-white">
      {/* Top bar */}
      <header className="sticky top-0 z-50 border-b border-slate-200 bg-white/95 backdrop-blur-sm">
        <div className="mx-auto flex items-center justify-between px-6 h-16 max-w-[1400px]">
          <div className="flex items-center gap-4">
            <Link href="/" className="flex items-center gap-2 text-slate-400 hover:text-slate-600 transition-colors">
              <ArrowLeft className="h-4 w-4" />
            </Link>
            <div className="h-5 w-px bg-slate-200" />
            <Link href="/docs" className="flex items-center gap-2.5">
              <div className="flex h-7 w-7 items-center justify-center rounded-md bg-indigo-600">
                <BookOpen className="h-3.5 w-3.5 text-white" />
              </div>
              <span className="font-bold text-slate-900">PayForge</span>
              <span className="rounded-md bg-indigo-50 px-2 py-0.5 text-[11px] font-semibold text-indigo-600">
                DOCS
              </span>
            </Link>
          </div>
          <div className="flex items-center gap-4">
            <span className="rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-mono text-slate-500">
              v1.0.0
            </span>
            <Link
              href="/dashboard"
              className="inline-flex items-center gap-1.5 rounded-lg bg-indigo-600 px-3.5 py-1.5 text-sm font-medium text-white hover:bg-indigo-700 transition-colors"
            >
              Dashboard
            </Link>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-[1400px] flex">
        {/* Sidebar */}
        <aside className="w-64 shrink-0 border-r border-slate-200 sticky top-16 h-[calc(100vh-4rem)] overflow-y-auto">
          <div className="p-4">
            {/* Search */}
            <div className="relative mb-5">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-slate-400" />
              <input
                type="text"
                placeholder="Search docs..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full rounded-lg border border-slate-200 bg-slate-50 py-2 pl-9 pr-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-indigo-300 focus:bg-white focus:outline-none focus:ring-2 focus:ring-indigo-100 transition-all"
              />
            </div>

            {/* Navigation */}
            <nav className="space-y-6">
              {filteredSections.map((section) => (
                <div key={section.title}>
                  <h3 className="mb-2 px-3 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                    {section.title}
                  </h3>
                  <div className="space-y-0.5">
                    {section.items.map((item) => {
                      const isActive = pathname === item.href;
                      return (
                        <Link
                          key={item.href}
                          href={item.href}
                          className={cn(
                            "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm transition-colors",
                            isActive
                              ? "bg-indigo-50 text-indigo-700 font-medium"
                              : "text-slate-600 hover:text-slate-900 hover:bg-slate-50"
                          )}
                        >
                          <item.icon className={cn("h-4 w-4", isActive ? "text-indigo-500" : "text-slate-400")} />
                          {item.label}
                        </Link>
                      );
                    })}
                  </div>
                </div>
              ))}
            </nav>
          </div>
        </aside>

        {/* Content */}
        <main className="flex-1 min-w-0 px-12 py-10 max-w-4xl">{children}</main>
      </div>
    </div>
  );
}
