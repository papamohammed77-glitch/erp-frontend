-- RAWAEA: make unresolved return discrepancies a database-enforced close barrier.
-- The gate covers both return completion and cancellation, prevents late reports,
-- and serializes report/status changes against the parent runsheet row.
-- No operational rows are inserted or updated by this migration.

ALTER TABLE public.stock_discrepancies
  ALTER COLUMN company_id SET NOT NULL,
  ALTER COLUMN reported_by SET NOT NULL,
  ALTER COLUMN status SET DEFAULT 'pending',
  ALTER COLUMN status SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_stock_discrepancies_open_runsheet
  ON public.stock_discrepancies (company_id, runsheet_id)
  WHERE status IN ('pending', 'investigating');

CREATE OR REPLACE FUNCTION public.guard_stock_discrepancy_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_company_id uuid;
  v_runsheet_status text;
  v_return_handler_id uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.company_id IS NULL OR NEW.runsheet_id IS NULL OR NEW.reported_by IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'بلاغ الاختلاف يتطلب الشركة والرانشيت والمستخدم المبلّغ';
    END IF;

    IF NEW.status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'يجب إنشاء بلاغ الاختلاف بحالة pending ثم مراجعته عبر دورة الاعتماد';
    END IF;

    SELECT r.company_id, r.status, r.return_handler_id
      INTO v_company_id, v_runsheet_status, v_return_handler_id
      FROM public.runsheets AS r
     WHERE r.id = NEW.runsheet_id
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = '23503',
        MESSAGE = 'الرانشيت المرتبط ببلاغ الاختلاف غير موجود';
    END IF;

    IF v_company_id IS DISTINCT FROM NEW.company_id THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'الشركة في بلاغ الاختلاف لا تطابق شركة الرانشيت';
    END IF;

    IF v_runsheet_status IS DISTINCT FROM 'Returning' THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'لا يمكن تسجيل اختلاف إلا أثناء جلسة مرتجعات نشطة';
    END IF;

    IF v_return_handler_id IS DISTINCT FROM NEW.reported_by THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'مبلّغ الاختلاف ليس مسؤول المرتجعات المسند إليه الرانشيت';
    END IF;

    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.company_id IS DISTINCT FROM OLD.company_id
       OR NEW.runsheet_id IS DISTINCT FROM OLD.runsheet_id
       OR NEW.reported_by IS DISTINCT FROM OLD.reported_by THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'لا يمكن تغيير هوية الشركة أو الرانشيت أو المبلّغ في سجل الاختلاف';
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status THEN
      IF NEW.status IS NULL THEN
        RAISE EXCEPTION USING
          ERRCODE = '23514',
          MESSAGE = 'حالة بلاغ الاختلاف لا يمكن أن تكون فارغة';
      END IF;

      IF OLD.status = 'resolved' AND NEW.status <> 'resolved' THEN
        RAISE EXCEPTION USING
          ERRCODE = '23514',
          MESSAGE = 'لا يمكن إعادة فتح بلاغ اختلاف تم حسمه؛ سجّل بلاغًا جديدًا أثناء جلسة مرتجعات نشطة';
      END IF;

      IF NEW.status IN ('pending', 'investigating') THEN
        SELECT r.company_id, r.status
          INTO v_company_id, v_runsheet_status
          FROM public.runsheets AS r
         WHERE r.id = NEW.runsheet_id
         FOR UPDATE;

        IF NOT FOUND OR v_company_id IS DISTINCT FROM NEW.company_id THEN
          RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'الرانشيت المرتبط ببلاغ الاختلاف غير متاح ضمن الشركة';
        END IF;

        IF v_runsheet_status IS DISTINCT FROM 'Returning' THEN
          RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'لا يمكن إبقاء بلاغ الاختلاف غير محسوم بعد إغلاق جلسة المرتجعات';
        END IF;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_stock_discrepancy_integrity() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_stock_discrepancies_integrity
  ON public.stock_discrepancies;

