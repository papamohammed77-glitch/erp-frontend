# CountFlow database migrations

The live project is Supabase `rawaea-staging` (`hfzznsiprnwkpayskzhu`). The following SQL files are the reviewed source artifacts for the CountFlow database changes.

## Migration sequence represented in this repository

1. `20261119190750_countflow_revoke_unsafe_anon_and_ddl_privileges.sql` — removes anon access and dangerous DDL-style grants from CountFlow tables.
2. `20261119191119_countflow_reconciliation_approved_recount_override_v1.sql` — establishes the approved recount override path.
3. `20261119191232_countflow_unit_conversion_snapshots_and_effective_totals_v1.sql` — stores conversion snapshots and computes effective quantities using the latest approved recount.
4. `20261119191603_countflow_remove_exposed_security_definer_helpers.sql` — removes unused public SECURITY DEFINER wrappers from the client RPC surface.
5. `20261119191833_countflow_automatic_anomaly_alerts_v1.sql` — creates automatic quantity/repeat alerts and evaluates variance alerts during reconciliation.
6. `20261119191854_countflow_fix_repeat_alert_uuid_aggregate.sql` — fixes UUID aggregation in repeat-scan alert evaluation.
7. `20261119192509_countflow_approval_requires_all_positions_counted.sql` — consolidated final reconciliation/approval contract. It represents the final state of the incremental live patches recorded between migration versions 19192305 and 19192509: entry-count watermark, serialized session lock, latest-run check, uncounted-position guard, open-task/critical-alert gates, and session freeze after approval.
8. `20261119192958_countflow_live_kpi_and_alert_index_tuning_v1.sql` — materializes effective-count aggregation once for live KPIs and adds targeted repeat-alert lookup indexes.
9. `20261119193513_countflow_assignments_nulls_not_distinct_unique_scope_v1.sql` — replaces the partial/global assignment indexes with one `NULLS NOT DISTINCT` unique index so global and location-specific assignments can be upserted atomically.
10. `20261119193620_countflow_expected_balance_snapshot_guard_v1.sql` — requires expected balances to use the product base unit and freezes them after the first count or reconciliation.

## Operational rules

- Do not rerun these migrations blindly against a database with existing objects. Compare the Supabase migration ledger and live definitions first.
- These migrations only alter CountFlow objects and do not post or modify ERP stock, treasury, or accounting balances.
- Test fixtures in `../../tests/*_rollback.sql` create temporary Auth and CountFlow rows inside a transaction and finish with `ROLLBACK`.
- Keep Supabase migration history and this repository's SQL artifacts aligned when making future changes.
