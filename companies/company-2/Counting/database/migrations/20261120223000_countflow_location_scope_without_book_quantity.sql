-- CountFlow: separate operation/location count scope from optional expected quantity.
-- A known location with no book balance remains in scope and must be counted; NULL is never coerced to zero.
ALTER TABLE public.count_expected_balances
  ALTER COLUMN expected_quantity DROP NOT NULL;

ALTER TABLE public.count_reconciliation_lines
  ADD COLUMN expected_scope boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.count_commit_import_batch(p_batch_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_batch public.count_import_batches;
  v_row public.count_import_rows;
  v_product public.count_products;
  v_match_ids uuid[];
  v_match_count integer;
  v_product_id uuid;
  v_sku text;
  v_barcode text;
  v_name text;
  v_category text;
  v_unit text;
  v_image_url text;
  v_location_id uuid;
  v_location_count integer;
  v_error text;
  v_accepted integer;
  v_rejected integer;
  v_expected integer;
BEGIN
  SELECT * INTO v_batch
  FROM public.count_import_batches
  WHERE id = p_batch_id
  FOR UPDATE;

  IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
    RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
  END IF;

  IF v_batch.status = 'committed' THEN
    RETURN jsonb_build_object(
      'batch_id',p_batch_id,'status','committed',
      'accepted_rows',v_batch.accepted_count,
      'rejected_rows',v_batch.rejected_count,
      'idempotent',true
    );
  END IF;
  IF v_batch.status <> 'preview' THEN
    RAISE EXCEPTION 'IMPORT_BATCH_NOT_READY';
  END IF;

  UPDATE public.count_import_batches
  SET status='committing', updated_at=now()
  WHERE id=p_batch_id;

  IF v_batch.session_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.count_sessions s
    WHERE s.id=v_batch.session_id
      AND s.project_id=v_batch.project_id
      AND s.status IN ('planned','active','paused','review')
  ) THEN
    RAISE EXCEPTION 'INVALID_IMPORT_SESSION_AT_COMMIT';
  END IF;

  FOR v_row IN
    SELECT * FROM public.count_import_rows
    WHERE batch_id=p_batch_id AND row_status='staged'
    ORDER BY row_number, id
    FOR UPDATE
  LOOP
    v_error := NULL;
    v_product_id := NULL;
    v_sku := nullif(btrim(v_row.sku),'');
    v_barcode := nullif(btrim(v_row.barcode),'');
    v_name := nullif(btrim(v_row.product_name),'');
    v_category := nullif(btrim(v_row.category),'');
    v_unit := nullif(btrim(v_row.base_unit),'');
    v_image_url := nullif(btrim(v_row.image_url),'');
    v_location_id := v_row.location_id;

    IF v_sku IS NULL AND v_barcode IS NULL THEN
      v_error := 'MISSING_PRODUCT_IDENTIFIER';
    ELSIF v_unit IS NOT NULL AND length(v_unit)>40 THEN
      v_error := 'BASE_UNIT_TOO_LONG';
    ELSIF v_name IS NOT NULL AND length(v_name)>200 THEN
      v_error := 'PRODUCT_NAME_TOO_LONG';
    ELSIF v_sku IS NOT NULL AND length(v_sku)>160 THEN
      v_error := 'SKU_TOO_LONG';
    ELSIF v_barcode IS NOT NULL AND length(v_barcode)>120 THEN
      v_error := 'BARCODE_TOO_LONG';
    ELSIF v_row.expected_quantity IS NOT NULL AND (
      v_row.expected_quantity < 0 OR v_batch.session_id IS NULL
    ) THEN
      v_error := 'INVALID_EXPECTED_QUANTITY';
    ELSIF v_image_url IS NOT NULL AND (
      length(v_image_url)>2048
      OR (v_image_url ~* '^[a-z][a-z0-9+.-]*://' AND v_image_url !~* '^https://')
      OR v_image_url LIKE '/%'
      OR v_image_url LIKE '%..%'
    ) THEN
      v_error := 'INVALID_IMAGE_REFERENCE';
    END IF;

    IF v_error IS NULL AND v_row.location_code IS NOT NULL THEN
      SELECT count(*), (array_agg(id))[1]
      INTO v_location_count, v_location_id
      FROM public.count_locations
      WHERE project_id=v_batch.project_id
        AND code=v_row.location_code;
      IF v_location_count <> 1 THEN
        v_error := CASE WHEN v_location_count=0
          THEN 'UNKNOWN_LOCATION_CODE_AT_COMMIT'
          ELSE 'AMBIGUOUS_LOCATION_CODE_AT_COMMIT' END;
      END IF;
    ELSIF v_error IS NULL AND v_location_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.count_locations l
      WHERE l.id=v_location_id AND l.project_id=v_batch.project_id
    ) THEN
      v_error := 'LOCATION_OUTSIDE_ENGAGEMENT';
    END IF;

    IF v_error IS NULL AND (
      (v_sku IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.count_import_rows prior
        WHERE prior.batch_id=p_batch_id
          AND prior.row_status='committed'
          AND prior.id<>v_row.id
          AND lower(btrim(prior.sku))=lower(v_sku)
          AND nullif(btrim(prior.location_code),'') IS NOT DISTINCT FROM nullif(btrim(v_row.location_code),'')
      ))
      OR
      (v_barcode IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.count_import_rows prior
        WHERE prior.batch_id=p_batch_id
          AND prior.row_status='committed'
          AND prior.id<>v_row.id
          AND btrim(prior.barcode)=v_barcode
          AND nullif(btrim(prior.location_code),'') IS NOT DISTINCT FROM nullif(btrim(v_row.location_code),'')
      ))
    ) THEN
      v_error := 'DUPLICATE_PRODUCT_IDENTIFIER_AT_SAME_LOCATION';
    END IF;

    IF v_error IS NULL THEN
      SELECT array_agg(p.id ORDER BY p.id)
      INTO v_match_ids
      FROM public.count_products p
      WHERE p.project_id=v_batch.project_id
        AND (
          (v_sku IS NOT NULL AND lower(btrim(p.sku))=lower(v_sku))
          OR (v_barcode IS NOT NULL AND btrim(p.barcode)=v_barcode)
        );
      v_match_count := coalesce(array_length(v_match_ids,1),0);

      IF v_match_count > 1 THEN
        v_error := 'PRODUCT_IDENTITY_MATCHES_MULTIPLE_PRODUCTS';
      ELSIF v_match_count = 1 THEN
        SELECT * INTO v_product
        FROM public.count_products
        WHERE id=v_match_ids[1]
        FOR UPDATE;
        IF v_unit IS NULL THEN v_unit := v_product.base_unit; END IF;

        IF v_sku IS NOT NULL AND v_product.sku IS NOT NULL
           AND lower(btrim(v_product.sku))<>lower(v_sku) THEN
          v_error := 'SKU_CONFLICT_FOR_MATCHED_PRODUCT';
        ELSIF v_barcode IS NOT NULL AND v_product.barcode IS NOT NULL
           AND btrim(v_product.barcode)<>v_barcode THEN
          v_error := 'BARCODE_CONFLICT_FOR_MATCHED_PRODUCT';
        ELSIF v_unit IS DISTINCT FROM v_product.base_unit AND (
          EXISTS (SELECT 1 FROM public.count_entries e WHERE e.product_id=v_product.id)
          OR EXISTS (SELECT 1 FROM public.count_expected_balances b WHERE b.product_id=v_product.id)
        ) THEN
          v_error := 'BASE_UNIT_LOCKED_BY_EXISTING_COUNT_SNAPSHOT';
        ELSE
          BEGIN
            UPDATE public.count_products
            SET sku=coalesce(v_product.sku,v_sku),
                barcode=coalesce(v_product.barcode,v_barcode),
                name=coalesce(v_name,v_product.name),
                category=coalesce(v_category,v_product.category),
                base_unit=v_unit,
                units=CASE
                  WHEN v_row.units IS NULL OR v_row.units='[]'::jsonb
                    THEN v_product.units
                  ELSE v_row.units
                END,
                image_url=coalesce(v_image_url,v_product.image_url),
                updated_at=now()
            WHERE id=v_product.id
            RETURNING id INTO v_product_id;
          EXCEPTION WHEN unique_violation THEN
            v_error := 'PRODUCT_IDENTIFIER_ALREADY_IN_USE';
          END;
        END IF;
      ELSE
        IF v_unit IS NULL THEN
          v_error := 'MISSING_BASE_UNIT_FOR_NEW_PRODUCT';
        ELSE
          BEGIN
            INSERT INTO public.count_products(
              project_id,sku,barcode,name,category,base_unit,units,
              image_url,is_active,updated_at
            ) VALUES (
              v_batch.project_id,v_sku,v_barcode,v_name,v_category,v_unit,
              coalesce(v_row.units,'[]'::jsonb),v_image_url,true,now()
            )
            RETURNING id INTO v_product_id;
          EXCEPTION WHEN unique_violation THEN
            v_error := 'PRODUCT_IDENTIFIER_ALREADY_IN_USE';
          END;
        END IF;
      END IF;
    END IF;

    IF v_error IS NOT NULL THEN
      UPDATE public.count_import_rows
      SET row_status='rejected',
          error_codes=array_append(coalesce(error_codes,ARRAY[]::text[]),v_error),
          error_detail=coalesce(error_detail,'{}'::jsonb)||jsonb_build_object(
            'commit_validation_error',v_error
          ),
          processed_at=now()
      WHERE id=v_row.id;
    ELSE
      UPDATE public.count_import_rows
      SET product_id=v_product_id,
          location_id=v_location_id,
          sku=v_sku,
          barcode=v_barcode,
          product_name=v_name,
          category=v_category,
          base_unit=v_unit,
          image_url=v_image_url,
          row_status='committed',
          processed_at=now()
      WHERE id=v_row.id;
    END IF;
  END LOOP;

  IF v_batch.session_id IS NOT NULL THEN
    INSERT INTO public.count_expected_balances(
      project_id,session_id,product_id,location_id,
      expected_quantity,unit,source_batch_id,snapshot_at,updated_at
    )
    SELECT
      v_batch.project_id,v_batch.session_id,r.product_id,r.location_id,
      r.expected_quantity,p.base_unit,p_batch_id,now(),now()
    FROM public.count_import_rows r
    JOIN public.count_products p ON p.id=r.product_id
    WHERE r.batch_id=p_batch_id
      AND r.row_status='committed'
      AND r.location_id IS NOT NULL
    ON CONFLICT(session_id,product_id,location_id) DO UPDATE SET
      expected_quantity=coalesce(EXCLUDED.expected_quantity,public.count_expected_balances.expected_quantity),
      unit=EXCLUDED.unit,
      source_batch_id=EXCLUDED.source_batch_id,
      snapshot_at=EXCLUDED.snapshot_at,
      updated_at=now();
  END IF;

  IF v_batch.session_id IS NOT NULL THEN
    -- A product may occur on multiple location rows. Persist one cost snapshot only
    -- when all supplied cost tuples in this batch are identical.
    WITH cost_conflicts AS (
      SELECT product_id
      FROM public.count_import_rows
      WHERE batch_id=p_batch_id AND row_status='committed'
        AND (
          purchase_unit_cost IS NOT NULL OR currency_code IS NOT NULL
          OR purchase_unit IS NOT NULL OR unit_factor_to_base IS NOT NULL
          OR cost_source_type IS NOT NULL OR cost_source_reference IS NOT NULL
          OR cost_source_date IS NOT NULL
        )
      GROUP BY product_id
      HAVING count(DISTINCT jsonb_build_array(
        purchase_unit_cost,currency_code,purchase_unit,unit_factor_to_base,
        cost_source_type,cost_source_reference,cost_source_date
      )::text)>1
    )
    UPDATE public.count_import_rows r
    SET warning_codes=array_append(coalesce(r.warning_codes,ARRAY[]::text[]),'CONFLICTING_COST_SNAPSHOT_IN_BATCH')
    FROM cost_conflicts c
    WHERE r.batch_id=p_batch_id AND r.row_status='committed' AND r.product_id=c.product_id
      AND NOT ('CONFLICTING_COST_SNAPSHOT_IN_BATCH'=ANY(coalesce(r.warning_codes,ARRAY[]::text[])));

    WITH cost_conflicts AS (
      SELECT product_id
      FROM public.count_import_rows
      WHERE batch_id=p_batch_id AND row_status='committed'
        AND (
          purchase_unit_cost IS NOT NULL OR currency_code IS NOT NULL
          OR purchase_unit IS NOT NULL OR unit_factor_to_base IS NOT NULL
          OR cost_source_type IS NOT NULL OR cost_source_reference IS NOT NULL
          OR cost_source_date IS NOT NULL
        )
      GROUP BY product_id
      HAVING count(DISTINCT jsonb_build_array(
        purchase_unit_cost,currency_code,purchase_unit,unit_factor_to_base,
        cost_source_type,cost_source_reference,cost_source_date
      )::text)>1
    )
    UPDATE public.count_session_product_costs c
    SET warning_codes=array_append(coalesce(c.warning_codes,ARRAY[]::text[]),'CONFLICTING_COST_SNAPSHOT_IN_BATCH'),
        updated_by=(SELECT auth.uid()),updated_at=now()
    FROM cost_conflicts x
    WHERE c.session_id=v_batch.session_id AND c.product_id=x.product_id
      AND NOT ('CONFLICTING_COST_SNAPSHOT_IN_BATCH'=ANY(coalesce(c.warning_codes,ARRAY[]::text[])));

    WITH cost_conflicts AS (
      SELECT product_id
      FROM public.count_import_rows
      WHERE batch_id=p_batch_id AND row_status='committed'
        AND (
          purchase_unit_cost IS NOT NULL OR currency_code IS NOT NULL
          OR purchase_unit IS NOT NULL OR unit_factor_to_base IS NOT NULL
          OR cost_source_type IS NOT NULL OR cost_source_reference IS NOT NULL
          OR cost_source_date IS NOT NULL
        )
      GROUP BY product_id
      HAVING count(DISTINCT jsonb_build_array(
        purchase_unit_cost,currency_code,purchase_unit,unit_factor_to_base,
        cost_source_type,cost_source_reference,cost_source_date
      )::text)>1
    ),
    one_cost_per_product AS (
      SELECT DISTINCT ON (r.product_id) r.*
      FROM public.count_import_rows r
      WHERE r.batch_id=p_batch_id AND r.row_status='committed'
        AND (
          r.purchase_unit_cost IS NOT NULL OR r.currency_code IS NOT NULL
          OR r.purchase_unit IS NOT NULL OR r.unit_factor_to_base IS NOT NULL
          OR r.cost_source_type IS NOT NULL OR r.cost_source_reference IS NOT NULL
          OR r.cost_source_date IS NOT NULL
        )
        AND NOT EXISTS (SELECT 1 FROM cost_conflicts c WHERE c.product_id=r.product_id)
      ORDER BY r.product_id,r.row_number DESC
    )
    INSERT INTO public.count_session_product_costs(
      project_id,session_id,product_id,purchase_unit_cost,currency_code,
      purchase_unit,unit_factor_to_base,source_type,source_reference,source_date,
      source_batch_id,warning_codes,created_by,updated_by
    )
    SELECT
      v_batch.project_id,v_batch.session_id,r.product_id,r.purchase_unit_cost,
      r.currency_code,r.purchase_unit,r.unit_factor_to_base,
      r.cost_source_type,r.cost_source_reference,r.cost_source_date,
      v_batch.id,coalesce(r.warning_codes,ARRAY[]::text[]),
      (SELECT auth.uid()),(SELECT auth.uid())
    FROM one_cost_per_product r
    ON CONFLICT(session_id,product_id) DO UPDATE SET
      purchase_unit_cost=coalesce(EXCLUDED.purchase_unit_cost,public.count_session_product_costs.purchase_unit_cost),
      currency_code=coalesce(EXCLUDED.currency_code,public.count_session_product_costs.currency_code),
      purchase_unit=coalesce(EXCLUDED.purchase_unit,public.count_session_product_costs.purchase_unit),
      unit_factor_to_base=coalesce(EXCLUDED.unit_factor_to_base,public.count_session_product_costs.unit_factor_to_base),
      source_type=coalesce(EXCLUDED.source_type,public.count_session_product_costs.source_type),
      source_reference=coalesce(EXCLUDED.source_reference,public.count_session_product_costs.source_reference),
      source_date=coalesce(EXCLUDED.source_date,public.count_session_product_costs.source_date),
      source_batch_id=EXCLUDED.source_batch_id,
      warning_codes=coalesce(EXCLUDED.warning_codes,ARRAY[]::text[]),
      updated_by=EXCLUDED.updated_by,
      updated_at=now();
  END IF;

  SELECT
    count(*) FILTER (WHERE row_status='committed'),
    count(*) FILTER (WHERE row_status='rejected'),
    count(*) FILTER (WHERE row_status='committed' AND location_id IS NOT NULL)
  INTO v_accepted,v_rejected,v_expected
  FROM public.count_import_rows
  WHERE batch_id=p_batch_id;

  UPDATE public.count_import_batches
  SET status='committed',
      accepted_count=coalesce(v_accepted,0),
      rejected_count=coalesce(v_rejected,0),
      completed_at=now(),
      error_report=jsonb_build_object(
        'rejected_count',coalesce(v_rejected,0),
        'expected_balance_rows',coalesce(v_expected,0),
        'warning_count',(SELECT count(*) FROM public.count_import_rows
          WHERE batch_id=p_batch_id AND cardinality(warning_codes)>0)
      ),
      updated_at=now()
  WHERE id=p_batch_id;

  INSERT INTO public.count_audit_log(
    project_id,actor_id,action,entity_type,entity_id,details
  ) VALUES (
    v_batch.project_id,(SELECT auth.uid()),
    'import.committed','import_batch',p_batch_id,
    jsonb_build_object(
      'accepted_rows',coalesce(v_accepted,0),
      'rejected_rows',coalesce(v_rejected,0),
      'expected_balance_rows',coalesce(v_expected,0),
      'metadata_optional',true,
      'identity_rule','sku_or_barcode'
    )
  );

  RETURN jsonb_build_object(
    'batch_id',p_batch_id,
    'status','committed',
    'accepted_rows',coalesce(v_accepted,0),
    'rejected_rows',coalesce(v_rejected,0),
    'expected_balance_rows',coalesce(v_expected,0)
  );
