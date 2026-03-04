---
name: observability
description: |
  Investigate production issues at 37signals using Grafana (Prometheus, Loki, Tempo) and Sentry.
  Use when asked to debug, investigate, monitor, or diagnose production behavior for any 37signals app.
triggers:
  # Direct invocations
  - /observability
  - /observe
  - /investigate
  # Production investigation
  - investigate production
  - debug production
  - production issue
  - production error
  - production slowness
  - production latency
  - what's happening in production
  - something's wrong in production
  # App-specific
  - check hey logs
  - check bc4 logs
  - check fizzy logs
  - check launchpad logs
  - check queenbee logs
  - hey is slow
  - bc4 is slow
  - fizzy is slow
  # Grafana
  - grafana
  - check grafana
  - look at metrics
  - check metrics
  - check logs
  - check loki
  - check traces
  - check tempo
  - query prometheus
  - query loki
  # Sentry
  - check sentry
  - sentry errors
  - error tracking
  # General debugging
  - why is X slow
  - what's causing errors
  - find the bottleneck
  - latency investigation
  - error rate spike
  - performance investigation
---

# observability

Open `@references/guide.md` and follow it. Do not proceed without it.

Investigate production issues at 37signals using the observability stack: Prometheus metrics, Loki logs, Tempo traces, and Sentry errors.

The guide contains:
- Investigation workflow (metrics → logs → traces → errors)
- App identifiers and datasource configs
- Ready-to-use query templates for each tool
- Token management rules for Loki
- Eval checks and failure modes
