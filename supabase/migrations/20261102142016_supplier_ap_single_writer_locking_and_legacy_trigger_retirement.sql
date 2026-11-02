-- LVE-579: make Supplier AP projection single-writer and concurrency-safe.
-- Production migration version: 20261102142016
-- Rollback trigger recreation:
-- CREATE TRIGGER trg_sync_supplier_accounts_payable
-- AFTER INSERT OR DELETE OR UPDATE ON public.supplier_ledger
-- FOR EACH ROW EXECUTE FUNCTION public.sync_supplier_accounts_payable_from_ledger();

CREATE OR REPLACE FUNCTION app_private.sync_supplier_accounts_payable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_old_supplier_id uuid;
  v_new_supplier_id uuid;
  v_lock_supplier_id uuid;
  v_total numeric;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_old_supplier_id := OLD.supplier_id;
  ELSE
    v_new_supplier_id := NEW.supplier_id;
    IF TG_OP = 'UPDATE' THEN
      v_old_supplier_id := OLD.supplier_id;
    END IF;
  END IF;

  -- Lock affected suppliers in deterministic UUID order before calculating
  -- the projection. Under READ COMMITTED, the following SUM statements then
  -- see ledger rows committed by transactions that released these locks.
  FOR v_lock_supplier_id IN
    SELECT DISTINCT ids.supplier_id
    FROM unnest(ARRAY[v_old_supplier_id, v_new_supplier_id]) AS ids(supplier_id)
    WHERE ids.supplier_id IS NOT NULL
    ORDER BY ids.supplier_id
  LOOP
    PERFORM 1
    FROM public.suppliers AS s
    WHERE s.id = v_lock_supplier_id
    FOR UPDATE;
  END LOOP;

  -- A reassignment must recalculate both the old and new supplier projections.
  IF v_old_supplier_id IS NOT NULL
     AND v_old_supplier_id IS DISTINCT FROM v_new_supplier_id THEN
    SELECT COALESCE(SUM(sl.credit - sl.debit), 0)
      INTO v_total
    FROM public.supplier_ledger AS sl
    WHERE sl.supplier_id = v_old_supplier_id;

    UPDATE public.suppliers AS s
       SET accounts_payable = v_total,
           updated_at = now()
     WHERE s.id = v_old_supplier_id;
  END IF;

  IF v_new_supplier_id IS NOT NULL THEN
    SELECT COALESCE(SUM(sl.credit - sl.debit), 0)
      INTO v_total
    FROM public.supplier_ledger AS sl
    WHERE sl.supplier_id = v_new_supplier_id;

    UPDATE public.suppliers AS s
       SET accounts_payable = v_total,
           updated_at = now()
     WHERE s.id = v_new_supplier_id;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_supplier_accounts_payable
ON public.supplier_ledger;
