-- CountFlow only: optional descriptive metadata, strict product identity, and safe barcode-only import.
-- Missing product name/category/image/alternate units never block counting.
-- Every countable product still needs one stable identifier and a real base unit.

ALTER TABLE public.count_products
  ALTER COLUMN sku DROP NOT NULL,
  ALTER COLUMN name DROP NOT NULL,
  ALTER COLUMN base_unit DROP DEFAULT;

ALTER TABLE public.count_products
  ADD CONSTRAINT count_products_identity_required
    CHECK (nullif(btrim(sku), '') IS NOT NULL OR nullif(btrim(barcode), '') IS NOT NULL),
  ADD CONSTRAINT count_products_sku_normalized
    CHECK (sku IS NULL OR (sku = btrim(sku) AND sku <> '')),
  ADD CONSTRAINT count_products_barcode_normalized
    CHECK (barcode IS NULL OR (barcode = btrim(barcode) AND barcode <> '')),
  ADD CONSTRAINT count_products_base_unit_nonblank
    CHECK (btrim(base_unit) <> '');

CREATE UNIQUE INDEX count_products_project_sku_ci_uq
  ON public.count_products (project_id, lower(btrim(sku)))
  WHERE sku IS NOT NULL AND btrim(sku) <> '';

CREATE UNIQUE INDEX count_products_project_barcode_uq
  ON public.count_products (project_id, btrim(barcode))
  WHERE barcode IS NOT NULL AND btrim(barcode) <> '';

CREATE OR REPLACE FUNCTION public.count_stage_import_rows(
  p_batch_id uuid,
  p_rows jsonb,
  p_row_offset integer DEFAULT 0
)
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
  v_expected_text text;
  v_expected numeric(18,4);
  v_location_code text;
  v_location_id uuid;
  v_location_count integer;
  v_errors text[];
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
        )
      ) OR (
        v_barcode IS NOT NULL AND EXISTS (
          SELECT 1 FROM public.count_import_rows old
          WHERE old.batch_id = p_batch_id
            AND btrim(old.barcode) = v_barcode
        )
      ) THEN
        v_errors := array_append(v_errors,'DUPLICATE_PRODUCT_IDENTIFIER_IN_BATCH');
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
      location_id, row_status, error_codes
    ) VALUES (
      p_batch_id, v_batch.project_id, v_row_number,
      coalesce(v_row->'_source_row',v_row),
      v_sku, v_barcode, v_name, v_category, v_unit, v_units, v_image_url,
      v_expected, v_location_code, v_location_id,
      CASE WHEN cardinality(v_errors) > 0 THEN 'rejected' ELSE 'staged' END,
      v_errors
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
        'staged_count',coalesce(v_accepted,0)
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
    ELSIF v_unit IS NULL OR length(v_unit)>40 THEN
      v_error := 'INVALID_OR_MISSING_BASE_UNIT';
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
      ))
      OR
      (v_barcode IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.count_import_rows prior
        WHERE prior.batch_id=p_batch_id
          AND prior.row_status='committed'
          AND prior.id<>v_row.id
          AND btrim(prior.barcode)=v_barcode
      ))
    ) THEN
      v_error := 'DUPLICATE_PRODUCT_IDENTIFIER_IN_BATCH';
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
                search_text=nullif(concat_ws(' ',
                  coalesce(v_product.sku,v_sku),
                  coalesce(v_product.barcode,v_barcode),
                  coalesce(v_name,v_product.name),
                  coalesce(v_category,v_product.category)
                ),''),
                updated_at=now()
            WHERE id=v_product.id
            RETURNING id INTO v_product_id;
          EXCEPTION WHEN unique_violation THEN
            v_error := 'PRODUCT_IDENTIFIER_ALREADY_IN_USE';
          END;
        END IF;
      ELSE
        BEGIN
          INSERT INTO public.count_products(
            project_id,sku,barcode,name,category,base_unit,units,
            image_url,search_text,is_active,updated_at
          ) VALUES (
            v_batch.project_id,v_sku,v_barcode,v_name,v_category,v_unit,
            coalesce(v_row.units,'[]'::jsonb),v_image_url,
            nullif(concat_ws(' ',v_sku,v_barcode,v_name,v_category),''),
            true,now()
          )
          RETURNING id INTO v_product_id;
        EXCEPTION WHEN unique_violation THEN
          v_error := 'PRODUCT_IDENTIFIER_ALREADY_IN_USE';
        END;
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
      AND r.expected_quantity IS NOT NULL
    ON CONFLICT(session_id,product_id,location_id) DO UPDATE SET
      expected_quantity=EXCLUDED.expected_quantity,
      unit=EXCLUDED.unit,
      source_batch_id=EXCLUDED.source_batch_id,
      snapshot_at=EXCLUDED.snapshot_at,
      updated_at=now();
  END IF;

  SELECT
    count(*) FILTER (WHERE row_status='committed'),
    count(*) FILTER (WHERE row_status='rejected'),
    count(*) FILTER (WHERE row_status='committed' AND expected_quantity IS NOT NULL)
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
        'expected_balance_rows',coalesce(v_expected,0)
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

REVOKE ALL ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_stage_import_rows(uuid,jsonb,integer) TO authenticated;

REVOKE ALL ON FUNCTION public.count_commit_import_batch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.count_commit_import_batch(uuid) TO authenticated;
