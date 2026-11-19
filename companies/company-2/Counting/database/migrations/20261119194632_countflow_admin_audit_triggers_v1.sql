CREATE OR REPLACE FUNCTION counting_private.audit_countflow_row_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_new jsonb; v_old jsonb; v_project_id uuid; v_session_id uuid; v_entity_id uuid; v_actor_id uuid; v_action text;
BEGIN
  v_new:=CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END;
  v_old:=CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
  IF TG_OP='UPDATE' AND v_new=v_old THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND TG_TABLE_NAME IN ('count_devices','count_members')
     AND (v_new-'last_seen_at')=(v_old-'last_seen_at') THEN RETURN NEW; END IF;
  v_entity_id:=coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_session_id:=coalesce(nullif(v_new->>'session_id','')::uuid,nullif(v_old->>'session_id','')::uuid);
  v_project_id:=coalesce(nullif(v_new->>'project_id','')::uuid,nullif(v_old->>'project_id','')::uuid);
  IF TG_TABLE_NAME='count_projects' THEN v_project_id:=v_entity_id;
  ELSIF TG_TABLE_NAME='count_assignments' THEN
    SELECT project_id INTO v_project_id FROM public.count_sessions WHERE id=v_session_id;
  END IF;
  IF v_project_id IS NULL THEN RAISE EXCEPTION 'COUNT_AUDIT_PROJECT_SCOPE_MISSING:%',TG_TABLE_NAME; END IF;
  v_actor_id:=auth.uid();
  v_action:='countflow.'||TG_TABLE_NAME||'.'||lower(TG_OP);
  INSERT INTO public.count_audit_log(project_id,actor_id,action,entity_type,entity_id,details)
  VALUES(v_project_id,v_actor_id,v_action,TG_TABLE_NAME,v_entity_id,
    jsonb_build_object('operation',TG_OP,'session_id',v_session_id,'before',v_old,'after',v_new));
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION counting_private.audit_countflow_row_change() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_projects;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_projects FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_members;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_members FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_sessions;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_sessions FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_assignments;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_assignments FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_recount_tasks;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_recount_tasks FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_anomaly_rules;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_anomaly_rules FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_devices;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_devices FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_row_change ON public.count_entry_images;
CREATE TRIGGER countflow_audit_row_change AFTER INSERT OR UPDATE OR DELETE ON public.count_entry_images FOR EACH ROW EXECUTE FUNCTION counting_private.audit_countflow_row_change();
DROP TRIGGER IF EXISTS countflow_audit_status_change ON public.count_import_batches;
CREATE TRIGGER countflow_audit_status_change AFTER UPDATE OF status ON public.count_import_batches
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION counting_private.audit_countflow_row_change();
