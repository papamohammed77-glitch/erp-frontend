import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import vm from "node:vm";
import { spawnSync } from "node:child_process";

const root = process.cwd();
const buyerPath = path.join(root, "companies/company-1/purchasing/buyer.html");
const edgePath = path.join(root, "supabase/functions/save-purchase-order/index.ts");
const migrationPath = path.join(root, "supabase/migrations/20261109201500_buyer_quick_market_supplier_return_custody.sql");
const buyer = fs.readFileSync(buyerPath, "utf8");
const edge = fs.readFileSync(edgePath, "utf8");
const sql = fs.readFileSync(migrationPath, "utf8");

// Buyer inline JavaScript syntax check. External and non-JavaScript script tags are ignored.
const inlineScripts = [];
for (const match of buyer.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
  const attrs = match[1] || "";
  const source = match[2] || "";
  if (/\bsrc\s*=/.test(attrs) || !source.trim()) continue;
  const type = (attrs.match(/\btype\s*=\s*["']?([^"'\s>]+)/i) || [])[1] || "";
  if (type && !/(javascript|ecmascript|module)/i.test(type)) continue;
  inlineScripts.push(source);
}
assert.ok(inlineScripts.length > 0, "Buyer inline scripts were not found");
for (const [i, source] of inlineScripts.entries()) {
  const tmp = path.join(os.tmpdir(), "buyer-inline-" + i + ".js");
  fs.writeFileSync(tmp, source, "utf8");
  const check = spawnSync(process.execPath, ["--check", tmp], { encoding: "utf8" });
  assert.equal(check.status, 0, "Buyer inline script syntax error #" + i + ":\n" + check.stderr);
}

// Source wiring and UI state guards.
assert.match(buyer, /recordQuickMarketSupplierReturn:async function\(invoiceId\)/);
assert.match(buyer, /App\.recordQuickMarketSupplierReturn/);
assert.match(buyer, /var canRegisterHandover=quickMarketStatusEligible&&invoiceOwner&&hasHandoverPending/);
assert.match(buyer, /var canReturnSupplier=quickMarketStatusEligible&&invoiceOwner&&hasReturnableCustody/);
assert.match(buyer, /pending=Array\.isArray\(result\.pending_handover\)\?result\.pending_handover:\[\]/);
assert.doesNotMatch(buyer.slice(buyer.indexOf("openInvoice:async function(id){"), buyer.indexOf("viewPurchaseAttachment:async function(path){")), /showDenyButton:isQuickMarket/);

// Extract and execute the actual Buyer method with an isolated modal / storage / Edge-function mock.
const methodStart = buyer.indexOf("recordQuickMarketSupplierReturn:async function(invoiceId){");
const methodEnd = buyer.indexOf("renderQuickSearch:function(items,q)", methodStart);
assert.ok(methodStart >= 0 && methodEnd > methodStart, "Supplier-return method boundaries not found");
let methodMember = buyer.slice(methodStart, methodEnd).trim().replace(/,\s*$/, "");
let lastValidation = "";
let modalHtml = "";
let controls = {};
let queryRows = [];
let uploadedPath = "";
let registerCalls = [];
let apiCalls = [];
let mockApi;
const context = {
  buyerEsc: value => String(value == null ? "" : value),
  buyerOperationId: () => "operation-quick-return-001",
  document: { querySelectorAll: () => queryRows },
  Swal: {
    fire: async options => {
      modalHtml = options.html || "";
      if (typeof options.preConfirm !== "function") return { isConfirmed: false };
      const value = await options.preConfirm();
      return { isConfirmed: value !== false, value };
    },
    showValidationMessage: message => { lastValidation = String(message); }
  },
  RW_UI: {
    byId: id => controls[id] || null,
    toast: () => {}
  },
  supabase: {
    storage: {
      from: bucket => ({
        upload: async (filePath, file, options) => { uploadedPath = filePath; return { data: { path: filePath }, error: null }; }
      })
    }
  },
  Number,
  Array,
  Date,
  Promise,
  console
};
const methodObject = vm.runInNewContext("({" + methodMember + "})", context);
const returnMethod = methodObject.recordQuickMarketSupplierReturn;
assert.equal(typeof returnMethod, "function");

function baseProgress() {
  return {
    success: true, invoice_id: "invoice-quick-001", status: "Draft", purchaser_user_id: "buyer-001",
    lines: [{
      invoice_detail_id: "line-001", item_code: "ITEM-1", item_name: "Test item",
      invoice_qty: 10, handed_over_qty: 10, warehouse_accepted_qty: 2,
      supplier_returned_qty: 3, current_custody_qty: 5, remaining_qty: 0, unit: "قطعة"
    }],
    events: [], return_events: []
  };
}
async function scenario({qty=2, progress=baseProgress(), registerError=null, verifyMatch=false, fileType="application/pdf"}={}) {
  lastValidation = ""; modalHtml = ""; registerCalls = []; apiCalls = []; queryRows = []; uploadedPath = "";
  let invalidated = 0, opened = 0, errors = [];
  const input = { getAttribute: name => name === "data-bsr-line" ? "line-001" : null, value: String(qty) };
  queryRows = [input];
  controls = {
    "bsr-reason": { value: "تالف ووافق المورد على استلامه" },
    "bsr-file": { files: [{ name: "supplier-return.pdf", size: 2048, type: fileType }] }
  };
  const api = async (operation, payload) => {
    apiCalls.push({operation,payload});
    if (operation === "GET_QUICK_MARKET_HANDOVER_PROGRESS") {
      if (apiCalls.filter(x => x.operation === operation).length === 1) return progress;
      if (verifyMatch) {
        const ret = payload || {};
        return { ...baseProgress(), return_events: [{
          operation_id: "operation-quick-return-001",
          evidence_path: uploadedPath
        }] };
      }
      return { ...baseProgress(), return_events: [] };
    }
    if (operation === "REGISTER_QUICK_MARKET_SUPPLIER_RETURN") {
      registerCalls.push(payload);
      if (registerError) throw new Error(registerError);
      return { success: true, duplicate: false };
    }
    throw new Error("Unexpected API operation: " + operation);
  };
  const app = {
    currentUser: { id:"buyer-001", company_id:"company-001" },
    api, invalidate: () => { invalidated++; },
    openInvoice: async () => { opened++; },
    notifyError: e => { errors.push(String(e && e.message || e)); }
  };
  await returnMethod.call(app, "invoice-quick-001");
  return {app,invalidated,opened,errors,apiCalls,registerCalls,lastValidation,modalHtml};
}

// Happy path: a partial accepted return records only the user-entered line quantity.
const happy = await scenario({qty:2});
assert.equal(happy.registerCalls.length, 1, "Partial return must call the atomic operation once");
assert.equal(happy.registerCalls[0].items[0].invoice_detail_id, "line-001");
assert.equal(happy.registerCalls[0].items[0].qty, 2);
assert.match(happy.registerCalls[0].evidence_path, /supplier-return-/);
assert.equal(happy.registerCalls[0].operation_id, "operation-quick-return-001");
assert.equal(happy.invalidated, 1);
assert.equal(happy.opened, 1);
assert.match(happy.modalHtml, /متاح/);

// Over-return must be rejected before the atomic operation is called.
const over = await scenario({qty:6});
assert.equal(over.registerCalls.length, 0);
assert.match(over.lastValidation, /تتجاوز صافي الحيازة/);
assert.equal(over.invalidated, 0);

// Wrong/missing custody means no supplier-return dialog or operation.
const empty = await scenario({progress:{...baseProgress(),lines:[]}});
assert.equal(empty.registerCalls.length, 0);
assert.match(empty.errors.join(" "), /لا توجد بضاعة مثبتة/);

// Unsupported evidence MIME must be rejected before any business RPC.
const badFile = await scenario({qty:1,fileType:"text/plain"});
assert.equal(badFile.registerCalls.length, 0);
assert.match(badFile.lastValidation, /أرفق PDF أو صورة/);

// Retry after uncertain transport is accepted only when the server confirms the same operation/evidence.
const retry = await scenario({qty:1,registerError:"network timeout",verifyMatch:true});
assert.equal(retry.registerCalls.length, 1);
assert.equal(retry.invalidated, 1);
assert.equal(retry.opened, 1);

// Edge authorization and RPC wiring.
assert.match(edge, /op === "REGISTER_QUICK_MARKET_SUPPLIER_RETURN"\)\s*\{\s*requireAny\(\["purchases"\]\)/);
assert.match(edge, /buyer_goods_custody_register_quick_market_supplier_return_atomic/);
assert.match(edge, /event\.operation_id === operationId && event\.evidence_path === evidencePath/);

// SQL contract guards. These are static contract tests, not a live Postgres execution.
assert.match(sql, /BEGIN;[\s\S]*COMMIT;/);
assert.match(sql, /CREATE OR REPLACE FUNCTION public\.buyer_goods_custody_register_quick_market_supplier_return_atomic/);
assert.match(sql, /'BUYER_TO_SUPPLIER_ACCEPTED',-v_qty,'PurchaseInvoice'/);
assert.match(sql, /'pending_handover',v_pending/);
assert.match(sql, /COALESCE\(parent\.event_type,e\.event_type\) IN \('SUPPLIER_TO_BUYER_QUICK_MARKET','BUYER_TO_WAREHOUSE_ACCEPTED','BUYER_TO_SUPPLIER_ACCEPTED'\)/);
assert.match(sql, /REVOKE ALL ON FUNCTION public\.buyer_goods_custody_register_quick_market_supplier_return_atomic/);
assert.doesNotMatch(sql.slice(sql.indexOf("CREATE OR REPLACE FUNCTION public.buyer_goods_custody_register_quick_market_supplier_return_atomic"), sql.indexOf("DROP POLICY IF EXISTS buyer_goods_docs_insert_owner")), /INSERT INTO public\.(stock|purchase_payments|journal_entries|treasury)/i);

console.log("BUYER_QUICK_MARKET_SUPPLIER_RETURN_CONTRACT_TESTS=PASS");
console.log("buyerInlineScripts=" + inlineScripts.length);
console.log("businessScenarios=5");
console.log("sqlValidation=STATIC_ONLY");
