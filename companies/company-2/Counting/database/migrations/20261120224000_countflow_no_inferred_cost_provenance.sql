-- Missing price provenance must remain missing; never substitute the file name as an authoritative source.
CREATE OR REPLACE FUNCTION public.count_stage_import_rows(p_batch_id uuid, p_rows jsonb, p_row_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_batch public.count_import_batches;
  v_row jsonb;
  v_ord bigint;
  v_row_number integer;
  v_sku text;
  v_barcode text;
  v_name text;
  v_category text;
  v_unit text;
  v_units jsonb;
  v_image_url text;
  v_cost_text text;
  v_cost numeric(18,6);
  v_currency text;
  v_purchase_unit text;
  v_factor_text text;
  v_unit_factor numeric(18,6);
  v_cost_source_type text;
  v_cost_source_reference text;
  v_cost_source_date_text text;
  v_cost_source_date date;
  v_expected_text text;
  v_expected numeric(18,4);
  v_location_code text;
  v_location_id uuid;
  v_location_count integer;
  v_existing_product_count integer;
  v_errors text[];
  v_warnings text[];
  v_inserted integer := 0;
  v_rejected integer;
  v_accepted integer;
BEGIN
  IF jsonb_typeof(p_rows) <> 'array'
     OR jsonb_array_length(p_rows) < 1
     OR jsonb_array_length(p_rows) > 1000 THEN
    RAISE EXCEPTION 'IMPORT_CHUNK_MUST_CONTAIN_1_TO_1000_ROWS';
  END IF;
  IF p_row_offset < 0 THEN RAISE EXCEPTION 'INVALID_ROW_OFFSET'; END IF;

  SELECT * INTO v_batch
  FROM public.count_import_batches
  WHERE id = p_batch_id
  FOR UPDATE;

  IF NOT FOUND OR NOT counting_private.is_supervisor(v_batch.project_id) THEN
    RAISE EXCEPTION 'IMPORT_BATCH_NOT_FOUND_OR_FORBIDDEN';
  END IF;
  IF v_batch.status NOT IN ('uploading','preview') THEN
    RAISE EXCEPTION 'IMPORT_BATCH_NOT_ACCEPTING_ROWS';
  END IF;

  FOR v_row, v_ord IN
    SELECT value, ordinality
    FROM jsonb_array_elements(p_rows) WITH ORDINALITY
  LOOP
    v_errors := ARRAY[]::text[];
    v_warnings := ARRAY[]::text[];
    v_expected := NULL;
    v_location_id := NULL;
    v_sku := NULL;
    v_barcode := NULL;
    v_name := NULL;
    v_category := NULL;
    v_unit := NULL;
    v_expected_text := NULL;
    v_location_code := NULL;
    v_units := '[]'::jsonb;
    v_image_url := NULL;
    v_cost_text := NULL;
    v_cost := NULL;
    v_currency := NULL;
    v_purchase_unit := NULL;
    v_factor_text := NULL;
    v_unit_factor := NULL;
    v_cost_source_type := NULL;
    v_cost_source_reference := NULL;
    v_cost_source_date_text := NULL;
    v_cost_source_date := NULL;

    IF jsonb_typeof(v_row) <> 'object' THEN
      v_errors := array_append(v_errors,'INVALID_ROW_SHAPE');
    ELSE
      v_sku := coalesce(
        nullif(btrim(v_row->>'sku'),''),
        nullif(btrim(v_row->>'item_code'),''),
        nullif(btrim(v_row->>'كود الصنف'),'')
      );
      v_barcode := coalesce(
        nullif(btrim(v_row->>'barcode'),''),
        nullif(btrim(v_row->>'باركود'),'')
      );
      v_name := coalesce(
        nullif(btrim(v_row->>'name'),''),
        nullif(btrim(v_row->>'product_name'),''),
        nullif(btrim(v_row->>'اسم الصنف'),'')
      );
      v_category := coalesce(
        nullif(btrim(v_row->>'category'),''),
        nullif(btrim(v_row->>'الفئة'),'')
      );
      v_unit := coalesce(
        nullif(btrim(v_row->>'base_unit'),''),
        nullif(btrim(v_row->>'unit'),''),
        nullif(btrim(v_row->>'الوحدة'),'')
      );
      IF v_unit IS NULL AND (v_sku IS NOT NULL OR v_barcode IS NOT NULL) THEN
        SELECT count(*), (array_agg(p.base_unit))[1]
        INTO v_existing_product_count, v_unit
        FROM public.count_products p
        WHERE p.project_id=v_batch.project_id
          AND (
            (v_sku IS NOT NULL AND lower(btrim(p.sku))=lower(v_sku))
            OR (v_barcode IS NOT NULL AND btrim(p.barcode)=v_barcode)
          );
        IF v_existing_product_count > 1 THEN
          v_errors := array_append(v_errors,'PRODUCT_IDENTITY_MATCHES_MULTIPLE_PRODUCTS');
          v_unit := NULL;
        END IF;
      END IF;
      v_units := CASE
        WHEN jsonb_typeof(v_row->'units') = 'array' THEN v_row->'units'
        ELSE '[]'::jsonb
      END;
      v_expected_text := coalesce(
        nullif(btrim(v_row->>'expected_qty'),''),
        nullif(btrim(v_row->>'expected_quantity'),''),
        nullif(btrim(v_row->>'الكمية الدفترية'),'')
      );
      v_location_code := coalesce(
        nullif(btrim(v_row->>'location_code'),''),
        nullif(btrim(v_row->>'الموقع'),'')
      );
      v_image_url := coalesce(
        nullif(btrim(v_row->>'image_url'),''),
        nullif(btrim(v_row->>'رابط الصورة'),'')
      );
      v_cost_text := coalesce(
        nullif(btrim(v_row->>'purchase_unit_cost'),''),
        nullif(btrim(v_row->>'purchase_price'),''),
        nullif(btrim(v_row->>'unit_cost'),''),
        nullif(btrim(v_row->>'سعر الشراء'),''),
        nullif(btrim(v_row->>'وحدة سعر الشراء'),'')
      );
      v_currency := coalesce(
        nullif(upper(btrim(v_row->>'currency_code')),''),
        nullif(upper(btrim(v_row->>'currency')),''),
        nullif(upper(btrim(v_row->>'العملة')),'')
      );
      v_purchase_unit := coalesce(
        nullif(btrim(v_row->>'purchase_unit'),''),
        nullif(btrim(v_row->>'وحدة الشراء'),'')
      );
      v_factor_text := coalesce(
        nullif(btrim(v_row->>'unit_factor_to_base'),''),
        nullif(btrim(v_row->>'purchase_unit_factor_to_base'),''),
        nullif(btrim(v_row->>'معامل التحويل للوحدة الأساسية'),'')
      );
      v_cost_source_type := coalesce(
        nullif(btrim(v_row->>'cost_source_type'),''),
        nullif(btrim(v_row->>'price_source'),''),
        nullif(btrim(v_row->>'مصدر السعر'),'')
      );
      v_cost_source_reference := coalesce(
        nullif(btrim(v_row->>'cost_source_reference'),''),
        nullif(btrim(v_row->>'invoice_reference'),''),
        nullif(btrim(v_row->>'مرجع السعر'),'')
      );
      v_cost_source_date_text := coalesce(
        nullif(btrim(v_row->>'cost_source_date'),''),
        nullif(btrim(v_row->>'price_date'),''),
        nullif(btrim(v_row->>'تاريخ السعر'),'')
      );

      IF v_cost_text IS NOT NULL THEN
        IF v_cost_text !~ '^[0-9]+([.][0-9]{1,6})?$' THEN
          v_warnings := array_append(v_warnings,'INVALID_PURCHASE_UNIT_COST');
        ELSE
          v_cost := v_cost_text::numeric(18,6);
        END IF;
      END IF;
      IF v_currency IS NOT NULL AND v_currency !~ '^[A-Z]{3,8}$' THEN
        v_currency := NULL;
        v_warnings := array_append(v_warnings,'INVALID_CURRENCY_CODE');
      END IF;
      IF v_factor_text IS NOT NULL THEN
        IF v_factor_text !~ '^[0-9]+([.][0-9]{1,6})?$' THEN
          v_warnings := array_append(v_warnings,'INVALID_UNIT_FACTOR');
        ELSE
          v_unit_factor := v_factor_text::numeric(18,6);
          IF v_unit_factor <= 0 THEN
            v_unit_factor := NULL;
            v_warnings := array_append(v_warnings,'INVALID_UNIT_FACTOR');
          END IF;
        END IF;
      END IF;
      IF v_cost_source_date_text IS NOT NULL THEN
        BEGIN
          IF v_cost_source_date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
            RAISE EXCEPTION 'INVALID_SOURCE_DATE';
          END IF;
          v_cost_source_date := v_cost_source_date_text::date;
        EXCEPTION WHEN OTHERS THEN
          v_cost_source_date := NULL;
          v_warnings := array_append(v_warnings,'INVALID_COST_SOURCE_DATE');
        END;
      END IF;
      -- Do not infer an authoritative cost source from the import filename.
      -- Keep missing source type/reference NULL and surface COST_DATA_INCOMPLETE.
      IF (v_cost IS NOT NULL OR v_currency IS NOT NULL OR v_purchase_unit IS NOT NULL
          OR v_unit_factor IS NOT NULL OR v_cost_source_type IS NOT NULL
          OR v_cost_source_reference IS NOT NULL OR v_cost_source_date IS NOT NULL)
         AND (v_cost IS NULL OR v_currency IS NULL OR v_purchase_unit IS NULL
              OR v_unit_factor IS NULL OR v_cost_source_type IS NULL
              OR v_cost_source_reference IS NULL) THEN
        v_warnings := array_append(v_warnings,'COST_DATA_INCOMPLETE');
      END IF;
      IF v_batch.session_id IS NULL AND (
        v_cost IS NOT NULL OR v_currency IS NOT NULL OR v_purchase_unit IS NOT NULL
        OR v_unit_factor IS NOT NULL OR v_cost_source_type IS NOT NULL
        OR v_cost_source_reference IS NOT NULL OR v_cost_source_date IS NOT NULL
      ) THEN
        v_warnings := array_append(v_warnings,'COST_REQUIRES_OPERATION_SCOPE');
      END IF;

      IF v_sku IS NULL AND v_barcode IS NULL THEN
        v_errors := array_append(v_errors,'MISSING_PRODUCT_IDENTIFIER');
      END IF;
      IF v_sku IS NOT NULL AND length(v_sku) > 160 THEN
        v_errors := array_append(v_errors,'SKU_TOO_LONG');
      END IF;
      IF v_barcode IS NOT NULL AND length(v_barcode) > 120 THEN
        v_errors := array_append(v_errors,'BARCODE_TOO_LONG');
      END IF;
      IF v_name IS NOT NULL AND length(v_name) > 200 THEN
        v_errors := array_append(v_errors,'PRODUCT_NAME_TOO_LONG');
      END IF;
      IF v_unit IS NULL THEN
        v_errors := array_append(v_errors,'MISSING_BASE_UNIT');
      ELSIF length(v_unit) > 40 THEN
        v_errors := array_append(v_errors,'BASE_UNIT_TOO_LONG');
      END IF;
      IF v_category IS NOT NULL AND length(v_category) > 120 THEN
        v_errors := array_append(v_errors,'CATEGORY_TOO_LONG');
      END IF;

      IF v_image_url IS NOT NULL AND (
        length(v_image_url) > 2048
        OR (v_image_url ~* '^[a-z][a-z0-9+.-]*://' AND v_image_url !~* '^https://')
        OR v_image_url LIKE '/%'
        OR v_image_url LIKE '%..%'
      ) THEN
        v_errors := array_append(v_errors,'INVALID_IMAGE_REFERENCE');
      END IF;

      IF v_expected_text IS NOT NULL THEN
        IF v_expected_text !~ '^[+-]?[0-9]+([.][0-9]{1,4})?$' THEN
          v_errors := array_append(v_errors,'INVALID_EXPECTED_QUANTITY');
        ELSE
          v_expected := v_expected_text::numeric;
          IF v_expected < 0 THEN
            v_errors := array_append(v_errors,'NEGATIVE_EXPECTED_QUANTITY');
          END IF;
          IF v_batch.session_id IS NULL THEN
            v_errors := array_append(v_errors,'SESSION_REQUIRED_FOR_EXPECTED_QTY');
          END IF;
        END IF;
      END IF;

      IF v_location_code IS NOT NULL THEN
        SELECT count(*), (array_agg(id))[1]
        INTO v_location_count, v_location_id
        FROM public.count_locations
        WHERE project_id = v_batch.project_id
          AND code = v_location_code;

        IF v_location_count = 0 THEN
          v_errors := array_append(v_errors,'UNKNOWN_LOCATION_CODE');
        ELSIF v_location_count > 1 THEN
          v_location_id := NULL;
          v_errors := array_append(v_errors,'AMBIGUOUS_LOCATION_CODE');
        END IF;
      END IF;

      IF (
        v_sku IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.count_import_rows old
          WHERE old.batch_id = p_batch_id
            AND lower(btrim(old.sku)) = lower(v_sku)
            AND nullif(btrim(old.location_code),'') IS NOT DISTINCT FROM v_location_code
        )
      ) OR (
        v_barcode IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.count_import_rows old
          WHERE old.batch_id = p_batch_id
            AND btrim(old.barcode) = v_barcode
            AND nullif(btrim(old.location_code),'') IS NOT DISTINCT FROM v_location_code
        )
      ) THEN
        v_errors := array_append(v_errors,'DUPLICATE_PRODUCT_IDENTIFIER_AT_SAME_LOCATION');
      END IF;
    END IF;

    IF jsonb_typeof(v_row) = 'object'
       AND coalesce(v_row->>'_row_number','') ~ '^[0-9]+$' THEN
      v_row_number := (v_row->>'_row_number')::integer;
    ELSE
      v_row_number := p_row_offset + v_ord::integer;
    END IF;
    IF v_row_number < 1 THEN
      RAISE EXCEPTION 'INVALID_SOURCE_ROW_NUMBER';
    END IF;

    INSERT INTO public.count_import_rows(
      batch_id, project_id, row_number, raw_row, sku, barcode, product_name,
      category, base_unit, units, image_url, expected_quantity, location_code,
      location_id, row_status, error_codes, purchase_unit_cost, currency_code,
      purchase_unit, unit_factor_to_base, cost_source_type, cost_source_reference,
      cost_source_date, warning_codes
    ) VALUES (
      p_batch_id, v_batch.project_id, v_row_number,
      coalesce(v_row->'_source_row',v_row),
      v_sku, v_barcode, v_name, v_category, v_unit, v_units, v_image_url,
      v_expected, v_location_code, v_location_id,
      CASE WHEN cardinality(v_errors) > 0 THEN 'rejected' ELSE 'staged' END,
      v_errors, v_cost, v_currency, v_purchase_unit, v_unit_factor,
      v_cost_source_type, v_cost_source_reference, v_cost_source_date, v_warnings
    )
    ON CONFLICT(batch_id,row_number) DO NOTHING;

    IF FOUND THEN v_inserted := v_inserted + 1; END IF;
  END LOOP;

  SELECT
    count(*) FILTER (WHERE row_status='rejected'),
    count(*) FILTER (WHERE row_status IN ('staged','accepted'))
  INTO v_rejected, v_accepted
  FROM public.count_import_rows
  WHERE batch_id = p_batch_id;

  UPDATE public.count_import_batches
  SET row_count = (SELECT count(*) FROM public.count_import_rows WHERE batch_id=p_batch_id),
      accepted_count = coalesce(v_accepted,0),
      rejected_count = coalesce(v_rejected,0),
      status = 'preview',
      error_report = jsonb_build_object(
        'rejected_count',coalesce(v_rejected,0),
        'staged_count',coalesce(v_accepted,0),
        'warning_count',(SELECT count(*) FROM public.count_import_rows
          WHERE batch_id=p_batch_id AND cardinality(warning_codes)>0)
      ),
      updated_at = now()
  WHERE id = p_batch_id;

  RETURN jsonb_build_object(
    'batch_id',p_batch_id,
    'inserted_rows',v_inserted,
    'accepted_rows',coalesce(v_accepted,0),
    'rejected_rows',coalesce(v_rejected,0)
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) TO authenticated;
