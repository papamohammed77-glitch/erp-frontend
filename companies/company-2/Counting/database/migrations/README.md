# CountFlow database migrations

Live project: Supabase rawaea-staging (hfzznsiprnwkpayskzhu). Scope is CountFlow objects only.

## SQL artifacts currently tracked in Git (17)

1. 20261119190750_countflow_revoke_unsafe_anon_and_ddl_privileges.sql
2. 20261119191119_countflow_reconciliation_approved_recount_override_v1.sql
3. 20261119191232_countflow_unit_conversion_snapshots_and_effective_totals_v1.sql
4. 20261119191603_countflow_remove_exposed_security_definer_helpers.sql
5. 20261119191833_countflow_automatic_anomaly_alerts_v1.sql
6. 20261119191854_countflow_fix_repeat_alert_uuid_aggregate.sql
7. 20261119192509_countflow_approval_requires_all_positions_counted.sql
8. 20261119192958_countflow_live_kpi_and_alert_index_tuning_v1.sql
9. 20261119193513_countflow_assignments_nulls_not_distinct_unique_scope_v1.sql
10. 20261119193620_countflow_expected_balance_snapshot_guard_v1.sql
11. 20261119194632_countflow_admin_audit_triggers_v1.sql
12. 20261119194738_countflow_audit_skip_service_member_provision_v1.sql
13. 20261119195303_countflow_rpc_and_immutable_ledger_acl_hardening_v1.sql
14. 20261119195630_countflow_import_batch_sku_lookup_index_v1.sql
15. 20261120170000_countflow_platform_owner_verified_email.sql
16. 20261120171000_countflow_license_settings_unbounded_emails.sql
17. 20261120200000_countflow_atomic_engagement_and_operation_create.sql

## Live migration ledger reconciliation — 2026-11-19

Read-only comparison of the Supabase migration ledger against the current Git folder found:

- Latest read-only ledger query (2026-11-20): **56** applied `countflow_*` entries and **12** earlier `counting_*` entries, **68 combined CountFlow/Counting migration entries**.
- **17** SQL migration files are tracked in this repository.
- The three new migration names are present in the live ledger. The connector generated live version timestamps `20261119232523`, `20261119232615`, and `20261120004422` for the named owner, license-settings and atomic-engagement migrations respectively; do not infer ledger version from the filename.
- **51** applied CountFlow/Counting ledger entries have no standalone one-to-one SQL source in the current Git folder. The previously recorded 7-foundation/60-total figure in the 2026-11-19 archive is retained as historical evidence but is superseded by this latest catalog query, which identifies 12 `counting_*` and 56 `countflow_*` names.
- The current folder is therefore NOT a complete replayable migration history or a clean-install baseline.

### Applied ledger entries without a standalone Git SQL artifact (39)

The missing entries are preserved below exactly as reported by the live ledger; do not recreate them from memory or reapply them blindly.

1. 20261119182050 countflow_enterprise_data_model_v1
2. 20261119182153 countflow_enterprise_security_storage_v1
3. 20261119182705 countflow_import_pipeline_v1
4. 20261119182926 countflow_import_pipeline_hardening_v1
5. 20261119183711 countflow_reconciliation_recount_presence_v1
6. 20261119183721 countflow_presence_rls_self_scope_fix
7. 20261119183927 countflow_import_image_and_presence_stream_v1
8. 20261119184026 countflow_fk_indexes_and_device_policy_consolidation
9. 20261119184103 countflow_import_uuid_location_lookup_fix
10. 20261119184201 countflow_kpis_and_anomaly_alert_engine_v1
11. 20261119184224 countflow_alerts_and_recount_realtime_publication
12. 20261119184230 countflow_import_image_reference_validation
13. 20261119184250 countflow_recount_entry_secure_rpc_v1
14. 20261119184532 countflow_recount_idempotency_retry_fix
15. 20261119184632 countflow_private_realtime_broadcast_architecture_v1
16. 20261119184706 countflow_recount_review_and_reconciliation_approval_v1
17. 20261119185002 countflow_evidence_owner_cleanup_policy
18. 20261119185027 countflow_session_project_broadcast_event
19. 20261119185123 countflow_import_mapping_relation_and_raw_source_preservation
20. 20261119185154 countflow_single_default_import_mapping_per_format
21. 20261119185210 countflow_all_location_assignment_uniqueness
22. 20261119185240 countflow_server_side_device_and_product_scope_enforcement
23. 20261119185300 countflow_assignment_scope_rls_and_enforcement
24. 20261119185320 countflow_device_realtime_broadcast
25. 20261119185755 countflow_member_data_isolation_and_audit_write_restriction
26. 20261119185811 countflow_evidence_storage_member_scope
27. 20261119185920 countflow_append_only_insert_policy_full_validation
28. 20261119185943 countflow_device_status_supervisor_only
29. 20261119190029 countflow_first_device_autoapproval_and_new_device_supervisor_gate
30. 20261119190037 countflow_persist_pending_device_registration
31. 20261119190249 countflow_fk_and_duplicate_index_advisor_fixes
32. 20261119190309 countflow_realtime_evidence_and_location_updates
33. 20261119190448 countflow_idempotent_retries_after_member_pause
34. 20261119192305 countflow_reconciliation_approval_freeze_v1
35. 20261119192405 countflow_atomic_reconciliation_freeze_watermark_v1
36. 20261119192409 countflow_approved_session_insert_error_order_fix
37. 20261119192427 countflow_count_entry_guard_definer_lock_fix
38. 20261119195107 countflow_location_hierarchy_guard_and_session_heatmap_v1
39. 20261119195202 countflow_session_heatmap_helper_contract_fix_v1