CREATE TRIGGER trg_stock_discrepancies_integrity
BEFORE INSERT OR UPDATE OF status, company_id, runsheet_id, reported_by
ON public.stock_discrepancies
FOR EACH ROW
EXECUTE FUNCTION public.guard_stock_discrepancy_integrity();

CREATE OR REPLACE FUNCTION public.prevent_runsheet_close_with_unresolved_discrepancies()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF OLD.status = 'Returning'
     AND NEW.status IS DISTINCT FROM OLD.status
     AND EXISTS (
       SELECT 1
         FROM public.stock_discrepancies AS d
        WHERE d.company_id = OLD.company_id
          AND d.runsheet_id = OLD.id
          AND d.status IN ('pending', 'investigating')
     ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '23514',
      MESSAGE = 'لا يمكن إغلاق أو إلغاء جلسة المرتجعات قبل حسم جميع بلاغات الاختلاف المعلقة أو قيد المراجعة';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.prevent_runsheet_close_with_unresolved_discrepancies() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_runsheets_unresolved_discrepancy_close_guard
  ON public.runsheets;

CREATE TRIGGER trg_runsheets_unresolved_discrepancy_close_guard
BEFORE UPDATE OF status
ON public.runsheets
FOR EACH ROW
WHEN (OLD.status = 'Returning' AND NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION public.prevent_runsheet_close_with_unresolved_discrepancies();

-- Use the permissions already stored on actual RAWAEA roles. The old policy
-- compared the Arabic users.role field to English labels that do not exist.
DROP POLICY IF EXISTS "Warehouse users read scoped return discrepancies"
  ON public.stock_discrepancies;

CREATE POLICY "Warehouse users read scoped return discrepancies"
ON public.stock_discrepancies
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
      FROM public.users AS u
     WHERE u.auth_id = (SELECT auth.uid())
       AND u.company_id = stock_discrepancies.company_id
       AND lower(coalesce(u.status, 'active')) = 'active'
       AND (
         u.id = stock_discrepancies.reported_by
         OR EXISTS (
           SELECT 1
             FROM public.runsheets AS rs
            WHERE rs.id = stock_discrepancies.runsheet_id
              AND rs.company_id = u.company_id
              AND rs.return_handler_id = u.id
         )
         OR (SELECT app_private.current_user_has_permission('warehouse_supervisor'))
         OR (SELECT app_private.current_user_has_permission('warehouse_manager'))
       )
  )
);

DROP POLICY IF EXISTS "Company supervisors update scoped return discrepancies"
  ON public.stock_discrepancies;

CREATE POLICY "Company supervisors update scoped return discrepancies"
ON public.stock_discrepancies
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
      FROM public.users AS u
     WHERE u.auth_id = (SELECT auth.uid())
       AND u.company_id = stock_discrepancies.company_id
       AND lower(coalesce(u.status, 'active')) = 'active'
  )
  AND (
    (SELECT app_private.current_user_has_permission('warehouse_supervisor'))
    OR (SELECT app_private.current_user_has_permission('warehouse_manager'))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
      FROM public.users AS u
     WHERE u.auth_id = (SELECT auth.uid())
       AND u.company_id = stock_discrepancies.company_id
       AND lower(coalesce(u.status, 'active')) = 'active'
  )
  AND (
    (SELECT app_private.current_user_has_permission('warehouse_supervisor'))
    OR (SELECT app_private.current_user_has_permission('warehouse_manager'))
  )
);

COMMENT ON FUNCTION public.guard_stock_discrepancy_integrity()
  IS 'Serializes discrepancy creation/reopening against its runsheet and binds the report to the current assigned return handler.';

COMMENT ON FUNCTION public.prevent_runsheet_close_with_unresolved_discrepancies()
  IS 'Prevents cancelling or completing a Returning runsheet while any discrepancy is pending or investigating.';

COMMENT ON TRIGGER trg_stock_discrepancies_integrity ON public.stock_discrepancies
  IS 'Validates tenant, session, reporter identity, and resolved-state finality before discrepancy writes.';

COMMENT ON TRIGGER trg_runsheets_unresolved_discrepancy_close_guard ON public.runsheets
  IS 'Blocks every transition out of Returning while its discrepancy queue contains unresolved rows.';
