// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import * as XLSX from "npm:xlsx@0.18.5";
import { zipSync, strToU8 } from "npm:fflate@0.8.2";

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

function xmlEscape(value: unknown) {
  return String(value ?? "").replace(/[&<>"']/g, ch => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&apos;",
  }[ch] as string));
}
function decimalToScaled(value: unknown, scale: number): bigint | null {
  if (value === null || value === undefined || value === "") return null;
  const raw = String(value).trim();
  const match = raw.match(/^([+-]?)([0-9]+)(?:\.([0-9]*))?$/);
  if (!match) throw new Error("INVALID_DECIMAL_VALUE");
  const factor = 10n ** BigInt(scale);
  const sign = match[1] === "-" ? -1n : 1n;
  const whole = BigInt(match[2]) * factor;
  const fraction = match[3] || "";
  const kept = fraction.slice(0, scale).padEnd(scale, "0");
  let result = whole + BigInt(kept || "0");
  if (fraction.length > scale && fraction[scale] >= "5") result += 1n;
  return sign * result;
}
function roundDivide(numerator: bigint, denominator: bigint): bigint {
  if (denominator <= 0n) throw new Error("INVALID_DECIMAL_DENOMINATOR");
  if (numerator < 0n) return -roundDivide(-numerator, denominator);
  return (numerator + denominator / 2n) / denominator;
}
function scaledToNumber(value: bigint, scale: number): number {
  return Number(value) / Number(10n ** BigInt(scale));
}
function excelColumn(index: number) {
  let n=index+1, out="";
  while(n>0){const r=(n-1)%26;out=String.fromCharCode(65+r)+out;n=Math.floor((n-1)/26);}
  return out;
}
function clientSheetXml(rows: unknown[][], widths: number[], options: {filter?:boolean, drawing?:boolean, imageRows?:Set<number>} = {}) {
  const maxCols=Math.max(widths.length,...rows.map(r=>r.length),1);
  const cols=widths.map((w,i)=>'<col min="'+(i+1)+'" max="'+(i+1)+'" width="'+w+'" customWidth="1"/>').join("");
  const sheetRows=rows.map((row,ri)=>{
    const cells=row.map((value,ci)=>{
      const ref=excelColumn(ci)+(ri+1);
      if(value===null||value===undefined||value==="")return '<c r="'+ref+'"/>';
      if(typeof value==="number"&&Number.isFinite(value)){
        const style=ri===0?1:2;
        return '<c r="'+ref+'" s="'+style+'" t="n"><v>'+String(value)+'</v></c>';
      }
      const text=xmlEscape(value);
      return '<c r="'+ref+'" s="'+(ri===0?1:0)+'" t="inlineStr"><is><t xml:space="preserve">'+text+'</t></is></c>';
    }).join("");
    const isImageRow=options.imageRows?.has(ri+1);
    const height=ri===0?28:(isImageRow?62:22);
    return '<row r="'+(ri+1)+'" ht="'+height+'" customHeight="1">'+cells+'</row>';
  }).join("");
  const last=excelColumn(maxCols-1)+Math.max(1,rows.length);
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'+
    '<sheetViews><sheetView workbookViewId="0" rightToLeft="1"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'+
    '<cols>'+cols+'</cols><sheetData>'+sheetRows+'</sheetData>'+
    (options.filter?'<autoFilter ref="A1:'+last+'"/>':'')+
    (options.drawing?'<drawing r:id="rId1"/>':'')+
    '<pageMargins left="0.25" right="0.25" top="0.5" bottom="0.5" header="0.2" footer="0.2"/>'+
    '</worksheet>';
}
function buildClientBalanceXlsx(sheets: Array<{name:string,rows:unknown[][],widths:number[]}>, embeddedImages:Array<{row:number,extension:string,bytes:Uint8Array}>) {
  const files:Record<string,Uint8Array>={};
  const contentOverrides=sheets.map((_,i)=>'<Override PartName="/xl/worksheets/sheet'+(i+1)+'.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join("");
  const hasImages=embeddedImages.length>0;
  const mediaDefaults=hasImages?'<Default Extension="png" ContentType="image/png"/><Default Extension="jpg" ContentType="image/jpeg"/>':'';
  const drawingOverride=hasImages?'<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>':'';
  files["[Content_Types].xml"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'+
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'+
    '<Default Extension="xml" ContentType="application/xml"/>'+mediaDefaults+
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'+
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'+
    contentOverrides+drawingOverride+
    '</Types>');
  files["_rels/.rels"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'+
    '</Relationships>');
  const sheetNodes=sheets.map((s,i)=>'<sheet name="'+xmlEscape(s.name)+'" sheetId="'+(i+1)+'" r:id="rId'+(i+1)+'"/>').join("");
  files["xl/workbook.xml"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'+
    '<bookViews><workbookView/></bookViews><sheets>'+sheetNodes+'</sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>');
  const relNodes=sheets.map((_,i)=>'<Relationship Id="rId'+(i+1)+'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet'+(i+1)+'.xml"/>').join("");
  files["xl/_rels/workbook.xml.rels"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+relNodes+
    '<Relationship Id="rId'+(sheets.length+1)+'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'+
    '</Relationships>');
  files["xl/styles.xml"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'+
    '<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.######;[Red](#,##0.######);-"/></numFmts>'+
    '<fonts count="2"><font><sz val="10"/><name val="Arial"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="10"/><name val="Arial"/></font></fonts>'+
    '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1F4E78"/><bgColor indexed="64"/></patternFill></fill></fills>'+
    '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"><color rgb="FFD9E2F3"/></left><right style="thin"><color rgb="FFD9E2F3"/></right><top style="thin"><color rgb="FFD9E2F3"/></top><bottom style="thin"><color rgb="FFD9E2F3"/></bottom><diagonal/></border></borders>'+
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'+
    '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/><xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/></cellXfs>'+
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>');
  for(let i=0;i<sheets.length;i++){
    const sheet=sheets[i];
    const imageRows=i===1?new Set(embeddedImages.map(im=>im.row)):new Set<number>();
    const xml=clientSheetXml(sheet.rows,sheet.widths,{filter:true,drawing:i===1&&hasImages,imageRows});
    files["xl/worksheets/sheet"+(i+1)+".xml"]=strToU8(xml);
    if(i===1&&hasImages){
      files["xl/worksheets/_rels/sheet2.xml.rels"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/>'+
        '</Relationships>');
    }
  }
  if(hasImages){
    const anchors:string[]=[];
    const rels:string[]=[];
    embeddedImages.forEach((im,i)=>{
      const id=i+1,fromRow=im.row-1,toRow=im.row;
      anchors.push('<xdr:twoCellAnchor editAs="oneCell"><xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>'+fromRow+'</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:to><xdr:col>1</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>'+toRow+'</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>'+
        '<xdr:pic><xdr:nvPicPr><xdr:cNvPr id="'+id+'" name="Product image '+id+'"/><xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>'+
        '<xdr:blipFill><a:blip r:embed="rId'+id+'"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'+
        '<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="850000" cy="620000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic><xdr:clientData/></xdr:twoCellAnchor>');
      rels.push('<Relationship Id="rId'+id+'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image'+id+'.'+im.extension+'"/>');
      files["xl/media/image"+id+"."+im.extension]=im.bytes;
    });
    files["xl/drawings/drawing1.xml"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
      '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'+anchors.join("")+'</xdr:wsDr>');
    files["xl/drawings/_rels/drawing1.xml.rels"]=strToU8('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+rels.join("")+'</Relationships>');
  }
  return zipSync(files,{level:6});
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
    const scope = String(body?.scope || "full").toLowerCase();
    if (!/^[0-9a-f-]{36}$/i.test(sessionId)) return json({ error: "INVALID_SESSION_ID" }, 400);
    if (!["xlsx", "csv"].includes(format)) return json({ error: "UNSUPPORTED_EXPORT_FORMAT" }, 400);
    if (!["full", "client_balance"].includes(scope)) return json({ error: "UNSUPPORTED_EXPORT_SCOPE" }, 400);
    if (scope === "client_balance" && format !== "xlsx") return json({ error: "CLIENT_BALANCE_REQUIRES_XLSX" }, 400);

    admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: session, error: sessionError } = await admin.from("count_sessions")
      .select("id,project_id,name,status,started_at,closed_at")
      .eq("id", sessionId).maybeSingle();
    if (sessionError || !session) return json({ error: "SESSION_NOT_FOUND" }, 404);

    const isPlatformOwner =
      String(user.email || "").trim().toLowerCase() === "owner@rawaea.com" &&
      Boolean(user.email_confirmed_at);
    if (!isPlatformOwner) {
      const { data: member, error: memberError } = await admin.from("count_members")
        .select("id,role,status")
        .eq("project_id", session.project_id).eq("user_id", user.id)
        .eq("role", "supervisor").eq("status", "active").maybeSingle();
      if (memberError || !member) return json({ error: "SUPERVISOR_ACCESS_REQUIRED" }, 403);
    }

    const { data: exportRow, error: createError } = await admin.from("count_exports").insert({
      project_id: session.project_id,
      session_id: session.id,
      requested_by: user.id,
      export_format: format,
      export_scope: scope,
      status: "processing",
      metadata: { requested_at: new Date().toISOString(), engine: "counting-export-session-v1" },
    }).select("id").single();
    if (createError || !exportRow) throw new Error("EXPORT_RECORD_CREATE_FAILED: " + (createError?.message || "unknown"));
    exportId = exportRow.id;


    if (scope === "client_balance") {
      const runs = await fetchAll(admin,"count_reconciliation_runs",
        "id,run_number,status,expected_rows,counted_rows,matched_rows,variance_rows,uncounted_rows,created_at,computed_at,approved_at",
        [["session_id","eq",sessionId]],10000,"run_number");
      const latestRun = [...runs].sort((a:any,b:any)=>Number(b.run_number)-Number(a.run_number))[0] || null;
      if (!latestRun || latestRun.status !== "approved") {
        throw new Error("CLIENT_BALANCE_REQUIRES_APPROVED_RECONCILIATION");
      }
      const {data:engagement,error:engagementError}=await admin.from("count_projects")
        .select("id,name,code").eq("id",session.project_id).maybeSingle();
      if(engagementError||!engagement)throw new Error("CLIENT_BALANCE_ENGAGEMENT_NOT_FOUND");
      const [lines, locations, importBatches, costs, countEntries] = await Promise.all([
        fetchAll(admin,"count_reconciliation_lines",
          "id,run_id,product_id,location_id,product_sku,product_name,location_path,unit,expected_quantity,counted_quantity,variance_quantity,result_status,computed_at",
          [["run_id","eq",latestRun.id]],MAX_LINES),
        fetchAll(admin,"count_locations",
          "id,code,name,location_type,parent_id,sort_order",
          [["project_id","eq",session.project_id]],MAX_LOCATIONS),
        fetchAll(admin,"count_import_batches",
          "id,source_name,source_format,row_count,accepted_count,rejected_count,status,created_at,completed_at,error_report",
          [["session_id","eq",sessionId]],50000),
        fetchAll(admin,"count_session_product_costs",
          "id,product_id,purchase_unit_cost,currency_code,purchase_unit,unit_factor_to_base,source_type,source_reference,source_date,warning_codes,source_batch_id,updated_at",
          [["session_id","eq",sessionId]],MAX_PRODUCTS),
        fetchAll(admin,"count_entries",
          "id,product_id,location_id,quantity,unit,unit_factor_to_base,base_quantity,counted_at,count_round,revision,scan_code,recount_task_id,note",
          [["session_id","eq",sessionId]],MAX_ENTRIES,"counted_at"),
      ]);
      const importBatchIds=importBatches.map((b:any)=>b.id);
      const committedImportRows:any[]=[];
      for(let offset=0;offset<importBatchIds.length;offset+=500){
        const chunk=importBatchIds.slice(offset,offset+500);
        committedImportRows.push(...await fetchAll(admin,"count_import_rows",
          "id,batch_id,product_id,sku,barcode,product_name,base_unit,row_number,warning_codes",
          [["batch_id","in",chunk],["row_status","eq","committed"]],MAX_PRODUCTS));
        if(committedImportRows.length>MAX_PRODUCTS)throw new Error("CLIENT_BALANCE_PRODUCT_LIMIT:"+MAX_PRODUCTS);
      }
      const productIds=new Set<string>();
      for(const line of lines)productIds.add(line.product_id);
      for(const row of committedImportRows)if(row.product_id)productIds.add(row.product_id);
      for(const cost of costs)productIds.add(cost.product_id);
      for(const entry of countEntries)productIds.add(entry.product_id);
      if(productIds.size>MAX_PRODUCTS)throw new Error("CLIENT_BALANCE_PRODUCT_LIMIT:"+MAX_PRODUCTS);

      const productIdArray=[...productIds];
      const products:any[]=[];
      for(let offset=0;offset<productIdArray.length;offset+=500){
        const chunk=productIdArray.slice(offset,offset+500);
        products.push(...await fetchAll(admin,"count_products",
          "id,sku,barcode,name,category,base_unit,units,image_url,is_active",
          [["project_id","eq",session.project_id],["id","in",chunk]],MAX_PRODUCTS));
      }
      const productMap=new Map(products.map((p:any)=>[p.id,p]));
      const locationMap=new Map(locations.map((l:any)=>[l.id,l]));
      const costMap=new Map(costs.map((c:any)=>[c.product_id,c]));
      const locationPath=(locationId:string|null)=>{
        if(!locationId)return "موقع غير محدد";
        const chain:any[]=[];const seen=new Set<string>();let node:any=locationMap.get(locationId);
        while(node&&!seen.has(node.id)){seen.add(node.id);chain.unshift(node);node=node.parent_id?locationMap.get(node.parent_id):null;}
        return chain.map(x=>(x.code?x.code+" · ":"")+x.name).join(" / ")||"موقع غير معروف";
      };
      const unitRows:any[][]=[[
        "SKU","الباركود","الصنف","الفرع / المخزن / الموقع","الكمية التي أدخلها العداد",
        "وحدة العد","معامل التحويل إلى الوحدة الأساسية","الكمية المحولة إلى الوحدة الأساسية",
        "الوحدة الأساسية","جولة العد","رقم المراجعة","تاريخ/وقت التسجيل","كود المسح","مهمة إعادة العد","ملاحظات",
      ]];
      for(const entry of [...countEntries].sort((a:any,b:any)=>String(a.counted_at||"").localeCompare(String(b.counted_at||"")))){
        const product:any=productMap.get(entry.product_id)||{};
        unitRows.push([
          product.sku||"",product.barcode||"",product.name||"",
          locationPath(entry.location_id),Number(entry.quantity),entry.unit||"",
          Number(entry.unit_factor_to_base),entry.base_quantity===null?null:Number(entry.base_quantity),
          product.base_unit||"",entry.count_round,entry.revision,entry.counted_at||"",
          entry.scan_code||"",entry.recount_task_id||"",entry.note||"",
        ]);
      }
      const linesByProduct=new Map<string,any[]>();
      for(const line of lines){if(!linesByProduct.has(line.product_id))linesByProduct.set(line.product_id,[]);linesByProduct.get(line.product_id)!.push(line);}
      const importsByProduct=new Map<string,any[]>();
      for(const row of committedImportRows){if(row.product_id){if(!importsByProduct.has(row.product_id))importsByProduct.set(row.product_id,[]);importsByProduct.get(row.product_id)!.push(row);}}
      const importWarningCount=committedImportRows.reduce((n:number,r:any)=>n+(Array.isArray(r.warning_codes)&&r.warning_codes.length?1:0),0);
      const imageByProduct=new Map<string,{status:string,extension?:string,bytes?:Uint8Array,reference:string}>();
      const embeddedImages:Array<{row:number,extension:string,bytes:Uint8Array}>=[];
      let embeddedBytes=0;
      for(const product of products){
        const reference=String(product.image_url||"");
        if(!reference){imageByProduct.set(product.id,{status:"لا توجد صورة",reference:""});continue;}
        if(/^https:\/\//i.test(reference)){
          imageByProduct.set(product.id,{status:"رابط خارجي - لم يتم تضمينه",reference});continue;
        }
        if(!reference.startsWith(session.project_id+"/")||reference.includes("..")||reference.includes("\\")||reference.includes("?")){
          imageByProduct.set(product.id,{status:"مرجع تخزين غير صالح",reference});continue;
        }
        if(embeddedImages.length>=500){imageByProduct.set(product.id,{status:"تجاوز حد تضمين الصور",reference});continue;}
        try{
          const {data:blob,error}=await admin.storage.from("counting-product-images").download(reference);
          if(error||!blob){imageByProduct.set(product.id,{status:"تعذر تحميل الصورة",reference});continue;}
          if(blob.size>1024*1024){imageByProduct.set(product.id,{status:"حجم الصورة أكبر من 1MB",reference});continue;}
          const mime=String(blob.type||"").toLowerCase();
          const extension=mime==="image/png"?"png":mime==="image/jpeg"?"jpg":"";
          if(!extension){imageByProduct.set(product.id,{status:"صيغة غير مدعومة للتضمين (PNG/JPEG فقط)",reference});continue;}
          if(embeddedBytes+blob.size>12*1024*1024){imageByProduct.set(product.id,{status:"تجاوز حد حجم الصور الإجمالي",reference});continue;}
          const bytes=new Uint8Array(await blob.arrayBuffer());
          embeddedBytes+=bytes.byteLength;
          imageByProduct.set(product.id,{status:"مضمنة داخل Excel",extension,bytes,reference});
        }catch(_){imageByProduct.set(product.id,{status:"تعذر تحميل الصورة",reference});}
      }

      const clientRows:any[][]=[[
        "الصورة","SKU","الباركود","اسم الصنف","التصنيف","الرصيد الفعلي المكتمل",
        "الوحدة الأساسية","حالة اكتمال الكمية","الكمية المعروفة من المواقع المعدودة فقط",
        "سعر الشراء","وحدة الشراء","العملة","معامل التحويل إلى الوحدة الأساسية",
        "تكلفة الوحدة الأساسية","قيمة الرصيد","نوع مصدر السعر","مرجع مصدر السعر",
        "تاريخ السعر","حالة الصورة","مرجع الصورة","المواقع المعدودة","المواقع غير المعدودة",
      ]];
      const locationRows:any[][]=[[
        "SKU","الباركود","الصنف","الفرع / المخزن / الموقع","الوحدة الأساسية",
        "الرصيد الدفتري المرجعي","الكمية المعدودة","الفرق","حالة الموقع",
      ]];
      const gapRows:any[][]=[["SKU","الباركود","الصنف","الموقع","نوع الفجوة","التفاصيل","الإجراء المقترح"]];
      const currencyTotals=new Map<string,{valueMicro:bigint,products:number}>();
      let fullyCountedProducts=0,partiallyCountedProducts=0,notCountedProducts=0;
      let fullyPricedProducts=0,unpricedProducts=0,valueEligibleProducts=0;
      let embeddedCount=0,notEmbeddedCount=0,completeQuantityProducts=0;
      let knownCountedQuantityProducts=0;
      for(const product of products){
        const productLines=(linesByProduct.get(product.id)||[]).sort((a:any,b:any)=>String(a.location_path||"").localeCompare(String(b.location_path||"")));
        const countedLines=productLines.filter((l:any)=>l.counted_quantity!==null&&l.counted_quantity!==undefined);
        const uncountedLines=productLines.filter((l:any)=>l.counted_quantity===null||l.counted_quantity===undefined||l.result_status==="not_counted");
        const isCountComplete=productLines.length>0&&uncountedLines.length===0;
        const partialQuantityScaled=countedLines.reduce((sum:bigint,l:any)=>sum+(decimalToScaled(l.counted_quantity,4)??0n),0n);
        const partialQuantity=scaledToNumber(partialQuantityScaled,4);
        const actualQuantityScaled=isCountComplete?partialQuantityScaled:null;
        const actualQuantity=actualQuantityScaled===null?null:scaledToNumber(actualQuantityScaled,4);
        const cost:any=costMap.get(product.id)||null;
        const costFields={
          price:cost?.purchase_unit_cost,
          currency:cost?.currency_code,
          purchaseUnit:cost?.purchase_unit,
          factor:cost?.unit_factor_to_base,
          sourceType:cost?.source_type,
          sourceReference:cost?.source_reference,
        };
        const missingCostFields=Object.entries(costFields).filter(([_,v])=>v===null||v===undefined||v==="").map(([k])=>k);
        const costWarnings=Array.isArray(cost?.warning_codes)?cost.warning_codes:[];
        const blockingCostWarnings=costWarnings.filter((w:string)=>[
          "COST_DATA_INCOMPLETE","INVALID_PURCHASE_UNIT_COST","INVALID_CURRENCY_CODE",
          "INVALID_UNIT_FACTOR","COST_REQUIRES_OPERATION_SCOPE","CONFLICTING_COST_SNAPSHOT_IN_BATCH"
        ].includes(w));
        const purchasePriceMicro=cost?decimalToScaled(cost.purchase_unit_cost,6):null;
        const purchaseUnitFactorMicro=cost?decimalToScaled(cost.unit_factor_to_base,6):null;
        const isCostComplete=!!cost&&missingCostFields.length===0
          &&purchaseUnitFactorMicro!==null&&purchaseUnitFactorMicro>0n
          &&purchasePriceMicro!==null&&purchasePriceMicro>=0n
          &&blockingCostWarnings.length===0;
        const baseUnitCostMicro=isCostComplete
          ?roundDivide(purchasePriceMicro!*1000000n,purchaseUnitFactorMicro!)
          :null;
        const baseUnitCost=baseUnitCostMicro===null?null:scaledToNumber(baseUnitCostMicro,6);
        const lineValueMicro=isCostComplete&&actualQuantityScaled!==null
          ?roundDivide(actualQuantityScaled*baseUnitCostMicro!,10000n)
          :null;
        const lineValue=lineValueMicro===null?null:scaledToNumber(lineValueMicro,6);
        const photo=imageByProduct.get(product.id)||{status:"لا توجد صورة",reference:""};
        if(photo.bytes&&photo.extension){embeddedImages.push({row:clientRows.length+1,extension:photo.extension,bytes:photo.bytes});embeddedCount++;}
        else notEmbeddedCount++;
        if(isCountComplete){fullyCountedProducts++;completeQuantityProducts++;}else if(productLines.length){partiallyCountedProducts++;if(countedLines.length)knownCountedQuantityProducts++;}else{notCountedProducts++;}
        if(isCostComplete)fullyPricedProducts++;else unpricedProducts++;
        if(lineValueMicro!==null){
          valueEligibleProducts++;
          const currency=String(cost.currency_code);
          const agg=currencyTotals.get(currency)||{valueMicro:0n,products:0};
          agg.valueMicro+=lineValueMicro;agg.products++;currencyTotals.set(currency,agg);
        }

        if(!product.name)gapRows.push([product.sku||"",product.barcode||"","", "", "اسم الصنف غير مكتمل","لا يوجد اسم وصفي محفوظ للصنف","استكمال الاسم من مصدر العميل"]);
        if(!photo.bytes)gapRows.push([product.sku||"",product.barcode||"",product.name||"","", "الصورة غير مضمنة",photo.status+" · "+photo.reference,"رفع صورة واضحة بصيغة PNG/JPEG"]);
        if(!cost){
          gapRows.push([product.sku||"",product.barcode||"",product.name||"","", "بيانات التكلفة غير متوفرة","لا توجد لقطة تكلفة لهذه العملية","استيراد/توثيق سعر الشراء ومصدره ووحدته وعملته ومعامل تحويله"]);
        }else if(!isCostComplete){
          gapRows.push([product.sku||"",product.barcode||"",product.name||"","", "بيانات التكلفة غير مكتملة","الحقول الناقصة: "+missingCostFields.join("، ")+" · تنبيهات: "+costWarnings.join("، "),"استكمال الحقول الناقصة أو حل تعارض مصادر السعر قبل احتساب قيمة الرصيد"]);
        }else if(costWarnings.length){
          gapRows.push([product.sku||"",product.barcode||"",product.name||"","", "تنبيهات مصدر التكلفة",costWarnings.join("، "),"مراجعة التنبيهات المرجعية وتحديث بيانات السعر عند الحاجة"]);
        }
        if(!productLines.length){
          gapRows.push([product.sku||"",product.barcode||"",product.name||"","", "لا توجد نتيجة عد","الصنف موجود في استيراد العملية لكن لا توجد له نتيجة في جولة التسوية المعتمدة","تحديد موقعه وإتمام العد ثم اعتماد جولة تسوية جديدة"]);
        }else if(uncountedLines.length){
          for(const l of uncountedLines){
            const loc=locationPath(l.location_id);
            gapRows.push([product.sku||"",product.barcode||"",product.name||"",loc,"موقع لم يكتمل عده","لا توجد كمية معدودة معتمدة لهذا الموقع؛ لم تُعامل على أنها صفر","إتمام العد/إعادة العد للموقع ثم إعادة التسوية"]);
          }
        }
        if(!product.base_unit)gapRows.push([product.sku||"",product.barcode||"",product.name||"","", "وحدة أساسية غير متاحة","تعذر تحديد الوحدة الأساسية للصنف","استكمال الوحدة والتحقق من تحويلات الوحدات"]);

        clientRows.push([
          "",product.sku||"",product.barcode||"",product.name||"",product.category||"",
          actualQuantity,product.base_unit||"",isCountComplete?"مكتمل":productLines.length?"غير مكتمل - مواقع ناقصة":"لم يسجل عد",
          countedLines.length?partialQuantity:null,
          isCostComplete?Number(cost.purchase_unit_cost):null,cost?.purchase_unit||"",
          cost?.currency_code||"",isCostComplete?Number(cost.unit_factor_to_base):null,
          baseUnitCost,lineValue,cost?.source_type||"",cost?.source_reference||"",
          cost?.source_date||"",photo.status,photo.reference,
          countedLines.map((l:any)=>locationPath(l.location_id)).join(" | "),
          uncountedLines.map((l:any)=>locationPath(l.location_id)).join(" | "),
        ]);
        if(productLines.length){
          for(const l of productLines){
            locationRows.push([
              product.sku||"",product.barcode||"",product.name||"",locationPath(l.location_id),
              product.base_unit||l.unit||"",l.expected_quantity===null?null:Number(l.expected_quantity),
              l.counted_quantity===null?null:Number(l.counted_quantity),
              l.variance_quantity===null?null:Number(l.variance_quantity),
              l.counted_quantity===null||l.counted_quantity===undefined?"غير معدود":l.result_status,
            ]);
          }
        }else{
          locationRows.push([product.sku||"",product.barcode||"",product.name||"","لم يسجل موقع/عد",product.base_unit||"",null,null,null,"لم يسجل عد"]);
        }
      }
      for(const row of committedImportRows){
        const warnings=Array.isArray(row.warning_codes)?row.warning_codes:[];
        if(!warnings.length)continue;
        const p:any=productMap.get(row.product_id)||{};
        const batch:any=importBatches.find((x:any)=>x.id===row.batch_id)||{};
        gapRows.push([
          p.sku||row.sku||"",p.barcode||row.barcode||"",p.name||row.product_name||"",
          row.location_id?locationPath(row.location_id):"",
          "تنبيهات بيانات الاستيراد",
          (batch.source_name||"ملف غير محدد")+" · الصف "+row.row_number+" · "+warnings.join("، "),
          warnings.includes("CONFLICTING_COST_SNAPSHOT_IN_BATCH")
            ?"تحديد مصدر تكلفة واحد لكل نطاق صنف/موقع أو توثيق التكلفة الصحيحة يدوياً قبل التقييم"
            :"استكمال الحقول الناقصة أو تصحيحها ثم إعادة استيراد البيانات"
        ]);
      }
      for(const batch of importBatches){
        if((batch.rejected_count||0)>0)gapRows.push(["","","","", "صفوف مرفوضة في الاستيراد",batch.source_name+" · عدد الصفوف المرفوضة: "+batch.rejected_count,"مراجعة أخطاء الاستيراد وإعادة إدخال الصفوف الصحيحة"]);
      }
      const summaryRows:any[][]=[
        ["مؤشر التقرير","القيمة","العملة","إجمالي القيمة المشتقة"],
        ["اسم الجهة/التكليف",engagement.name,"",""],
        ["رقم التكليف",engagement.code||"","", ""],
        ["اسم العملية",session.name,"",""],
        ["حالة العملية",session.status,"",""],
        ["رقم جولة التسوية المعتمدة",latestRun.run_number,"",""],
        ["تاريخ اعتماد التسوية",latestRun.approved_at||"",""],
        ["عدد الأصناف المشمولة",products.length,"",""],
        ["أصناف اكتمل عد جميع مواقعها",fullyCountedProducts,"",""],
        ["أصناف بعدّ جزئي/مواقع ناقصة",partiallyCountedProducts,"",""],
        ["أصناف لم يسجل لها عد",notCountedProducts,"",""],
        ["أصناف لها تكلفة مكتملة المصدر",fullyPricedProducts,"",""],
        ["أصناف بلا/بتكلفة غير مكتملة",unpricedProducts,"",""],
        ["أصناف أمكن احتساب قيمة لها",valueEligibleProducts,"",""],
        ["عدد أحداث العد المسجلة",countEntries.length,"",""],
        ["تفاصيل الوحدات", "تتضمن جميع أحداث التسجيل وجولات العد؛ الرصيد النهائي المعتمد في ورقة الرصيد الفعلي","",""],
        ["صور مضمنة داخل المصنف",embeddedCount,"",""],
        ["صور غير مضمنة/مفقودة",notEmbeddedCount,"",""],
        ["صفوف استيراد تحمل تنبيهات",importWarningCount,"",""],
        ["سياسة التسعير المعتمدة","UNKNOWN - لم تُعتمد بعد","",""],
        ["منهج القيمة","قيمة مشتقة من سعر الشراء المقدم ÷ معامل التحويل؛ ليست قيداً أو تقييماً محاسبياً معتمداً","",""],
        ["قاعدة النقص في العد","الموقع غير المعدود لا يُسجل صفراً؛ الرصيد الإجمالي يبقى فارغاً عند نقص أي موقع ضمن نطاق الصنف","",""],
      ];
      for(const [currency,total] of [...currencyTotals.entries()].sort((a,b)=>a[0].localeCompare(b[0]))){
        summaryRows.push(["قيمة الأصناف المكتملة التسعير",total.products,currency,scaledToNumber(total.valueMicro,6)]);
      }
      const workbookBytes=buildClientBalanceXlsx([
        {name:"ملخص العميل",rows:summaryRows,widths:[38,58,14,24]},
        {name:"الرصيد الفعلي",rows:clientRows,widths:[12,18,20,32,20,22,18,24,24,18,18,12,24,22,22,22,28,16,25,24,48,48]},
        {name:"تفاصيل وحدات العد",rows:unitRows,widths:[18,20,32,58,22,18,26,28,18,14,14,24,20,24,40]},
        {name:"تفصيل المواقع",rows:locationRows,widths:[18,20,32,58,18,22,22,18,22]},
        {name:"استكمالات البيانات",rows:gapRows,widths:[18,20,32,58,28,72,70]},
      ],embeddedImages);
      if(workbookBytes.byteLength>50*1024*1024)throw new Error("CLIENT_BALANCE_EXPORT_EXCEEDS_50MB");
      const bytes=workbookBytes instanceof Uint8Array?workbookBytes:new Uint8Array(workbookBytes);
      const digest=await crypto.subtle.digest("SHA-256",bytes);
      const sha256=toHex(digest);
      const extension="xlsx";
      const fileName="CountFlow_ClientBalance_"+session.id+"_"+new Date().toISOString().slice(0,10)+".xlsx";
      storagePath=session.project_id+"/"+session.id+"/"+exportId+"-"+fileName;
      const contentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
      const {error:uploadError}=await admin.storage.from("counting-exports").upload(storagePath,bytes,{
        contentType,upsert:false,cacheControl:"3600",
      });
      if(uploadError)throw new Error("CLIENT_BALANCE_UPLOAD_FAILED: "+uploadError.message);
      const expiresAt=new Date(Date.now()+7*24*60*60*1000).toISOString();
      const metadata={
        engine:"counting-client-balance-ooxml-v1",format:"xlsx",scope:"client_balance",
        reconciliation_run_id:latestRun.id,reconciliation_run_number:latestRun.run_number,
        products:products.length,unit_count_rows:unitRows.length-1,location_rows:locationRows.length-1,gap_rows:gapRows.length-1,
        count_events:countEntries.length,images_embedded:embeddedCount,images_not_embedded:notEmbeddedCount,embedded_image_bytes:embeddedBytes,
        complete_quantity_products:fullyCountedProducts,partial_quantity_products:partiallyCountedProducts,
        not_counted_products:notCountedProducts,fully_priced_products:fullyPricedProducts,
        unpriced_products:unpricedProducts,value_eligible_products:valueEligibleProducts,
        currency_totals:[...currencyTotals.entries()].map(([currency,v])=>({
          currency,products:v.products,value:scaledToNumber(v.valueMicro,6),
          value_scaled_micro:v.valueMicro.toString(),scale:6
        })),
        pricing_policy:"UNKNOWN",
      };
      const {error:updateError}=await admin.from("count_exports").update({
        status:"ready",storage_path:storagePath,row_count:products.length,file_size_bytes:bytes.byteLength,
        sha256,completed_at:new Date().toISOString(),expires_at:expiresAt,metadata,
      }).eq("id",exportId);
      if(updateError)throw new Error("CLIENT_BALANCE_RECORD_UPDATE_FAILED: "+updateError.message);
      const {data:signed,error:signedError}=await admin.storage.from("counting-exports").createSignedUrl(storagePath,7*24*60*60);
      if(signedError||!signed?.signedUrl)throw new Error("CLIENT_BALANCE_SIGNED_URL_FAILED: "+(signedError?.message||"no url"));
      const {error:auditError}=await admin.from("count_audit_log").insert({
        project_id:session.project_id,actor_id:user.id,action:"export.client_balance.ready",
        entity_type:"count_export",entity_id:exportId,
        details:{session_id:session.id,scope:"client_balance",reconciliation_run_id:latestRun.id,
          products:products.length,count_events:countEntries.length,images_embedded:embeddedCount,images_not_embedded:notEmbeddedCount,
          value_eligible_products:valueEligibleProducts,sha256}
      });
      if(auditError)throw new Error("CLIENT_BALANCE_AUDIT_WRITE_FAILED: "+auditError.message);
      return json({
        export_id:exportId,status:"ready",scope:"client_balance",file_name:fileName,
        signed_url:signed.signedUrl,row_count:products.length,file_size_bytes:bytes.byteLength,
        sha256,expires_at:expiresAt,images_embedded:embeddedCount,images_not_embedded:notEmbeddedCount,
        count_events:countEntries.length,products_fully_counted:fullyCountedProducts,products_with_incomplete_cost:unpricedProducts,
        pricing_policy:"UNKNOWN"
      });
    }

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
        alerts:alerts.length,recounts:recounts.length,imports:imports.length,import_error_rows:importErrors.length,
        evidence_images:sessionImages.length,presence_rows:presence.length,audit_rows:auditRows.length,
        sheets:format==="xlsx"?13:1},
    }).eq("id",exportId);
    if (updateError) throw new Error("EXPORT_RECORD_UPDATE_FAILED: "+updateError.message);

    const { data: signed, error: signedError } = await admin.storage.from("counting-exports").createSignedUrl(storagePath,7*24*60*60);
    if (signedError || !signed?.signedUrl) throw new Error("EXPORT_SIGNED_URL_FAILED: "+(signedError?.message||"no url"));
    const { error: auditError } = await admin.from("count_audit_log").insert({
      project_id:session.project_id,actor_id:user.id,action:"export.ready",entity_type:"count_export",entity_id:exportId,
      details:{session_id:session.id,format,row_count:entries.length,file_size_bytes:bytes.byteLength,sha256,
        import_error_rows:importErrors.length,evidence_images:sessionImages.length,presence_rows:presence.length,audit_rows:auditRows.length}
    });
    if (auditError) throw new Error("EXPORT_AUDIT_WRITE_FAILED: "+auditError.message);

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
    const status = /SUPERVISOR_ACCESS_REQUIRED/.test(message) ? 403 :
      /CLIENT_BALANCE_REQUIRES_APPROVED_RECONCILIATION/.test(message) ? 409 :
      /EXPORT_LIMIT|EXPORT_COMBINED_ROW_LIMIT|CLIENT_BALANCE_PRODUCT_LIMIT|CLIENT_BALANCE_EXPORT_EXCEEDS_50MB/.test(message) ? 413 : 500;
    return json({error:message},status);
  }
});
