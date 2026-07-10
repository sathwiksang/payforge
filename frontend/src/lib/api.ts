function getApiBase(): string {
  if (typeof window !== "undefined") {
    const host = window.location.hostname;
    if (host === "payforge.sathwiksangeethamproject.dev") {
      return "https://payforge-api.sathwiksangeethamproject.dev";
    }
  }
  return process.env.NEXT_PUBLIC_API_URL || "http://localhost:3200";
}

interface RequestOptions extends RequestInit {
  params?: Record<string, string | number | undefined>;
}

class ApiClient {
  private token: string | null = null;

  private get baseUrl(): string {
    return getApiBase();
  }

  setToken(token: string | null) {
    this.token = token;
  }

  private buildUrl(path: string, params?: Record<string, string | number | undefined>): string {
    const url = new URL(`${this.baseUrl}${path}`);
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined) url.searchParams.set(key, String(value));
      });
    }
    return url.toString();
  }

  private async request<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const { params, ...fetchOptions } = options;
    const url = this.buildUrl(path, params);

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...((fetchOptions.headers as Record<string, string>) || {}),
    };

    if (this.token) {
      headers["Authorization"] = `Bearer ${this.token}`;
    }

    const response = await fetch(url, { ...fetchOptions, headers });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: "Request failed" }));
      throw new ApiError(response.status, error.error || "Request failed");
    }

    return response.json();
  }

  get<T>(path: string, params?: Record<string, string | number | undefined>) {
    return this.request<T>(path, { method: "GET", params });
  }

  post<T>(path: string, body?: unknown) {
    return this.request<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined });
  }

  put<T>(path: string, body?: unknown) {
    return this.request<T>(path, { method: "PUT", body: body ? JSON.stringify(body) : undefined });
  }

  delete<T>(path: string) {
    return this.request<T>(path, { method: "DELETE" });
  }
}

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = "ApiError";
  }
}

export const api = new ApiClient();
