-- LVE-579: remove the retired trigger-only SECURITY DEFINER function.
-- The legacy trigger was removed in 20261102142016; catalog inspection
-- confirmed this function had no remaining database dependencies.
DROP FUNCTION public.sync_supplier_accounts_payable_from_ledger();
