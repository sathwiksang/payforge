"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";
import { Play, Copy, Check, ChevronDown, ChevronRight } from "lucide-react";

interface Parameter {
  name: string;
  type: string;
  required?: boolean;
  description: string;
  default?: string;
}

interface ApiExplorerProps {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  description: string;
  parameters?: Parameter[];
  requestBody?: string;
  sampleResponse: string;
}

const METHOD_COLORS: Record<string, string> = {
  GET: "bg-green-100 text-green-700 border-green-200",
  POST: "bg-blue-100 text-blue-700 border-blue-200",
  PUT: "bg-amber-100 text-amber-700 border-amber-200",
  PATCH: "bg-amber-100 text-amber-700 border-amber-200",
  DELETE: "bg-red-100 text-red-700 border-red-200",
};

export function ApiExplorer({
  method,
  path,
  description,
  parameters = [],
  requestBody,
  sampleResponse,
}: ApiExplorerProps) {
  const [paramValues, setParamValues] = useState<Record<string, string>>({});
  const [showResponse, setShowResponse] = useState(false);
  const [activeTab, setActiveTab] = useState<"curl" | "js" | "python" | "ruby">("curl");
  const [copied, setCopied] = useState(false);

  const buildCurl = () => {
    const queryParams = parameters
      .filter((p) => paramValues[p.name])
      .map((p) => `${p.name}=${encodeURIComponent(paramValues[p.name])}`)
      .join("&");
    const url = `https://api.payforge.dev${path}${queryParams ? `?${queryParams}` : ""}`;
    let cmd = `curl -X ${method} "${url}" \\\n  -H "Authorization: Bearer pk_test_..." \\\n  -H "Content-Type: application/json"`;
    if (requestBody && (method === "POST" || method === "PATCH" || method === "PUT")) {
      cmd += ` \\\n  -d '${requestBody}'`;
    }
    return cmd;
  };

  const buildJS = () => {
    const queryParams = parameters
      .filter((p) => paramValues[p.name])
      .map((p) => `${p.name}=${encodeURIComponent(paramValues[p.name])}`)
      .join("&");
    const url = `https://api.payforge.dev${path}${queryParams ? `?${queryParams}` : ""}`;
    let code = `const response = await fetch("${url}", {\n  method: "${method}",\n  headers: {\n    "Authorization": "Bearer pk_test_...",\n    "Content-Type": "application/json",\n  },`;
    if (requestBody && method !== "GET") {
      code += `\n  body: JSON.stringify(${requestBody}),`;
    }
    code += `\n});\n\nconst data = await response.json();\nconsole.log(data);`;
    return code;
  };

  const buildPython = () => {
    const url = `https://api.payforge.dev${path}`;
    let code = `import requests\n\nresponse = requests.${method.toLowerCase()}(\n    "${url}",\n    headers={\n        "Authorization": "Bearer pk_test_...",\n        "Content-Type": "application/json",\n    },`;
    if (parameters.length > 0) {
      code += `\n    params={`;
      parameters.filter((p) => paramValues[p.name]).forEach((p) => {
        code += `\n        "${p.name}": "${paramValues[p.name]}",`;
      });
      code += `\n    },`;
    }
    if (requestBody && method !== "GET") {
      code += `\n    json=${requestBody},`;
    }
    code += `\n)\n\nprint(response.json())`;
    return code;
  };

  const buildRuby = () => {
    const url = `https://api.payforge.dev${path}`;
    let code = `require "net/http"\nrequire "json"\n\nuri = URI("${url}")\nhttp = Net::HTTP.new(uri.host, uri.port)\nhttp.use_ssl = true\n\nrequest = Net::HTTP::${method[0] + method.slice(1).toLowerCase()}.new(uri)\nrequest["Authorization"] = "Bearer pk_test_..."\nrequest["Content-Type"] = "application/json"`;
    if (requestBody && method !== "GET") {
      code += `\nrequest.body = ${requestBody}.to_json`;
    }
    code += `\n\nresponse = http.request(request)\nputs JSON.parse(response.body)`;
    return code;
  };

  const codeGenerators: Record<string, () => string> = {
    curl: buildCurl,
    js: buildJS,
    python: buildPython,
    ruby: buildRuby,
  };

  const generatedCode = codeGenerators[activeTab]();

  const handleCopy = () => {
    navigator.clipboard.writeText(generatedCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="rounded-xl border border-[var(--pf-border)] overflow-hidden my-6 bg-[var(--pf-bg-primary)]">
      {/* Header */}
      <div className="flex items-center gap-3 px-5 py-4 border-b border-[var(--pf-border)] bg-[var(--pf-bg-secondary)]">
        <span className={cn("px-2.5 py-1 rounded-md text-xs font-bold border", METHOD_COLORS[method])}>
          {method}
        </span>
        <code className="text-sm font-mono font-medium text-[var(--pf-text-primary)]">{path}</code>
      </div>

      <div className="p-5">
        <p className="text-sm text-[var(--pf-text-secondary)] mb-4">{description}</p>

        {/* Parameters */}
        {parameters.length > 0 && (
          <div className="mb-4">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--pf-text-muted)] mb-3">
              Parameters
            </h4>
            <div className="space-y-2">
              {parameters.map((param) => (
                <div key={param.name} className="flex items-start gap-3">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <code className="text-xs font-mono font-medium text-[var(--pf-text-primary)]">{param.name}</code>
                      <span className="text-xs text-[var(--pf-text-muted)]">{param.type}</span>
                      {param.required && (
                        <span className="text-xs text-red-500 font-medium">required</span>
                      )}
                    </div>
                    <p className="text-xs text-[var(--pf-text-muted)]">{param.description}</p>
                  </div>
                  <input
                    type="text"
                    placeholder={param.default || param.name}
                    value={paramValues[param.name] || ""}
                    onChange={(e) => setParamValues((prev) => ({ ...prev, [param.name]: e.target.value }))}
                    className="w-48 px-3 py-1.5 text-xs font-mono border border-[var(--pf-border)] rounded-md bg-[var(--pf-bg-secondary)] focus:outline-none focus:ring-2 focus:ring-brand-primary/20 focus:border-brand-primary"
                  />
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Code tabs */}
        <div className="rounded-lg border border-[var(--pf-border)] overflow-hidden">
          <div className="flex items-center justify-between px-2 bg-[#1E293B]">
            <div className="flex">
              {(["curl", "js", "python", "ruby"] as const).map((tab) => (
                <button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className={cn(
                    "px-3 py-2 text-xs font-medium transition-colors",
                    activeTab === tab
                      ? "text-white border-b-2 border-brand-primary"
                      : "text-white/50 hover:text-white/80"
                  )}
                >
                  {tab === "js" ? "JavaScript" : tab === "curl" ? "cURL" : tab.charAt(0).toUpperCase() + tab.slice(1)}
                </button>
              ))}
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={handleCopy}
                className="p-1.5 rounded text-white/50 hover:text-white transition-colors"
              >
                {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
              </button>
              <button
                onClick={() => setShowResponse(true)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium bg-brand-primary text-white hover:bg-brand-hover transition-colors"
              >
                <Play className="h-3 w-3" />
                Try it
              </button>
            </div>
          </div>
          <pre className="p-4 overflow-x-auto bg-[#1E293B] text-[#E2E8F0] text-xs font-mono leading-relaxed">
            <code>{generatedCode}</code>
          </pre>
        </div>

        {/* Response */}
        <div className="mt-4">
          <button
            onClick={() => setShowResponse(!showResponse)}
            className="flex items-center gap-2 text-sm font-medium text-[var(--pf-text-secondary)] hover:text-[var(--pf-text-primary)] transition-colors"
          >
            {showResponse ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
            Sample Response
          </button>
          {showResponse && (
            <pre className="mt-2 p-4 rounded-lg overflow-x-auto bg-[#1E293B] text-[#E2E8F0] text-xs font-mono leading-relaxed border border-[var(--pf-border)]">
              <code>{sampleResponse}</code>
            </pre>
          )}
        </div>
      </div>
    </div>
  );
}
