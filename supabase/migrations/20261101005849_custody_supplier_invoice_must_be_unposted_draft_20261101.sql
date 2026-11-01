
do $$
declare v_definition text;
begin
 select pg_get_functiondef('public.buyer_custody_submit_expense_atomic(uuid,uuid,date,text,text,text,numeric,text,text,text,text,uuid,uuid,text,text,text,text,text)'::regprocedure)
 into v_definition;
 v_definition:=replace(v_definition,'i.status in (''Draft'',''Posted'')','i.status=''Draft''');
 if v_definition not like '%i.status=''Draft''%' then raise exception 'CUSTODY_INVOICE_STATUS_GUARD_PATCH_FAILED'; end if;
 execute v_definition;
end;
$$;
