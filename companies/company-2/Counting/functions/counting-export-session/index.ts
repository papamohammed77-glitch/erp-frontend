// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import * as XLSX from "npm:xlsx@0.18.5";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PAGE_SIZE = 1000;
const MAX_ENTRIES = 150000;
const MAX_LINES = 150000;
const MAX_PRODUCTS = 150000;
const MAX_LOCATIONS = 100000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

async function fetchAll(
  admin: any,
  table: string,
  columns: string,
  filters: Array<[string, string, unknown]>,
  maxRows: number,
  orderColumn = "id",
) {
  const rows: any[] = [];
  for (let offset = 0; offset < maxRows; offset += PAGE_SIZE) {
    let query = admin.from(table).select(columns);
    for (const [column, operator, value] of filters) {
      if (operator === "eq") query = query.eq(column, value);
      else if (operator === "in") query = query.in(column, value);
      else if (operator === "filter_eq") query = query.filter(column, "eq", value);
    }
    query = query.order(orderColumn, { ascending: true }).range(offset, offset + PAGE_SIZE - 1);
    const { data, error } = await query;
    if (error) throw new Error(`FETCH_${table}: ${error.message}`);
    const page = data || [];
    rows.push(...page);
    if (page.length < PAGE_SIZE) return rows;
  }
  if (rows.length >= maxRows) {
    let countQuery = admin.from(table).select("id", { count: "exact", head: true });
    for (const [column, operator, value] of filters) {
      if (operator === "eq") countQuery = countQuery.eq(column, value);
      else if (operator === "in") countQuery = countQuery.in(column, value);
      else if (operator === "filter_eq") countQuery = countQuery.filter(column, "eq", value);
    }
    const { count, error } = await countQuery;
    if (!error && count > maxRows) throw new Error(`EXPORT_LIMIT_${table}:${maxRows}`);
  }
  return rows;
}

