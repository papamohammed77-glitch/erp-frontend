-- CountFlow is an isolated application surface. RLS is not a substitute
-- for revoking TRUNCATE / REFERENCES / TRIGGER, which are not row-filtered.
REVOKE ALL PRIVILEGES ON TABLE
  public.count_alerts, public.count_anomaly_rules, public.count_assignments,
  public.count_audit_log, public.count_devices, public.count_entries,
  public.count_entry_images, public.count_expected_balances, public.count_exports,
  public.count_import_batches, public.count_import_mappings, public.count_import_rows,
  public.count_locations, public.count_members, public.count_presence,
  public.count_products, public.count_projects, public.count_reconciliation_lines,
  public.count_reconciliation_runs, public.count_recount_tasks, public.count_sessions
FROM anon;

REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE
  public.count_alerts, public.count_anomaly_rules, public.count_assignments,
  public.count_audit_log, public.count_devices, public.count_entries,
  public.count_entry_images, public.count_expected_balances, public.count_exports,
  public.count_import_batches, public.count_import_mappings, public.count_import_rows,
  public.count_locations, public.count_members, public.count_presence,
  public.count_products, public.count_projects, public.count_reconciliation_lines,
  public.count_reconciliation_runs, public.count_recount_tasks, public.count_sessions
FROM authenticated;

REVOKE EXECUTE ON FUNCTION public.count_is_member(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.count_is_supervisor(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.countflow_broadcast_changes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_is_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_is_supervisor(uuid) TO authenticated;