### Special mappings / caveats

- The four approval/freeze entries 19192305, 19192405, 19192409, and 19192427 are described in the existing migration documentation as consolidated into the final tracked contract 19192509. Their ledger entries still exist; the consolidated file is not proof that the original SQL text is preserved.
- The location hierarchy/heatmap migrations 19195107 and 19195202 are applied in Supabase but absent from Git. Their exact original SQL must be recovered from execution artifacts if available. Do not invent a replacement migration from the current catalog.
- The tracked source file 19195630_countflow_import_batch_sku_lookup_index_v1.sql corresponds by name to live ledger version 20261119195750. The index exists in the live catalog. Record this as timestamp mapping drift; do not rename or reapply without a reviewed lineage decision.
- The prior README listed only 12 files and stated 19194738 as latest. That statement was stale as of this audit.

## Safety rules

- Do not rerun these migrations blindly against a database with existing objects.
- Do not apply DDL, ACL, RLS, GRANT, REVOKE, or Edge deployment without a specific approved Change Set.
- Rollback tests must begin with BEGIN and finish with ROLLBACK; prove no residual CountFlow rows or Auth identities.
- CountFlow SQL must not write to ERP inventory, sales, treasury, customer/supplier ledgers, or accounting tables.
- No legacy ERP table/function/policy in rawaea-staging may be changed under this CountFlow scope.


## 2026-11-19 — live migration-ledger recovery

A read-only reconciliation against `supabase_migrations.schema_migrations` in `rawaea-staging` recovered the exact recorded SQL for all **60** migrations belonging to the CountFlow/Counting system: 7 earlier `counting_*` foundation rows plus 53 `countflow_*` rows.

- The current folder still contains 14 standalone SQL files. There are 46 applied ledger rows without a one-to-one standalone file (39 within the `countflow_*` set plus the 7 foundation rows).
- The exact applied statements are preserved in [COUNTFLOW_APPLIED_MIGRATION_LEDGER_ARCHIVE_20261119.md](../COUNTFLOW_APPLIED_MIGRATION_LEDGER_ARCHIVE_20261119.md).
- **The archive is evidence only. Do not apply or replay it.** The ledger has no rollback SQL recorded for these 60 rows.
- A whitespace/comment-insensitive SQL-token comparison found 4 of the 14 tracked files equivalent to their matching ledger statement; the other 10 require semantic reconciliation before anyone treats the tracked file as the exact applied source.
- `20261119195630_countflow_import_batch_sku_lookup_index_v1.sql` maps to live ledger version `20261119195750`; this is timestamp drift. `20261119192509_countflow_approval_requires_all_positions_counted.sql` is a consolidated source for incremental finality changes, not a one-to-one copy of a single ledger row.

Do not replay, rename, or rewrite any migration based only on its filename. Use the live schema and the archived applied statements as separate evidence sources.


## 2026-11-20 — CountFlow engagement and operation workflow additions

The following CountFlow-only migrations were applied and their source files committed:

- `20261120170000_countflow_platform_owner_verified_email.sql`: global owner identity gate bound to the confirmed Auth email `owner@rawaea.com`.
- `20261120171000_countflow_license_settings_unbounded_emails.sql`: owner-only license/contact email settings; no application-level list cap.
- `20261120200000_countflow_atomic_engagement_and_operation_create.sql`: SECURITY INVOKER RPC to atomically create the contracting-party engagement workspace and its first named count operation.

The latest function/ACL verification confirmed authenticated EXECUTE=true and anon EXECUTE=false for `public.count_create_engagement(text,text,text)`. No test engagement or Auth identity was created. These migrations do not touch ERP objects.
