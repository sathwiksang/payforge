"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";
import { Check, Copy } from "lucide-react";

interface CodeBlockProps {
  code: string;
  language?: string;
  title?: string;
}

export function CodeBlock({ code, language = "bash", title }: CodeBlockProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="rounded-lg border border-[var(--pf-border)] overflow-hidden my-4">
      {title && (
        <div className="flex items-center justify-between px-4 py-2 bg-[var(--pf-bg-tertiary)] border-b border-[var(--pf-border)]">
          <span className="text-xs font-medium text-[var(--pf-text-secondary)]">{title}</span>
          <span className="text-xs text-[var(--pf-text-muted)] font-mono">{language}</span>
        </div>
      )}
      <div className="relative group">
        <pre className="p-4 overflow-x-auto bg-[#1E293B] text-[#E2E8F0] text-sm font-mono leading-relaxed">
          <code>{code}</code>
        </pre>
        <button
          onClick={handleCopy}
          className={cn(
            "absolute top-3 right-3 p-1.5 rounded-md transition-all",
            "opacity-0 group-hover:opacity-100",
            copied
              ? "bg-green-500/20 text-green-400"
              : "bg-white/10 text-white/60 hover:text-white hover:bg-white/20"
          )}
        >
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
        </button>
      </div>
    </div>
  );
}

interface TabbedCodeBlockProps {
  tabs: { label: string; language: string; code: string }[];
  title?: string;
}

export function TabbedCodeBlock({ tabs, title }: TabbedCodeBlockProps) {
  const [activeTab, setActiveTab] = useState(0);
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(tabs[activeTab].code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="rounded-lg border border-[var(--pf-border)] overflow-hidden my-4">
      <div className="flex items-center justify-between px-2 bg-[var(--pf-bg-tertiary)] border-b border-[var(--pf-border)]">
        <div className="flex">
          {tabs.map((tab, i) => (
            <button
              key={tab.label}
              onClick={() => setActiveTab(i)}
              className={cn(
                "px-3 py-2 text-xs font-medium transition-colors",
                i === activeTab
                  ? "text-brand-primary border-b-2 border-brand-primary"
                  : "text-[var(--pf-text-muted)] hover:text-[var(--pf-text-secondary)]"
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>
        {title && <span className="text-xs text-[var(--pf-text-muted)] pr-2">{title}</span>}
      </div>
      <div className="relative group">
        <pre className="p-4 overflow-x-auto bg-[#1E293B] text-[#E2E8F0] text-sm font-mono leading-relaxed">
          <code>{tabs[activeTab].code}</code>
        </pre>
        <button
          onClick={handleCopy}
          className={cn(
            "absolute top-3 right-3 p-1.5 rounded-md transition-all",
            "opacity-0 group-hover:opacity-100",
            copied
              ? "bg-green-500/20 text-green-400"
              : "bg-white/10 text-white/60 hover:text-white hover:bg-white/20"
          )}
        >
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
        </button>
      </div>
    </div>
  );
}
