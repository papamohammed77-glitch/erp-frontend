ALTER TABLE public.count_expected_balances
  ADD CONSTRAINT count_expected_balances_nonnegative_qty_ck CHECK (expected_quantity>=0);

CREATE OR REPLACE FUNCTION counting_private.guard_expected_balance_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_session_id uuid; v_product_id uuid; v_project_id uuid;
  v_session_project uuid; v_session_status text; v_base_unit text;
BEGIN
  IF TG_OP='DELETE' THEN
    v_session_id:=OLD.session_id; v_product_id:=OLD.product_id; v_project_id:=OLD.project_id;
  ELSE
    v_session_id:=NEW.session_id; v_product_id:=NEW.product_id; v_project_id:=NEW.project_id;
  END IF;
  SELECT project_id,status INTO v_session_project,v_session_status
  FROM public.count_sessions WHERE id=v_session_id FOR UPDATE;
  IF NOT FOUND OR v_session_project<>v_project_id THEN RAISE EXCEPTION 'EXPECTED_BALANCE_SESSION_SCOPE_INVALID'; END IF;
  SELECT base_unit INTO v_base_unit FROM public.count_products WHERE id=v_product_id AND project_id=v_project_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'EXPECTED_BALANCE_PRODUCT_SCOPE_INVALID'; END IF;
  IF TG_OP<>'DELETE' THEN
    IF NEW.unit IS DISTINCT FROM v_base_unit THEN RAISE EXCEPTION 'EXPECTED_BALANCE_MUST_USE_BASE_UNIT:%',v_base_unit; END IF;
    IF NEW.expected_quantity<0 THEN RAISE EXCEPTION 'EXPECTED_BALANCE_NEGATIVE_NOT_ALLOWED'; END IF;
  END IF;
  IF EXISTS(SELECT 1 FROM public.count_entries WHERE session_id=v_session_id) THEN
    RAISE EXCEPTION 'EXPECTED_BALANCES_LOCKED_AFTER_FIRST_COUNT';
  END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs WHERE session_id=v_session_id) THEN
    RAISE EXCEPTION 'EXPECTED_BALANCES_LOCKED_AFTER_RECONCILIATION';
  END IF;
  IF v_session_status IN ('review','completed') THEN RAISE EXCEPTION 'EXPECTED_BALANCES_SESSION_FINALIZED'; END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.guard_expected_balance_mutation() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS count_expected_balances_snapshot_guard ON public.count_expected_balances;
CREATE TRIGGER count_expected_balances_snapshot_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.count_expected_balances
FOR EACH ROW EXECUTE FUNCTION counting_private.guard_expected_balance_mutation();
