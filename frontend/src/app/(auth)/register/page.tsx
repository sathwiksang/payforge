"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { Zap, Eye, EyeOff } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export default function RegisterPage() {
  const [showPassword, setShowPassword] = useState(false);

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-sm"
      >
        <div className="flex items-center justify-center gap-2.5 mb-8">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-600">
            <Zap size={22} className="text-white" />
          </div>
          <span className="text-2xl font-bold text-slate-900 tracking-tight">PayForge</span>
        </div>

        <div className="rounded-xl border border-slate-200 bg-white p-8 shadow-sm">
          <h1 className="text-xl font-bold text-slate-900 text-center">Create account</h1>
          <p className="mt-1.5 text-sm text-slate-500 text-center">Get started with PayForge</p>

          <form className="mt-6 space-y-4" onSubmit={(e) => e.preventDefault()}>
            <Input id="name" label="Full name" type="text" placeholder="Your name" />
            <Input id="email" label="Email" type="email" placeholder="you@company.com" />

            <div className="relative">
              <Input
                id="password"
                label="Password"
                type={showPassword ? "text" : "password"}
                placeholder="Min 12 characters"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-[34px] text-slate-400 hover:text-slate-600"
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>

            <Input id="merchant_name" label="Merchant name" type="text" placeholder="Your business name" />

            <Button type="submit" className="w-full" size="lg">
              Create account
            </Button>
          </form>
        </div>
      </motion.div>
    </div>
  );
}
