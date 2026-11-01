create or replace function public.buyer_custody_review_expense_atomic(p_company_id uuid,p_expense_id uuid,p_decision text,p_review_note text)
returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_expense public.buyer_custody_expenses%rowtype; v_row public.buyer_custody_expenses%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not app_private.current_user_has_effective_permission('finance') then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 if p_decision not in ('Approved','Rejected') then raise exception 'CUSTODY_REVIEW_DECISION_INVALID'; end if;
 select * into v_expense from public.buyer_custody_expenses where id=p_expense_id and company_id=p_company_id for update;
 if not found or v_expense.status<>'Submitted' then raise exception 'CUSTODY_EXPENSE_NOT_PENDING'; end if;
 if v_expense.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_REVIEW_FORBIDDEN'; end if;
 update public.buyer_custody_expenses set status=p_decision,reviewed_by=v_actor.id,reviewed_at=now(),review_note=nullif(btrim(p_review_note),'')
 where id=p_expense_id and company_id=p_company_id returning * into v_row;
 return to_jsonb(v_row);
end;$fn$;

create or replace function public.buyer_custody_settle_atomic(p_company_id uuid,p_custody_id uuid,p_cash_returned numeric,p_finance_reference text,p_notes text)
returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_actor public.users%rowtype; v_custody public.buyer_custodies%rowtype; v_approved numeric(14,2); v_pending integer; v_settlement public.buyer_custody_settlements%rowtype;
begin
 select * into v_actor from public.users where auth_id=auth.uid() and company_id=p_company_id and coalesce(status,'Active')='Active';
 if not found then raise exception 'CUSTODY_AUTH_REQUIRED'; end if;
 if not app_private.current_user_has_effective_permission('finance') then raise exception 'CUSTODY_FINANCE_PERMISSION_REQUIRED'; end if;
 select * into v_custody from public.buyer_custodies where id=p_custody_id and company_id=p_company_id for update;
 if not found or v_custody.status not in ('Issued','UnderReview') then raise exception 'CUSTODY_NOT_SETTLEABLE'; end if;
 if v_custody.employee_id=v_actor.id then raise exception 'CUSTODY_SELF_SETTLEMENT_FORBIDDEN'; end if;
 select count(*) into v_pending from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Submitted';
 if v_pending>0 then raise exception 'CUSTODY_EXPENSES_PENDING_REVIEW'; end if;
 select coalesce(sum(amount),0) into v_approved from public.buyer_custody_expenses where custody_id=p_custody_id and company_id=p_company_id and status='Approved';
 if coalesce(p_cash_returned,0)<0 or coalesce(p_cash_returned,0)>greatest(v_custody.issued_amount-v_approved,0) then raise exception 'CUSTODY_CASH_RETURN_INVALID'; end if;
 insert into public.buyer_custody_settlements(company_id,custody_id,approved_expense_total,cash_returned,amount_due_employee,balance_due_company,finance_reference,notes,recorded_by)
 values(p_company_id,p_custody_id,v_approved,coalesce(p_cash_returned,0),greatest(v_approved-v_custody.issued_amount,0),
 greatest(v_custody.issued_amount-v_approved-coalesce(p_cash_returned,0),0),nullif(btrim(p_finance_reference),''),nullif(btrim(p_notes),''),v_actor.id)
 returning * into v_settlement;
 update public.buyer_custodies set status='Settled',updated_at=now() where id=p_custody_id and company_id=p_company_id;
 return to_jsonb(v_settlement);
end;$fn$;
