export type TransactionStatus =
  | "pending" | "initiated" | "authorized" | "fraud_cleared"
  | "captured" | "settled" | "failed" | "refunded"
  | "partially_refunded" | "voided" | "blocked";

export type FraudDecision = "pass" | "review" | "block";
export type FraudCaseStatus = "open" | "under_review" | "confirmed_fraud" | "false_positive" | "escalated";
export type FraudCasePriority = "low" | "medium" | "high" | "critical";
export type UserRole = "super_admin" | "admin" | "manager" | "analyst" | "viewer";
export type MerchantStatus = "active" | "suspended" | "deactivated";
export type ApiKeyEnvironment = "test" | "live";

export interface Transaction {
  id: string;
  idempotency_key: string;
  merchant_id: string;
  merchant_name?: string;
  amount_cents: number;
  currency: string;
  status: TransactionStatus;
  fraud_decision: FraudDecision | null;
  fraud_score: number | null;
  card_last_four: string | null;
  card_brand: string | null;
  fee_cents: number | null;
  net_cents: number | null;
  captured_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface FraudCase {
  id: string;
  transaction_id: string;
  merchant_id: string;
  merchant_name?: string;
  status: FraudCaseStatus;
  priority: FraudCasePriority;
  risk_score: number;
  decision: FraudDecision;
  model_used: string;
  reviewer_id: string | null;
  notes: string | null;
  reviewed_at: string | null;
  resolved_at: string | null;
  created_at: string;
}

export interface Merchant {
  id: string;
  name: string;
  email: string;
  status: MerchantStatus;
  risk_tier: "standard" | "elevated" | "high";
  fee_percentage: number;
  fee_fixed_cents: number;
  onboarded_at: string | null;
  created_at: string;
}

export interface User {
  id: string;
  email: string;
  role: UserRole;
  merchant_id: string;
  merchant_name?: string;
}

export interface ApiKey {
  id: string;
  name: string;
  key_prefix: string;
  environment: ApiKeyEnvironment;
  last_used_at: string | null;
  expires_at: string | null;
  revoked_at: string | null;
  created_at: string;
}

export interface DashboardMetrics {
  total_volume_cents: number;
  total_revenue_cents: number;
  average_transaction_cents: number;
  fraud_rate: number;
  volume_change: number;
  revenue_change: number;
  avg_txn_change: number;
  fraud_rate_change: number;
  volume_sparkline: number[];
  revenue_sparkline: number[];
  avg_txn_sparkline: number[];
  fraud_sparkline: number[];
}

export interface ShapFeature {
  feature: string;
  value: number;
  shap_value: number;
  direction: "increases_risk" | "decreases_risk";
}

export interface LedgerEntry {
  id: string;
  transaction_id: string;
  from_account: string;
  to_account: string;
  amount_cents: number;
  currency: string;
  entry_type: string;
  created_at: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}
