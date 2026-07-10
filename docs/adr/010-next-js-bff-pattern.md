# ADR-010: Next.js Frontend with BFF Pattern

**Status:** Accepted
**Date:** 2026-03-01

## Context

PayForge needs a dashboard for merchant operations (transaction monitoring, fraud review, analytics) and an interactive developer documentation portal. The frontend must consume the versioned REST API.

## Decision

Use Next.js 15 with TypeScript as the frontend framework. The frontend acts as a Backend-for-Frontend (BFF), consuming the Rails API. The developer documentation portal is built as static pages under `/docs` with interactive API explorer components.

## Consequences

**Benefits:**
- React 19 with Server Components for optimal initial page load
- Static generation for documentation pages (no server required for docs)
- TypeScript provides type safety for API response handling
- Tailwind 4 for consistent, utility-first styling
- Interactive API explorer with live code generation in 4 languages
- Single deployment can serve both dashboard and documentation

**Trade-offs:**
- Two separate applications to maintain (Rails API + Next.js frontend)
- CORS configuration required for cross-origin API calls
- Node.js dependency in addition to Ruby

## Alternatives Considered

1. **Rails views (ERB/Hotwire)** — Simpler deployment but limited interactivity. Recharts, Framer Motion, and the API explorer would be difficult to implement without React.
2. **Separate documentation site (Docusaurus/Mintlify)** — Another deployment to manage. Integrating docs into the main frontend keeps everything in one place and allows shared components.
3. **Single-page application (Vite + React)** — No SSR/SSG capabilities. Documentation pages benefit from static generation for SEO and performance.