EXCEPTION WHEN OTHERS THEN
  UPDATE public.count_import_batches
  SET status='failed',
      completed_at=now(),
      error_report=jsonb_build_object('message',SQLERRM),
      updated_at=now()
  WHERE id=p_batch_id;
  RAISE;
END;
$function$;
REVOKE ALL ON FUNCTION public.count_commit_import_batch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_commit_import_batch(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.count_reconcile_session(p_session_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_session public.count_sessions; v_run_id uuid; v_run_number integer;
BEGIN
  SELECT * INTO v_session FROM public.count_sessions WHERE id=p_session_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_session.project_id) THEN RAISE EXCEPTION 'SESSION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_session.status NOT IN ('active','paused','review','completed') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_RECONCILIATION'; END IF;
  IF EXISTS(SELECT 1 FROM public.count_reconciliation_runs WHERE session_id=p_session_id AND status='approved') THEN
    RAISE EXCEPTION 'SESSION_RECONCILIATION_ALREADY_APPROVED';
  END IF;
  SELECT coalesce(max(run_number),0)+1 INTO v_run_number FROM public.count_reconciliation_runs WHERE session_id=p_session_id;
  INSERT INTO public.count_reconciliation_runs(project_id,session_id,run_number,status,created_by,created_at)
  VALUES(v_session.project_id,p_session_id,v_run_number,'building',(SELECT auth.uid()),now()) RETURNING id INTO v_run_id;
  WITH expected AS (
    SELECT product_id,location_id,sum(expected_quantity)::numeric AS expected_qty,
      max(unit) AS unit,true AS expected_scope
    FROM public.count_expected_balances
    WHERE session_id=p_session_id
    GROUP BY product_id,location_id
  ),
  counted AS (SELECT * FROM counting_private.session_effective_counts(p_session_id)),
  merged AS (
    SELECT coalesce(e.product_id,c.product_id) product_id,coalesce(e.location_id,c.location_id) location_id,
      e.expected_qty,c.counted_qty,coalesce(e.expected_scope,false) expected_scope,
      coalesce(c.unit,e.unit) unit,coalesce(c.events,0) events,coalesce(c.counters,0) counters
    FROM expected e FULL OUTER JOIN counted c ON c.product_id=e.product_id AND c.location_id IS NOT DISTINCT FROM e.location_id
  ),
  enriched AS (
    SELECT m.product_id,m.location_id,m.expected_qty,m.counted_qty,m.expected_scope,
      coalesce(m.unit,p.base_unit) unit,m.events,m.counters,
      coalesce(p.sku,'') sku,coalesce(p.name,'') product_name,
      coalesce(l.name,'غير محدد') location_name
    FROM merged m JOIN public.count_products p ON p.id=m.product_id LEFT JOIN public.count_locations l ON l.id=m.location_id
  )
  INSERT INTO public.count_reconciliation_lines(project_id,run_id,session_id,product_id,location_id,product_sku,product_name,location_path,unit,
    expected_quantity,counted_quantity,variance_quantity,variance_percent,counted_events,counter_count,result_status,computed_at,expected_scope)
  SELECT v_session.project_id,v_run_id,p_session_id,e.product_id,e.location_id,e.sku,e.product_name,e.location_name,e.unit,e.expected_qty,e.counted_qty,
    CASE WHEN e.expected_qty IS NULL THEN NULL ELSE coalesce(e.counted_qty,0)-e.expected_qty END,
    CASE WHEN e.expected_qty IS NULL OR e.expected_qty=0 THEN NULL ELSE ((coalesce(e.counted_qty,0)-e.expected_qty)/e.expected_qty)*100 END,
    e.events,e.counters,
    CASE WHEN e.expected_scope AND e.counted_qty IS NULL THEN 'not_counted'
      WHEN e.expected_qty IS NULL THEN 'not_expected'
      WHEN e.counted_qty IS NULL THEN 'not_counted'
      WHEN e.counted_qty=e.expected_qty THEN 'matched'
      WHEN e.counted_qty<e.expected_qty THEN 'under' ELSE 'over' END,now(),e.expected_scope
  FROM enriched e;
  UPDATE public.count_reconciliation_runs r SET status='computed',
    expected_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND expected_scope),
    counted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND counted_quantity IS NOT NULL),
    matched_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='matched'),
    variance_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status IN ('under','over')),
    uncounted_rows=(SELECT count(*) FROM public.count_reconciliation_lines WHERE run_id=v_run_id AND result_status='not_counted'),
    total_expected=(SELECT coalesce(sum(expected_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    total_counted=(SELECT coalesce(sum(counted_quantity),0) FROM public.count_reconciliation_lines WHERE run_id=v_run_id),
    entry_count_snapshot=(SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id),
    computed_at=now() WHERE r.id=v_run_id;
  PERFORM public.count_evaluate_session_alerts(p_session_id);
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_session.project_id,(SELECT auth.uid()),'reconciliation.computed','reconciliation_run',v_run_id,
    jsonb_build_object('session_id',p_session_id,'run_number',v_run_number,'approved_recount_override',true,
      'unit_normalization','base_quantity_snapshot','alerts_evaluated',true,'entry_count_snapshot',
      (SELECT count(*) FROM public.count_entries WHERE session_id=p_session_id)));
  RETURN v_run_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.count_reconcile_session(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_reconcile_session(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.count_approve_reconciliation(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_run public.count_reconciliation_runs;
  v_session_status text;
  v_open_tasks integer;
  v_critical_alerts integer;
  v_later_runs integer;
  v_current_entry_count bigint;
  v_uncovered_imported_products bigint;
BEGIN
  SELECT * INTO v_run FROM public.count_reconciliation_runs WHERE id=p_run_id FOR UPDATE;
  IF NOT FOUND OR NOT counting_private.is_supervisor(v_run.project_id) THEN RAISE EXCEPTION 'RECONCILIATION_NOT_FOUND_OR_FORBIDDEN'; END IF;
  IF v_run.status<>'computed' THEN RAISE EXCEPTION 'RECONCILIATION_NOT_COMPUTED'; END IF;
  SELECT status INTO v_session_status FROM public.count_sessions WHERE id=v_run.session_id FOR UPDATE;
  IF NOT FOUND OR v_session_status NOT IN ('active','paused','review') THEN RAISE EXCEPTION 'SESSION_NOT_READY_FOR_APPROVAL'; END IF;
  SELECT count(*) INTO v_later_runs FROM public.count_reconciliation_runs WHERE session_id=v_run.session_id AND run_number>v_run.run_number;
  IF v_later_runs>0 THEN RAISE EXCEPTION 'RECONCILIATION_NOT_LATEST'; END IF;
  SELECT count(*) INTO v_current_entry_count FROM public.count_entries WHERE session_id=v_run.session_id;
  IF v_current_entry_count<>v_run.entry_count_snapshot THEN
    RAISE EXCEPTION 'COUNT_DATA_CHANGED_AFTER_RECONCILIATION:%',v_current_entry_count-v_run.entry_count_snapshot;
  END IF;
  IF v_run.uncounted_rows>0 THEN RAISE EXCEPTION 'UNCOUNTED_POSITIONS_REMAINING:%',v_run.uncounted_rows; END IF;
  SELECT count(*) INTO v_uncovered_imported_products
  FROM (
    SELECT DISTINCT r.product_id
    FROM public.count_import_rows r
    JOIN public.count_import_batches b ON b.id=r.batch_id
    WHERE b.session_id=v_run.session_id AND r.row_status='committed'
      AND r.product_id IS NOT NULL
  ) scoped
  WHERE NOT EXISTS (
    SELECT 1 FROM public.count_reconciliation_lines l
    WHERE l.run_id=p_run_id AND l.product_id=scoped.product_id
      AND l.counted_quantity IS NOT NULL
  );
  IF v_uncovered_imported_products>0 THEN
    RAISE EXCEPTION 'IMPORTED_PRODUCTS_WITHOUT_ANY_COUNT:%',v_uncovered_imported_products;
  END IF;
  SELECT count(*) INTO v_open_tasks FROM public.count_recount_tasks WHERE session_id=v_run.session_id AND status NOT IN ('reviewed','cancelled');
  SELECT count(*) INTO v_critical_alerts FROM public.count_alerts WHERE session_id=v_run.session_id AND severity='critical' AND status IN ('open','acknowledged');
  IF v_open_tasks>0 THEN RAISE EXCEPTION 'RECOUNT_REVIEW_REQUIRED:%',v_open_tasks; END IF;
  IF v_critical_alerts>0 THEN RAISE EXCEPTION 'CRITICAL_ALERTS_UNRESOLVED:%',v_critical_alerts; END IF;
  UPDATE public.count_reconciliation_runs SET status='approved',approved_by=(SELECT auth.uid()),approved_at=now() WHERE id=p_run_id;
  UPDATE public.count_sessions SET status='review' WHERE id=v_run.session_id AND status IN ('active','paused');
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_run.project_id,(SELECT auth.uid()),'reconciliation.approved','reconciliation_run',p_run_id,
    jsonb_build_object('session_id',v_run.session_id,'run_number',v_run.run_number,'session_frozen',true,'entry_count_snapshot',v_run.entry_count_snapshot));
  RETURN jsonb_build_object('run_id',p_run_id,'status','approved','approved_at',now(),'session_status','review');
END;
$function$;
REVOKE ALL ON FUNCTION public.count_approve_reconciliation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_approve_reconciliation(uuid) TO authenticated;
