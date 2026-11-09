export type WarehouseActor = {
  authUser: any;
  appUser: any;
  verifiedOwner: boolean;
  permissions: string[];
  allowedBranches: string[];
};

function normalizePermissions(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((x) => String(x || "").trim()).filter(Boolean);
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed.map((x) => String(x || "").trim()).filter(Boolean) : [];
    } catch {
      return value.trim() ? [value.trim()] : [];
    }
  }
  return [];
}

function normalizeAllowedBranches(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((x) => String(x || "").trim()).filter(Boolean);
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) return parsed.map((x) => String(x || "").trim()).filter(Boolean);
      if (typeof parsed === "string" && parsed.trim()) return [parsed.trim()];
    } catch {
      if (value.trim()) return [value.trim()];
    }
  }
  return [];
}

export async function resolveWarehouseActor(client: any, token: string): Promise<WarehouseActor> {
  const cleanToken = String(token || "").replace(/^Bearer\s+/i, "").trim();
  if (!cleanToken) throw new Error("جلسة غير صالحة");

  const { data: authData, error: authError } = await client.auth.getUser(cleanToken);
  const authUser = authData?.user;
  if (authError || !authUser?.id) throw new Error("جلسة غير صالحة");

  const { data: appUser, error: userError } = await client
    .from("users")
    .select("id,auth_id,company_id,status,email,role,role_id,permissions,active_warehouse_role,default_branch_id,allowed_branch_ids")
    .eq("auth_id", authUser.id)
    .maybeSingle();
  if (userError) throw new Error("فشل التحقق من ملف المستخدم: " + userError.message);
  if (!appUser?.id || !appUser?.company_id || appUser.auth_id !== authUser.id) {
    throw new Error("ملف المستخدم أو سياق الشركة غير متاح");
  }
  if (appUser.status && String(appUser.status).toLowerCase() !== "active") {
    throw new Error("المستخدم غير نشط");
  }

  const permissions = normalizePermissions(appUser.permissions);
  if (appUser.role_id) {
    const { data: role, error: roleError } = await client
      .from("roles")
      .select("permissions")
      .eq("id", appUser.role_id)
      .eq("company_id", appUser.company_id)
      .maybeSingle();
    if (roleError) throw new Error("تعذر قراءة صلاحيات الدور: " + roleError.message);
    permissions.push(...normalizePermissions(role?.permissions));

    const { data: rolePermissionRows, error: rolePermissionError } = await client
      .from("role_permissions")
      .select("permission_key")
      .eq("role_id", appUser.role_id);
    if (rolePermissionError) throw new Error("تعذر قراءة صلاحيات الدور التفصيلية: " + rolePermissionError.message);
    (rolePermissionRows || []).forEach((row: any) => {
      if (row?.permission_key) permissions.push(String(row.permission_key));
    });
  }

  let verifiedOwner = false;
  const metadata = authUser.user_metadata || {};
  if (metadata.isOwner === true || metadata.isOwner === "true") {
    const { data: ownerProfile, error: ownerError } = await client
      .from("owner_profile")
      .select("auth_user_id")
      .eq("auth_user_id", authUser.id)
      .maybeSingle();
    if (ownerError) throw new Error("فشل التحقق من ملف المالك");
    verifiedOwner = permissions.includes("*") && ownerProfile?.auth_user_id === authUser.id;
  }

  if (!verifiedOwner && !permissions.includes("warehouse")) {
    throw new Error("ليس لديك صلاحية استخدام عمليات المخازن");
  }

  return {
    authUser,
    appUser,
    verifiedOwner,
    permissions: Array.from(new Set(permissions)),
    allowedBranches: normalizeAllowedBranches(appUser.allowed_branch_ids),
  };
}

export async function requireWarehouseRole(
  client: any,
  token: string,
  requiredRole: string,
): Promise<WarehouseActor> {
  const actor = await resolveWarehouseActor(client, token);
  if (!actor.verifiedOwner) {
    const activeRole = String(actor.appUser.active_warehouse_role || "");
    if (activeRole !== requiredRole && activeRole !== "مخزن شامل") {
      throw new Error("الدور المخزني النشط لا يسمح بهذه العملية");
    }
  }
  return actor;
}

export async function assertWarehouseBranch(
  client: any,
  actor: WarehouseActor,
  branchId: string | null | undefined,
): Promise<void> {
  if (actor.verifiedOwner) return;
  if (!branchId) throw new Error("فرع العملية غير محدد");

  const { data: branch, error } = await client
    .from("branches")
    .select("id,branch_code,is_active")
    .eq("id", branchId)
    .eq("company_id", actor.appUser.company_id)
    .maybeSingle();
  if (error) throw new Error("تعذر التحقق من فرع العملية: " + error.message);
  if (!branch || branch.is_active === false) throw new Error("فرع العملية غير نشط أو لا يتبع الشركة");

  const allowed = actor.allowedBranches;
  const defaultBranchId = String(actor.appUser.default_branch_id || "");
  if (defaultBranchId && defaultBranchId === String(branch.id)) return;
  if (allowed.includes("*") || allowed.includes(String(branch.id)) || allowed.includes(String(branch.branch_code))) return;
  throw new Error("فرع العملية خارج نطاق الفروع المسموح بها للمستخدم");
}

export async function assertWarehouseMainBranch(client: any, actor: WarehouseActor): Promise<string> {
  const { data: settings, error } = await client
    .from("app_settings")
    .select("main_branch_id")
    .eq("company_id", actor.appUser.company_id)
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error("تعذر تحديد الفرع الرئيسي: " + error.message);
  const branchId = settings?.main_branch_id;
  if (!branchId) throw new Error("الفرع الرئيسي غير محدد للشركة");
  await assertWarehouseBranch(client, actor, branchId);
  return branchId;
}

export async function assertWarehouseVehicleBranch(client: any, actor: WarehouseActor, vehicleId: string): Promise<string> {
  if (!vehicleId) throw new Error("المركبة غير محددة");
  const { data: vehicle, error } = await client
    .from("vehicles")
    .select("id,company_id,status,mobile_stock_enabled,mobile_branch_id")
    .eq("id", vehicleId)
    .eq("company_id", actor.appUser.company_id)
    .maybeSingle();
  if (error) throw new Error("تعذر التحقق من المركبة: " + error.message);
  if (!vehicle || vehicle.status !== "Active" || vehicle.mobile_stock_enabled === false || !vehicle.mobile_branch_id) {
    throw new Error("المركبة غير نشطة أو لا تملك فرع مخزون صالحًا");
  }
  await assertWarehouseBranch(client, actor, vehicle.mobile_branch_id);
  return vehicle.mobile_branch_id;
}
