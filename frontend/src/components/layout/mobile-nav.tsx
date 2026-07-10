"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard,
  CreditCard,
  ShieldAlert,
  Building2,
  Webhook,
  Settings,
} from "lucide-react";

const NAV = [
  { name: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { name: "Transactions", href: "/transactions", icon: CreditCard },
  { name: "Fraud Cases", href: "/fraud-cases", icon: ShieldAlert },
  { name: "Merchants", href: "/merchants", icon: Building2 },
  { name: "Webhooks", href: "/webhooks", icon: Webhook },
  { name: "Settings", href: "/settings", icon: Settings },
];

/** Horizontal nav for small screens — the fixed sidebar is hidden below lg. */
export function MobileNav() {
  const pathname = usePathname();
  return (
    <nav className="sticky top-16 z-20 flex gap-1 overflow-x-auto border-b border-slate-200 bg-white/95 px-3 py-2 backdrop-blur-sm lg:hidden">
      {NAV.map((item) => {
        const active = pathname.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={cn(
              "flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium transition-colors",
              active
                ? "bg-indigo-50 text-indigo-700"
                : "text-slate-600 hover:bg-slate-50"
            )}
          >
            <item.icon className="h-3.5 w-3.5" />
            {item.name}
          </Link>
        );
      })}
    </nav>
  );
}
