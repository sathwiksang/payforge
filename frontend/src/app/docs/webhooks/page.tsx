"use client";

import { CodeBlock, TabbedCodeBlock } from "@/components/docs/code-block";

const EVENT_TYPES = [
  { event: "payment.initiated", description: "Payment created and queued for processing" },
  { event: "payment.authorized", description: "Network authorization successful" },
  { event: "payment.authorization_failed", description: "Network declined the authorization" },
  { event: "payment.fraud_passed", description: "Fraud check passed, payment cleared" },
  { event: "payment.fraud_blocked", description: "Fraud check blocked the payment" },
  { event: "payment.captured", description: "Payment captured and funds secured" },
  { event: "payment.settled", description: "Settlement complete, funds transferred" },
  { event: "payment.refunded", description: "Full refund processed" },
  { event: "payment.partially_refunded", description: "Partial refund processed" },
  { event: "payment.voided", description: "Authorization voided before capture" },
  { event: "payment.dispute_opened", description: "Dispute or chargeback opened" },
  { event: "payment.dispute_resolved", description: "Dispute resolved" },
];

export default function WebhooksPage() {
  return (
    <article className="max-w-3xl">
      <h1 className="text-3xl font-bold text-[var(--pf-text-primary)] mb-2">Webhooks</h1>
      <p className="text-lg text-[var(--pf-text-secondary)] mb-8">
        Receive real-time notifications when events occur in your PayForge account.
      </p>

      {/* Overview */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">How Webhooks Work</h2>
        <p className="text-sm text-[var(--pf-text-secondary)] mb-3">
          When an event occurs (e.g., a payment is captured), PayForge sends an HTTP POST request to your
          configured endpoint with the event data. Your endpoint should return a <code className="text-xs bg-[var(--pf-bg-tertiary)] px-1.5 py-0.5 rounded font-mono">2xx</code> status
          to acknowledge receipt.
        </p>
        <div className="grid grid-cols-3 gap-3 mb-4">
          {[
            { label: "Retry Policy", value: "5 attempts over 24h" },
            { label: "Timeout", value: "30 seconds" },
            { label: "Signature", value: "HMAC-SHA256" },
          ].map((item) => (
            <div key={item.label} className="p-3 rounded-lg border border-[var(--pf-border)] bg-[var(--pf-bg-secondary)] text-center">
              <div className="text-xs text-[var(--pf-text-tertiary)] mb-1">{item.label}</div>
              <div className="text-sm font-semibold text-[var(--pf-text-primary)]">{item.value}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Webhook Payload */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">Webhook Payload</h2>
        <CodeBlock
          language="json"
          title="Example webhook payload"
          code={`{
  "id": "evt_01ABC...",
  "type": "payment.captured",
  "created_at": "2026-03-06T10:31:00Z",
  "data": {
    "id": "pay_01HXYZ...",
    "amount_cents": 5000,
    "currency": "USD",
    "status": "captured",
    "merchant_id": "mer_01ABC...",
    "fraud_score": 0.03
  }
}`}
        />
      </section>

      {/* Event Types */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">Event Types</h2>
        <div className="rounded-lg border border-[var(--pf-border)] overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-[var(--pf-bg-secondary)]">
                <th className="text-left px-4 py-2.5 font-semibold text-[var(--pf-text-primary)]">Event</th>
                <th className="text-left px-4 py-2.5 font-semibold text-[var(--pf-text-primary)]">Description</th>
              </tr>
            </thead>
            <tbody>
              {EVENT_TYPES.map((row, i) => (
                <tr key={row.event} className={i % 2 === 0 ? "" : "bg-[var(--pf-bg-secondary)]/50"}>
                  <td className="px-4 py-2 font-mono text-xs text-brand-primary">{row.event}</td>
                  <td className="px-4 py-2 text-[var(--pf-text-secondary)]">{row.description}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Signature Verification */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">Signature Verification</h2>
        <p className="text-sm text-[var(--pf-text-secondary)] mb-3">
          Every webhook includes a <code className="text-xs bg-[var(--pf-bg-tertiary)] px-1.5 py-0.5 rounded font-mono">X-PayForge-Signature</code> header.
          Always verify signatures to ensure the webhook came from PayForge. The signature format is{" "}
          <code className="text-xs bg-[var(--pf-bg-tertiary)] px-1.5 py-0.5 rounded font-mono">t=timestamp,v1=signature</code>.
        </p>

        <TabbedCodeBlock
          title="Verify webhook signature"
          tabs={[
            {
              label: "Ruby",
              language: "ruby",
              code: `def verify_webhook(payload, signature_header, secret)
  parts = signature_header.split(",").map { |p| p.split("=", 2) }.to_h
  timestamp = parts["t"]
  expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "\#{timestamp}.\#{payload}")

  # Timing-safe comparison prevents timing attacks
  Rack::Utils.secure_compare(expected, parts["v1"])
end

# Usage in a Rails controller
class WebhooksController < ApplicationController
  def receive
    payload = request.body.read
    sig = request.headers["X-PayForge-Signature"]

    unless verify_webhook(payload, sig, ENV["PAYFORGE_WEBHOOK_SECRET"])
      head :unauthorized
      return
    end

    event = JSON.parse(payload)
    # Handle the event...
    head :ok
  end
end`,
            },
            {
              label: "JavaScript",
              language: "javascript",
              code: `import crypto from "crypto";

function verifyWebhook(payload, signatureHeader, secret) {
  const parts = Object.fromEntries(
    signatureHeader.split(",").map((p) => p.split("=", 2))
  );

  const expected = crypto
    .createHmac("sha256", secret)
    .update(\`\${parts.t}.\${payload}\`)
    .digest("hex");

  return crypto.timingSafeEqual(
    Buffer.from(expected),
    Buffer.from(parts.v1)
  );
}

// Usage with Express
app.post("/webhooks", express.raw({ type: "application/json" }), (req, res) => {
  const sig = req.headers["x-payforge-signature"];
  if (!verifyWebhook(req.body.toString(), sig, process.env.PAYFORGE_WEBHOOK_SECRET)) {
    return res.status(401).send("Invalid signature");
  }

  const event = JSON.parse(req.body);
  // Handle the event...
  res.sendStatus(200);
});`,
            },
            {
              label: "Python",
              language: "python",
              code: `import hmac
import hashlib

def verify_webhook(payload: str, signature_header: str, secret: str) -> bool:
    parts = dict(p.split("=", 1) for p in signature_header.split(","))
    timestamp = parts["t"]
    expected = hmac.new(
        secret.encode(),
        f"{timestamp}.{payload}".encode(),
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, parts["v1"])

# Usage with Flask
@app.route("/webhooks", methods=["POST"])
def receive_webhook():
    payload = request.get_data(as_text=True)
    sig = request.headers.get("X-PayForge-Signature")

    if not verify_webhook(payload, sig, os.environ["PAYFORGE_WEBHOOK_SECRET"]):
        abort(401)

    event = request.get_json()
    # Handle the event...
    return "", 200`,
            },
          ]}
        />
      </section>

      {/* Retry Policy */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">Retry Schedule</h2>
        <p className="text-sm text-[var(--pf-text-secondary)] mb-4">
          Failed deliveries are retried with exponential backoff:
        </p>
        <div className="rounded-lg border border-[var(--pf-border)] overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-[var(--pf-bg-secondary)]">
                <th className="text-left px-4 py-2.5 font-semibold text-[var(--pf-text-primary)]">Attempt</th>
                <th className="text-left px-4 py-2.5 font-semibold text-[var(--pf-text-primary)]">Delay</th>
              </tr>
            </thead>
            <tbody>
              {[
                { attempt: "1st retry", delay: "1 minute" },
                { attempt: "2nd retry", delay: "5 minutes" },
                { attempt: "3rd retry", delay: "30 minutes" },
                { attempt: "4th retry", delay: "2 hours" },
                { attempt: "5th retry (final)", delay: "24 hours" },
              ].map((row, i) => (
                <tr key={row.attempt} className={i % 2 === 0 ? "" : "bg-[var(--pf-bg-secondary)]/50"}>
                  <td className="px-4 py-2 text-[var(--pf-text-primary)]">{row.attempt}</td>
                  <td className="px-4 py-2 text-[var(--pf-text-secondary)]">{row.delay}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Testing */}
      <section className="mb-10">
        <h2 className="text-xl font-semibold text-[var(--pf-text-primary)] mb-3">Testing Webhooks</h2>
        <p className="text-sm text-[var(--pf-text-secondary)] mb-3">
          Use the test endpoint to send a sample webhook event to your configured URL:
        </p>
        <CodeBlock
          language="bash"
          title="Send test webhook"
          code={`curl -X POST "https://api.payforge.dev/api/v1/webhooks/test" \\
  -H "Authorization: Bearer sk_test_..." \\
  -H "Content-Type: application/json" \\
  -d '{ "event_type": "payment.captured" }'`}
        />
        <p className="text-sm text-[var(--pf-text-secondary)] mt-3">
          You can also view delivery history in the dashboard under <strong>Webhooks &rarr; Deliveries</strong> to
          debug failed deliveries and inspect payloads.
        </p>
      </section>
    </article>
  );
}