function csvCell(value: unknown) {
  const s = value == null ? "" : typeof value === "object" ? JSON.stringify(value) : String(value);
  return '"' + s.replace(/"/g, '""') + '"';
}
function csvBytes(headers: string[], rows: unknown[][]) {
  const text = [headers, ...rows].map(row => row.map(csvCell).join(",")).join("\r\n");
  return new TextEncoder().encode("\uFEFF" + text);
}
function addSheet(workbook: any, name: string, headers: string[], rows: unknown[][]) {
  const sheet = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  sheet["!freeze"] = { xSplit: 0, ySplit: 1 };
  XLSX.utils.book_append_sheet(workbook, sheet, name.slice(0, 31));
}
function toHex(buffer: ArrayBuffer) {
  return [...new Uint8Array(buffer)].map(v => v.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: "SERVER_CONFIGURATION_MISSING" }, 500);
  }

  let exportId: string | null = null;
  let storagePath: string | null = null;
  let admin: any = null;
  try {
    const authorization = req.headers.get("Authorization") || "";
    if (!authorization.startsWith("Bearer ")) return json({ error: "AUTHORIZATION_REQUIRED" }, 401);

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData?.user) return json({ error: "INVALID_USER_TOKEN" }, 401);
    const user = userData.user;

    const body = await req.json().catch(() => ({}));
    const sessionId = String(body?.session_id || "");
    const format = String(body?.format || "xlsx").toLowerCase();
    if (!/^[0-9a-f-]{36}$/i.test(sessionId)) return json({ error: "INVALID_SESSION_ID" }, 400);
    if (!["xlsx", "csv"].includes(format)) return json({ error: "UNSUPPORTED_EXPORT_FORMAT" }, 400);

    admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: session, error: sessionError } = await admin.from("count_sessions")
      .select("id,project_id,name,status,started_at,closed_at")
      .eq("id", sessionId).maybeSingle();
    if (sessionError || !session) return json({ error: "SESSION_NOT_FOUND" }, 404);

    const { data: member, error: memberError } = await admin.from("count_members")
      .select("id,role,status")
      .eq("project_id", session.project_id).eq("user_id", user.id)
      .eq("role", "supervisor").eq("status", "active").maybeSingle();
    if (memberError || !member) return json({ error: "SUPERVISOR_ACCESS_REQUIRED" }, 403);

    const { data: exportRow, error: createError } = await admin.from("count_exports").insert({
      project_id: session.project_id,
      session_id: session.id,
      requested_by: user.id,
      export_format: format,
      export_scope: "full",
      status: "processing",
      metadata: { requested_at: new Date().toISOString(), engine: "counting-export-session-v1" },
    }).select("id").single();
    if (createError || !exportRow) throw new Error("EXPORT_RECORD_CREATE_FAILED: " + (createError?.message || "unknown"));
    exportId = exportRow.id;

    const [entries, products, locations, members, runs, alerts, recounts, imports] = await Promise.all([
      fetchAll(admin, "count_entries",
        "id,session_id,project_id,product_id,location_id,member_id,quantity,unit,unit_factor_to_base,base_quantity,scan_code,counted_at,device_id,count_round,revision,recount_task_id,client_event_id,note",
        [["session_id","eq",sessionId]], MAX_ENTRIES),
      fetchAll(admin, "count_products",
        "id,sku,barcode,name,category,base_unit,is_active",
        [["project_id","eq",session.project_id]], MAX_PRODUCTS),
      fetchAll(admin, "count_locations",
        "id,code,name,location_type,parent_id,sort_order",
        [["project_id","eq",session.project_id]], MAX_LOCATIONS),
      fetchAll(admin, "count_members",
        "id,user_id,display_name,username,role,status,last_seen_at",
        [["project_id","eq",session.project_id]], 10000),
      fetchAll(admin, "count_reconciliation_runs",
        "id,run_number,status,expected_rows,counted_rows,matched_rows,variance_rows,uncounted_rows,total_expected,total_counted,entry_count_snapshot,created_at,computed_at,approved_at",
        [["session_id","eq",sessionId]], 10000),
      fetchAll(admin, "count_alerts",
        "id,entry_id,rule_id,alert_type,severity,status,title,details,created_at,acknowledged_at,resolved_at",
        [["session_id","eq",sessionId]], 50000),
      fetchAll(admin, "count_recount_tasks",
        "id,product_id,location_id,assigned_member_id,status,reason,first_count_quantity,second_count_quantity,variance_percent,created_at,assigned_at,started_at,completed_at,reviewed_at,notes",
        [["session_id","eq",sessionId]], 50000),
      fetchAll(admin, "count_import_batches",
        "id,source_name,source_format,row_count,accepted_count,rejected_count,status,created_at,completed_at,error_report",
        [["session_id","eq",sessionId]], 50000),
    ]);

    const latestRun = [...runs].sort((a,b) => Number(b.run_number)-Number(a.run_number))[0] || null;
    const lines = latestRun
      ? await fetchAll(admin, "count_reconciliation_lines",
          "id,run_id,product_id,location_id,product_sku,product_name,location_path,unit,expected_quantity,counted_quantity,variance_quantity,variance_percent,counted_events,counter_count,result_status,computed_at",
          [["run_id","eq",latestRun.id]], MAX_LINES)
      : [];

    const importBatchIds = imports.map((b:any) => b.id);
    const [importErrors, images, presence, devices, auditByDetails, auditBySession] = await Promise.all([
      importBatchIds.length
        ? fetchAll(admin, "count_import_rows",
            "id,batch_id,row_number,raw_row,sku,barcode,product_name,location_code,row_status,error_codes,error_detail,processed_at",
            [["batch_id","in",importBatchIds],["row_status","eq","rejected"]], 100000)
        : Promise.resolve([]),
      fetchAll(admin, "count_entry_images",
        "id,project_id,entry_id,storage_path,mime_type,size_bytes,caption,uploaded_by,created_at",
        [["project_id","eq",session.project_id]], 50000),
      fetchAll(admin, "count_presence",
        "project_id,session_id,member_id,device_id,presence_state,current_location_id,started_at,last_seen_at",
        [["session_id","eq",sessionId]], 10000, "last_seen_at"),
      fetchAll(admin, "count_devices",
        "id,project_id,member_id,device_id,device_label,platform,app_version,status,first_seen_at,last_seen_at,revoked_at",
        [["project_id","eq",session.project_id]], 10000),
      fetchAll(admin, "count_audit_log",
        "id,project_id,actor_id,action,entity_type,entity_id,details,created_at",
        [["project_id","eq",session.project_id],["details->>session_id","filter_eq",sessionId]], 100000),
      fetchAll(admin, "count_audit_log",
        "id,project_id,actor_id,action,entity_type,entity_id,details,created_at",
        [["project_id","eq",session.project_id],["entity_id","eq",sessionId]], 1000),
    ]);
    const auditMap = new Map();
    for (const row of [...auditByDetails,...auditBySession]) auditMap.set(row.id,row);
    const auditRows = [...auditMap.values()];
    const entryIds = new Set(entries.map((e:any)=>e.id));
    const sessionImages = images.filter((img:any)=>entryIds.has(img.entry_id));
    const sessionDeviceIds = new Set([
      ...presence.map((p:any)=>p.device_id),
      ...entries.map((e:any)=>e.device_id).filter(Boolean),
    ]);
    const sessionDevices = devices.filter((d:any)=>sessionDeviceIds.has(d.device_id));
    const combinedRows = entries.length + lines.length + importErrors.length + sessionImages.length;
    if (combinedRows > 250000) throw new Error("EXPORT_COMBINED_ROW_LIMIT:250000");

    const productMap = new Map(products.map((p:any) => [p.id,p]));
    const locationMap = new Map(locations.map((l:any) => [l.id,l]));
    const memberMap = new Map(members.map((m:any) => [m.id,m]));
    const memberByUserId = new Map(members.map((m:any) => [m.user_id,m]));
    const importBatchMap = new Map(imports.map((b:any) => [b.id,b]));
    const entryMap = new Map(entries.map((e:any) => [e.id,e]));
    const deviceMap = new Map(sessionDevices.map((d:any) => [d.device_id,d]));
    const evidenceSignedMap = new Map();
    const evidencePaths = sessionImages.map((img:any)=>img.storage_path).filter(Boolean);
    for(let i=0;i<evidencePaths.length;i+=500){
      const chunk=evidencePaths.slice(i,i+500);
      const {data:signedRows}=await admin.storage.from("counting-evidence").createSignedUrls(chunk,7*24*60*60);
      for(const signed of (signedRows||[])) if(signed.path&&signed.signedUrl) evidenceSignedMap.set(signed.path,signed.signedUrl);
    }
    const memberAgg = new Map();
    const locationAgg = new Map();
    const quantityByUnit: Record<string,number> = {};

    const entryRows = entries.map((e:any) => {
      const p:any = productMap.get(e.product_id) || {};
      const l:any = locationMap.get(e.location_id) || {};
      const m:any = memberMap.get(e.member_id) || {};
      const baseUnit = p.base_unit || e.unit || "غير محدد";
      const baseQty = Number(e.base_quantity ?? e.quantity);
      quantityByUnit[baseUnit] = (quantityByUnit[baseUnit] || 0) + baseQty;

      let ma:any = memberAgg.get(e.member_id);
      if (!ma) { ma={count:0,products:new Set(),qtyByUnit:{},last:null}; memberAgg.set(e.member_id,ma); }
      ma.count++; ma.products.add(e.product_id); ma.qtyByUnit[baseUnit]=(ma.qtyByUnit[baseUnit]||0)+baseQty;
      if (!ma.last || e.counted_at>ma.last) ma.last=e.counted_at;

      let la:any = locationAgg.get(e.location_id);
      if (!la) { la={count:0,products:new Set(),qtyByUnit:{}}; locationAgg.set(e.location_id,la); }
      la.count++; la.products.add(e.product_id); la.qtyByUnit[baseUnit]=(la.qtyByUnit[baseUnit]||0)+baseQty;

      return [
        e.counted_at,m.display_name||"",m.username||"",p.sku||"",p.barcode||"",p.name||"",
        l.code||"",l.name||"",e.quantity,e.unit,e.unit_factor_to_base,e.base_quantity,baseUnit,
        e.count_round,e.revision,e.scan_code,e.device_id,e.recount_task_id||"",e.client_event_id,e.note||"",
      ];
    });

    const memberRows = members.map((m:any) => {
      const a:any=memberAgg.get(m.id)||{count:0,products:new Set(),qtyByUnit:{},last:null};
      return [m.display_name,m.username,m.role,m.status,a.count,a.products.size,JSON.stringify(a.qtyByUnit),a.last||m.last_seen_at||""];
    });
    const locationRows = locations.map((l:any) => {
      const a:any=locationAgg.get(l.id)||{count:0,products:new Set(),qtyByUnit:{}};
      return [l.code,l.name,l.location_type,l.parent_id||"",a.count,a.products.size,JSON.stringify(a.qtyByUnit)];
    });
    const reconciliationRows = lines.map((l:any) => [
      l.product_sku,l.product_name,l.location_path,l.unit,l.expected_quantity,l.counted_quantity,
      l.variance_quantity,l.variance_percent,l.counted_events,l.counter_count,l.result_status,
    ]);
    const runRows = runs.map((r:any) => [
      r.run_number,r.status,r.expected_rows,r.counted_rows,r.matched_rows,r.variance_rows,
      r.uncounted_rows,r.total_expected,r.total_counted,r.entry_count_snapshot,r.created_at,r.computed_at,r.approved_at,
    ]);
    const alertRows = alerts.map((a:any) => [
      a.created_at,a.alert_type,a.severity,a.status,a.title,JSON.stringify(a.details),a.acknowledged_at,a.resolved_at,
    ]);
    const recountRows = recounts.map((t:any) => [
      t.created_at,t.status,t.reason,productMap.get(t.product_id)?.sku||"",productMap.get(t.product_id)?.name||"",
      locationMap.get(t.location_id)?.code||"",locationMap.get(t.location_id)?.name||"",
      memberMap.get(t.assigned_member_id)?.display_name||"",t.first_count_quantity,t.second_count_quantity,
      t.variance_percent,t.assigned_at,t.started_at,t.completed_at,t.reviewed_at,t.notes||"",
    ]);
    const importRows = imports.map((b:any) => [
      b.created_at,b.completed_at,b.source_name,b.source_format,b.status,b.row_count,b.accepted_count,b.rejected_count,JSON.stringify(b.error_report||{}),
    ]);
    const importErrorRows = importErrors.map((r:any) => {
      const batch:any=importBatchMap.get(r.batch_id)||{};
      return [batch.source_name||"",r.row_number,r.sku,r.barcode,r.product_name,r.location_code,
        r.error_codes?.join("|")||"",JSON.stringify(r.error_detail||{}),JSON.stringify(r.raw_row||{})];
    });
    const evidenceRows = sessionImages.map((img:any) => {
      const e:any=entryMap.get(img.entry_id)||{};
      const p:any=productMap.get(e.product_id)||{};
      const l:any=locationMap.get(e.location_id)||{};
      const m:any=memberMap.get(e.member_id)||{};
      return [img.created_at,p.sku||"",p.name||"",l.code||"",l.name||"",m.display_name||"",
        img.caption||"",img.mime_type||"",img.size_bytes||0,img.storage_path,evidenceSignedMap.get(img.storage_path)||""];
    });
    const presenceRows = presence.map((p:any) => {
      const m:any=memberMap.get(p.member_id)||{};
      const l:any=locationMap.get(p.current_location_id)||{};
      const d:any=deviceMap.get(p.device_id)||{};
      return [p.last_seen_at,m.display_name||"",p.presence_state,d.device_label||"",d.platform||"",
        d.app_version||"",d.status||"",l.code||"",l.name||"",p.device_id];
    });
    const auditExportRows = auditRows.map((a:any) => {
      const actor:any=memberByUserId.get(a.actor_id)||{};
      return [a.created_at,actor.display_name||actor.username||a.actor_id,a.action,a.entity_type,a.entity_id,JSON.stringify(a.details||{})];
    });

    const summaryRows = [
      ["اسم الجلسة",session.name],["حالة الجلسة",session.status],["تاريخ البدء",session.started_at||""],
      ["تاريخ الإغلاق",session.closed_at||""],["عدد الأصناف في المشروع",products.length],
      ["عدد المواقع",locations.length],["عدد المندوبين",members.length],["عمليات العد",entries.length],
      ["عدد أسطر التسوية الأخيرة",lines.length],["التنبيه المفتوح",alerts.filter((a:any)=>a.status==="open").length],
      ["مهام إعادة العد",recounts.length],["أخطاء الاستيراد",importErrors.length],["أدلة الصور",sessionImages.length],
      ["الأجهزة والحضور",presence.length],["سجلات التدقيق",auditRows.length],["آخر رقم تسوية",latestRun?.run_number||""],
      ["حالة آخر تسوية",latestRun?.status||""],["الكميات بوحدات الأساس",JSON.stringify(quantityByUnit)],
    ];

    let bytes: Uint8Array;
    let contentType: string;
    let extension = format;
    if (format === "csv") {
      bytes = csvBytes(
        ["وقت العد","المندوب","اسم المستخدم","SKU","الباركود","الصنف","كود الموقع","الموقع","الكمية المدخلة","الوحدة المدخلة","معامل التحويل","الكمية الأساسية","الوحدة الأساسية","جولة العد","المراجعة","كود المسح","الجهاز","مهمة إعادة العد","معرف الحدث","ملاحظات"],
        entryRows,
      );
      contentType = "text/csv; charset=utf-8";
    } else {
      const workbook = XLSX.utils.book_new();
      addSheet(workbook,"ملخص",["المؤشر","القيمة"],summaryRows);
      addSheet(workbook,"عمليات العد",["وقت العد","المندوب","اسم المستخدم","SKU","الباركود","الصنف","كود الموقع","الموقع","الكمية المدخلة","الوحدة المدخلة","معامل التحويل","الكمية الأساسية","الوحدة الأساسية","جولة العد","المراجعة","كود المسح","الجهاز","مهمة إعادة العد","معرف الحدث","ملاحظات"],entryRows);
      addSheet(workbook,"التسوية",["SKU","الصنف","الموقع","الوحدة الأساسية","الدفترية","المعدودة","الفرق","نسبة الفرق %","عمليات العد","عدد المندوبين","الحالة"],reconciliationRows);
      addSheet(workbook,"سجل التسويات",["رقم الجولة","الحالة","مواقع دفترية","مواقع معدودة","مطابق","فروقات","غير معدود","إجمالي دفتري","إجمالي معدود","لقطة عمليات العد","إنشاء","احتساب","اعتماد"],runRows);
      addSheet(workbook,"أداء المندوبين",["المندوب","اسم المستخدم","الدور","الحالة","عمليات العد","أصناف مختلفة","الكميات بوحدات الأساس","آخر نشاط"],memberRows);
      addSheet(workbook,"تغطية المواقع",["كود الموقع","الموقع","النوع","الأب","عمليات العد","أصناف مختلفة","الكميات بوحدات الأساس"],locationRows);
      addSheet(workbook,"التنبيهات",["التاريخ","النوع","الخطورة","الحالة","العنوان","التفاصيل","الإقرار","المعالجة"],alertRows);
      addSheet(workbook,"إعادة العد",["الإنشاء","الحالة","السبب","SKU","الصنف","كود الموقع","الموقع","المندوب","العد الأول","إعادة العد","فرق %","الإسناد","البدء","الإكمال","المراجعة","ملاحظات"],recountRows);
      addSheet(workbook,"دفعات الاستيراد",["الإنشاء","الإكمال","الملف","الصيغة","الحالة","صفوف","مقبول","مرفوض","تقرير الأخطاء"],importRows);
      addSheet(workbook,"أخطاء الاستيراد",["الملف","رقم الصف","SKU","الباركود","الصنف","كود الموقع","رموز الرفض","تفاصيل الخطأ","الصف الأصلي"],importErrorRows);
      addSheet(workbook,"أدلة الصور",["التاريخ","SKU","الصنف","كود الموقع","الموقع","المندوب","الوصف","نوع الملف","الحجم بالبايت","مسار التخزين","رابط مؤقت"],evidenceRows);
      addSheet(workbook,"الأجهزة والحضور",["آخر ظهور","المندوب","حالة الحضور","الجهاز","المنصة","إصدار التطبيق","حالة الجهاز","كود الموقع","الموقع","معرف الجهاز"],presenceRows);
      addSheet(workbook,"سجل التدقيق",["التاريخ","الفاعل","الإجراء","نوع الكيان","معرف الكيان","التفاصيل"],auditExportRows);
      const out = XLSX.write(workbook,{bookType:"xlsx",type:"array",compression:true});
      bytes = out instanceof Uint8Array ? out : new Uint8Array(out);
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    }

    const digest = await crypto.subtle.digest("SHA-256",bytes);
    const sha256 = toHex(digest);
    const fileName = `CountFlow_${session.id}_${new Date().toISOString().slice(0,10)}.${extension}`;
    storagePath = `${session.project_id}/${session.id}/${exportId}-${fileName}`;
    const { error: uploadError } = await admin.storage.from("counting-exports").upload(storagePath,bytes,{
      contentType,upsert:false,cacheControl:"3600",
    });
    if (uploadError) throw new Error("EXPORT_UPLOAD_FAILED: "+uploadError.message);

    const expiresAt = new Date(Date.now()+7*24*60*60*1000).toISOString();
    const { error: updateError } = await admin.from("count_exports").update({
      status:"ready",storage_path:storagePath,row_count:entries.length,file_size_bytes:bytes.byteLength,
      sha256,completed_at:new Date().toISOString(),expires_at:expiresAt,
      metadata:{engine:"counting-export-session-v1",format,entry_rows:entries.length,
        reconciliation_rows:lines.length,products:products.length,locations:locations.length,
        alerts:alerts.length,recounts:recounts.length,imports:imports.length,sheets:format==="xlsx"?13:1},
    }).eq("id",exportId);
    if (updateError) throw new Error("EXPORT_RECORD_UPDATE_FAILED: "+updateError.message);

    const { data: signed, error: signedError } = await admin.storage.from("counting-exports").createSignedUrl(storagePath,7*24*60*60);
    if (signedError || !signed?.signedUrl) throw new Error("EXPORT_SIGNED_URL_FAILED: "+(signedError?.message||"no url"));

    return json({export_id:exportId,status:"ready",file_name:fileName,signed_url:signed.signedUrl,
      row_count:entries.length,file_size_bytes:bytes.byteLength,sha256,expires_at:expiresAt});
  } catch (error) {
    const message = String(error?.message || error);
    if (storagePath && admin) {
      await admin.storage.from("counting-exports").remove([storagePath]);
    }
    if (exportId && admin) {
      await admin.from("count_exports").update({status:"failed",error_message:message,completed_at:new Date().toISOString()}).eq("id",exportId);
    }
    const status = /SUPERVISOR_ACCESS_REQUIRED/.test(message) ? 403 : /EXPORT_LIMIT|EXPORT_COMBINED_ROW_LIMIT/.test(message) ? 413 : 500;
    return json({error:message},status);
  }
});
