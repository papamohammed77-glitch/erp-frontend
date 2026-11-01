
do $$
declare v_def text;
begin
 select pg_get_functiondef('public.receive_purchase_atomic(uuid,text,text,jsonb,uuid)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  'SELECT COALESCE(balance,0) INTO previous_balance FROM public.supplier_ledger WHERE supplier_id=po.supplier_id ORDER BY created_at DESC LIMIT 1;',
  'SELECT COALESCE(SUM(credit-debit),0) INTO previous_balance FROM public.supplier_ledger WHERE supplier_id=po.supplier_id;');
 if position('SUM(credit-debit)' in v_def)=0 then raise exception 'RECEIVING_SUPPLIER_BALANCE_PATCH_FAILED'; end if;
 execute v_def;
end;
$$;
do $$
declare v_def text;
begin
 select pg_get_functiondef('public.buyer_custody_review_expense_atomic(uuid,uuid,text,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  'select coalesce((select balance from public.supplier_ledger where supplier_id=v_expense.supplier_id order by created_at desc,id desc limit 1),0) into v_balance;',
  'select coalesce(sum(credit-debit),0) into v_balance from public.supplier_ledger where supplier_id=v_expense.supplier_id;');
 if position('select coalesce(sum(credit-debit),0) into v_balance' in v_def)=0 then raise exception 'CUSTODY_SUPPLIER_BALANCE_PATCH_FAILED'; end if;
 execute v_def;
end;
$$;
