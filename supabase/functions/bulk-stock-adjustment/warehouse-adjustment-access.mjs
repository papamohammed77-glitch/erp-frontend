export function normalizePermissions(value) {
  if (Array.isArray(value)) return [...new Set(value.map(x => String(x || "").trim()).filter(Boolean))];
  if (typeof value !== "string" || !value.trim()) return [];
  try {
    const parsed = JSON.parse(value);
    if (Array.isArray(parsed)) return normalizePermissions(parsed);
  } catch (_) {}
  return [...new Set(value.split(/[,|]/).map(x => x.trim()).filter(Boolean))];
}

export function normalizeBranchIds(value) {
  if (Array.isArray(value)) return [...new Set(value.map(x => String(x || "").trim()).filter(Boolean))];
  if (typeof value !== "string" || !value.trim()) return [];
  try {
    const parsed = JSON.parse(value);
    if (Array.isArray(parsed)) return normalizeBranchIds(parsed);
    if (typeof parsed === "string" && parsed.trim()) return [parsed.trim()];
  } catch (_) {}
  return value.split(/[,|]/).map(x => x.trim()).filter(Boolean);
}

export function canAdjustStock(profile) {
  if (!profile || typeof profile !== "object") return false;
  if (profile.isOwner === true) return true;
  const permissions = normalizePermissions(profile.permissions);
  if (permissions.includes("stock_adjustment")) return true;
  return String(profile.active_warehouse_role || "").trim() === "مخزن شامل"
    && permissions.includes("warehouse");
}

export function canAccessAdjustmentBranch(profile, branch) {
  if (!profile || typeof profile !== "object" || !branch || branch.is_active === false) return false;
  if (profile.isOwner === true) return true;

  // Preserve the existing global stock_adjustment capability for non-unified roles.
  // A unified storekeeper is always restricted to the parent-assigned branch scope.
  if (String(profile.active_warehouse_role || "").trim() !== "مخزن شامل") return true;

  const branchId = String(branch.id || "").trim();
  const branchCode = String(branch.branch_code || "").trim();
  if (!branchId || !normalizePermissions(profile.permissions).includes("warehouse")) return false;

  const defaultBranchId = String(profile.default_branch_id || "").trim();
  if (defaultBranchId && defaultBranchId === branchId) return true;

  const allowed = normalizeBranchIds(profile.allowed_branch_ids);
  return allowed.includes("*") || allowed.includes(branchId) || (!!branchCode && allowed.includes(branchCode));
}
