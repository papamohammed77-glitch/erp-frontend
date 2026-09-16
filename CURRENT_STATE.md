# RAWAEA ERP — CURRENT STATE

> هذا الملف هو Living Execution State وليس مصدرًا أعمى للحالة الحالية. يجب دائمًا مطابقة محتواه مع CURRENT GIT + CURRENT SOURCE + CURRENT PRODUCTION + CURRENT DATABASE + CURRENT DEPLOYMENT EVIDENCE.

## Current Session

- **Date:** 2026-09-16
- **Current repository:** `papamohammed77-glitch/erp-frontend`
- **Source of Truth:** `companies/company-1/main.html`
- **Main HEAD:** `6b3b500f2da361b1522f6e9f33d87f64cb0e8114`
- **HEAD message:** `Refactor functions to use RW_Finance namespace`
- **HEAD parent:** `2af93b03a0bc5c46e2126d329154c6d176f0d098`
- **Current main extract:** 24,134 lines; SHA256 `06452de29b1a55c7e3a63a50c7267c70561d93cca4743c84c2387767b11da675`

## Current Verified Findings

### Mother Finance Console defects

1. `main:14542 Uncaught ReferenceError: _renderPeriods is not defined`
   - Root cause: commit `6b3...` changed eight internal renderer calls to `RW_Finance._render...`, but those renderer functions are not exposed under those names.
   - Correct owner fix: restore the parent commit's internal calls in that exact eight-line dispatcher block.

2. `RW_Finance._goldOpenPeriod is not a function`
3. `RW_Finance._goldAddAsset is not a function`
4. `RW_Finance._goldTaxCode is not a function`
   - Root cause: Gold Extension exports `gold*` functions, while public `RW_Finance` only had `_goldJournalList` bound.
   - Correct owner fix: add explicit `_gold*` aliases at the final namespace binding.

5. `get_budget_vs_actual` returned HTTP 403 from the REST RPC path.
   - Production function exists and is company-context aware.
   - Root cause proven from `information_schema.routine_privileges`: `authenticated` lacked EXECUTE.
   - Production fix applied: grant EXECUTE to `authenticated` and `service_role`; revoke PUBLIC/anon.
   - Authenticated DB-context verification passed in transaction.

## Production Change Applied

```sql
BEGIN;
REVOKE ALL ON FUNCTION public.get_budget_vs_actual(integer,integer,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_budget_vs_actual(integer,integer,uuid) TO authenticated, service_role;
COMMIT;
```

## Current Architecture Decision

- `forensic_main_assembly.yml` is already correct and points to:
  - repository: `papamohammed77-glitch/erp-frontend`
  - path: `companies/company-1/main.html`
  - ref: `main`
  - `published_main_is_authoritative`
  - `historical_reference_only` for fragments.
- `Current/PWA/main2` remains historical/advisory only.
- Mother `main.html` was **not edited by the assistant**; owner applies surgical source changes.
- Production changes are performed directly by the assistant when proven necessary.

## Current Owner Action Required

Apply the surgical changes documented in:

`doc/Draft/Reprots/Report217_MOTHER_FINANCE_FORENSIC_E2E_20260916.md`

Required source changes:

- CHANGE A: restore the eight internal `RW_Finance` renderer calls at the dispatcher around line 14542.
- CHANGE B: bind all required `_gold*` aliases to `RW_Finance_GoldExtension`.
- Apply the modal UX replacements specified in the same report before declaring the source-side Finance E2E closure.

## What Is Closed

- Production permission root cause for `get_budget_vs_actual`: **CLOSED / PRODUCTION VERIFIED**.
- `forensic_main_assembly.yml` source-of-truth path: **VERIFIED**.

## What Is Not Yet Closed

- Real browser E2E after owner applies CHANGE A/B.
- Visual/interactive validation of the improved asset/tax/disposal/period modals.
- Final Finance E2E zero-console-error pass.

## Required Next Session Start

1. Read this file, but verify all claims against current sources.
2. Check the latest `erp-frontend` commit and its parent.
3. Open current `companies/company-1/main.html`.
4. Confirm CHANGE A and CHANGE B were actually applied; do not repair them again if already present.
5. Open Finance and execute real clicks in the browser.
6. Capture the exact first new Console error and trace it to source → public export → RPC → Production.
7. Re-check Production function signatures and privileges before any backend edit.
8. Only then proceed to the next open Finance closure unit.

## Continuity Rule

No previous report, assistant summary, or historical fragment overrides current Git/Source/Production/Database evidence.
