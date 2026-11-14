import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { chromium } from 'playwright';

const html = await readFile('companies/company-1/main.html', 'utf8');
assert.ok(html.includes('مسؤول المرتجع') && html.includes('return_handler_id'), 'PARENT_RETURN_ACTOR_COLUMN_MISSING');
assert.ok(html.includes("esc(v.created_by || '—')"), 'PARENT_VOUCHER_CREATOR_COLUMN_MISSING');
assert.ok(html.includes("escIC(x.created_by || '—')"), 'PARENT_COUNT_CREATOR_COLUMN_MISSING');

const moduleStart = html.indexOf('var RW_Warehouse = (function() {');
const moduleMarker = 'window.RW_Warehouse = RW_Warehouse;';
const moduleEnd = html.indexOf(moduleMarker, moduleStart);
assert.ok(moduleStart >= 0 && moduleEnd > moduleStart, 'PARENT_RW_WAREHOUSE_MODULE_NOT_FOUND');
const moduleSource = html.slice(moduleStart, moduleEnd + moduleMarker.length);

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.setContent('<!doctype html><html><body><div id="rw-header-title"></div><div id="rw-page-container"></div></body></html>');

  await page.evaluate(async ({ moduleSource }) => {
    const fixtures = {
      runsheets: [{
        id: 'QA-RUNSHEET-READY',
        runsheet_code: 'QA-UNLOAD-READY-001',
        run_date: '2026-11-14',
        driver_id: 'QA-DRIVER-001',
        vehicle_id: 'QA-VEHICLE-001',
        status: 'Loaded',
        loading_cycle_id: 'QA-LOAD-CYCLE-001',
        company_id: 'QA-COMPANY-001'
      }, {
        id: 'QA-RUNSHEET-NO-CYCLE',
        runsheet_code: 'QA-UNLOAD-NO-CYCLE',
        run_date: '2026-11-14',
        driver_id: 'QA-DRIVER-INVALID',
        vehicle_id: 'QA-VEHICLE-001',
        status: 'Loaded',
        loading_cycle_id: null,
        company_id: 'QA-COMPANY-001'
      }],
      erp_operation_registry: [{
        id: 'QA-UNLOAD-EVENT-001',
        company_id: 'QA-COMPANY-001',
        operation_type: 'complete_runsheet_unloading',
        operation_key: 'QA-UNLOADING-001',
        request_payload: {
          runsheet_code: 'QA-UNLOAD-DONE-001',
          user_email: 'qa.unloader@rawaea.invalid'
        },
        response_payload: { success: true, unloaded_total: 12 },
        status: 'completed',
        created_at: '2026-11-14T08:00:00.000Z',
        completed_at: '2026-11-14T08:00:03.000Z'
      }, {
        id: 'QA-PICK-EVENT-001',
        company_id: 'QA-COMPANY-001',
        operation_type: 'complete_runsheet_picking',
        request_payload: { runsheet_code: 'QA-PICK-001', user_email: 'qa.picker@rawaea.invalid', items: [{ item_code: 'QA-ITEM-1', picked_qty: 5 }] },
        response_payload: { success: true },
        status: 'completed',
        created_at: '2026-11-14T07:00:00.000Z',
        completed_at: '2026-11-14T07:00:05.000Z'
      }, {
        id: 'QA-LOAD-EVENT-001',
        company_id: 'QA-COMPANY-001',
        operation_type: 'complete_runsheet_loading',
        request_payload: { runsheet_code: 'QA-LOAD-001', user_email: 'qa.loader@rawaea.invalid', items: [{ item_code: 'QA-ITEM-1', loaded_qty: 7 }] },
        response_payload: { success: true, loaded_total: 7 },
        status: 'completed',
        created_at: '2026-11-14T09:10:00.000Z',
        completed_at: '2026-11-14T09:10:05.000Z'
      }],
      users: [],
      orders: [],
      run_sheet_details: []
    };

    let realtimeHandler = null;
    let writes = 0;
    let reads = 0;
    let realtimeFilter = null;

    window.RW_STATE = { app: { companyId: 'QA-COMPANY-001', currentView: 'unloading' } };
    window.byId = id => document.getElementById(id);
    window.safeHTML = (element, value) => { if (element) element.innerHTML = value; };
    window.safeText = (element, value) => { if (element) element.textContent = value; };
    window.showToast = message => { throw new Error('UNEXPECTED_TOAST: ' + message); };
    window.RW_Table = {
      paginate(id, rows, page, pageSize, renderRow) {
        const target = document.getElementById(id);
        if (!target) throw new Error('PAGINATION_TARGET_MISSING: ' + id);
        target.innerHTML = rows.slice((page - 1) * pageSize, page * pageSize).map(renderRow).join('');
      }
    };

    function makeQuery(table) {
      const filters = [];
      const notFilters = [];
      const ordering = [];
      let maxRows = null;
      const query = {
        select() { return this; },
        eq(column, value) { filters.push([column, value]); return this; },
        in(column, values) { filters.push([column, values]); return this; },
        not(column, operator, value) { notFilters.push([column, operator, value]); return this; },
        or() { return this; },
        order(column, options = {}) { ordering.push([column, options.ascending !== false]); return this; },
        limit(value) { maxRows = value; return this; },
        insert() { writes += 1; throw new Error('UNEXPECTED_DATA_WRITE'); },
        update() { writes += 1; throw new Error('UNEXPECTED_DATA_WRITE'); },
        upsert() { writes += 1; throw new Error('UNEXPECTED_DATA_WRITE'); },
        delete() { writes += 1; throw new Error('UNEXPECTED_DATA_WRITE'); },
        then(resolve, reject) {
          reads += 1;
          let rows = (fixtures[table] || []).filter(row =>
            filters.every(([column, value]) =>
              Array.isArray(value)
                ? value.map(String).includes(String(row[column]))
                : String(row[column]) === String(value)
            ) && notFilters.every(([column, operator, value]) =>
              operator === 'is' && value === null ? row[column] != null : String(row[column]) !== String(value)
            )
          );
          for (const [column, ascending] of ordering) {
            rows = rows.slice().sort((a, b) => {
              const av = a[column] == null ? '' : String(a[column]);
              const bv = b[column] == null ? '' : String(b[column]);
              return (av < bv ? -1 : av > bv ? 1 : 0) * (ascending ? 1 : -1);
            });
          }
          if (maxRows != null) rows = rows.slice(0, maxRows);
          return Promise.resolve({ data: rows.map(row => structuredClone(row)), error: null }).then(resolve, reject);
        }
      };
      return query;
    }

    window.supabase = {
      from: table => makeQuery(table),
      rpc: async (name, args) => {
        if (name !== 'get_picking_display_users') throw new Error('UNEXPECTED_RPC: ' + name);
        const allowed = new Set((args?.p_picker_ids || []).map(String));
        const rows = (fixtures.users || []).filter(u => allowed.has(String(u.id)));
        return { data: rows.map(u => ({ id: u.id, name: u.name, email: u.email })), error: null };
      },
      channel() {
        return {
          on(eventName, filter, handler) {
            if (eventName !== 'postgres_changes') throw new Error('UNEXPECTED_REALTIME_EVENT');
            realtimeFilter = filter;
            realtimeHandler = handler;
            return this;
          },
          subscribe() { return this; }
        };
      },
      removeChannel() { return Promise.resolve('ok'); }
    };
    window.__qaFixtures = fixtures;
    window.__qaCounters = () => ({ reads, writes, realtimeFilter });
    window.__emitParentRealtime = payload => {
      if (typeof realtimeHandler !== 'function') throw new Error('PARENT_REALTIME_NOT_SUBSCRIBED');
      realtimeHandler(payload);
    };

    window.eval(moduleSource);
    await window.RW_Warehouse.loadUnloading();
  }, { moduleSource });

  const unloadingQueue = await page.locator('#ul-table').innerText();
  assert.match(unloadingQueue, /QA-UNLOAD-READY-001/, 'CURRENT_UNLOADING_QUEUE_NOT_RENDERED');
  assert.doesNotMatch(unloadingQueue, /QA-UNLOAD-NO-CYCLE/, 'UNLOADING_QUEUE_ACCEPTED_MISSING_LOADING_CYCLE');
  const initialHistory = await page.locator('#ul-completed-table').innerText();
  assert.match(initialHistory, /QA-UNLOAD-DONE-001/, 'COMPLETED_UNLOADING_EVENT_NOT_RENDERED');
  assert.match(initialHistory, /qa\.unloader@rawaea\.invalid/, 'UNLOADING_ACTOR_NOT_RENDERED');
  assert.match(initialHistory, /١٢|12/, 'UNLOADED_QUANTITY_NOT_RENDERED');

  await page.locator('#ul-f-id').fill('QA-UNLOAD-DONE-001');
  assert.doesNotMatch(await page.locator('#ul-table').innerText(), /QA-UNLOAD-READY-001/, 'QUEUE_FILTER_NOT_APPLIED');
  assert.match(await page.locator('#ul-completed-table').innerText(), /QA-UNLOAD-DONE-001/, 'COMPLETED_HISTORY_FILTER_NOT_APPLIED');
  await page.locator('#ul-f-id').fill('');

  await page.evaluate(() => {
    window.__qaFixtures.runsheets = [];
    const event = {
      id: 'QA-UNLOAD-EVENT-002',
      company_id: 'QA-COMPANY-001',
      operation_type: 'complete_runsheet_unloading',
      operation_key: 'QA-UNLOADING-002',
      request_payload: {
        runsheet_code: 'QA-UNLOAD-REALTIME-002',
        user_email: 'qa.second-unloader@rawaea.invalid'
      },
      response_payload: { success: true, unloaded_total: 7 },
      status: 'completed',
      created_at: '2026-11-14T08:10:00.000Z',
      completed_at: '2026-11-14T08:10:02.000Z'
    };
    window.__qaFixtures.erp_operation_registry.push(event);
    window.__emitParentRealtime({ new: event });
  });

  await page.waitForFunction(
    () => document.getElementById('ul-completed-table')?.innerText.includes('QA-UNLOAD-REALTIME-002'),
    null,
    { timeout: 5000 }
  );
  assert.match(await page.locator('#ul-completed-table').innerText(), /qa\.second-unloader@rawaea\.invalid/, 'REALTIME_ACTOR_NOT_RENDERED');

  await page.evaluate(async () => {
    window.__qaFixtures.runsheets = [{
      id: 'QA-RUNSHEET-PICKED',
      runsheet_code: 'QA-PICK-001',
      run_date: '2026-11-14',
      driver_id: 'QA-DRIVER-PICK',
      picker_id: 'QA-USER-PICKER',
      status: 'Delivered',
      company_id: 'QA-COMPANY-001'
    }];
    window.__qaFixtures.users = [{
      id: 'QA-USER-PICKER',
      company_id: 'QA-COMPANY-001',
      name: 'QA Picking Operator',
      email: 'qa.picker@rawaea.invalid'
    }];
    await window.RW_Warehouse.loadPicking();
  });
  const pickingHistory = await page.locator('#pk-completed-table').innerText();
  assert.match(pickingHistory, /QA-PICK-001/, 'PARENT_PICKING_HISTORY_ROW_MISSING');
  assert.match(pickingHistory, /qa\.picker@rawaea\.invalid/, 'PARENT_PICKING_HISTORY_ACTOR_MISSING');
  assert.match(pickingHistory, /٥|5/, 'PARENT_PICKING_HISTORY_TOTAL_MISSING');

  await page.evaluate(async () => {
    window.__qaFixtures.runsheets = [{
      id: 'QA-RUNSHEET-RETURNED',
      runsheet_code: 'QA-RETURN-001',
      run_date: '2026-11-14',
      driver_id: 'QA-DRIVER-002',
      return_handler_id: 'QA-USER-RETURN',
      status: 'Returned',
      company_id: 'QA-COMPANY-001'
    }];
    window.__qaFixtures.users = [{
      id: 'QA-USER-RETURN',
      company_id: 'QA-COMPANY-001',
      name: 'QA Return Operator',
      email: 'qa.return@rawaea.invalid'
    }];
    await window.RW_Warehouse.loadReturn();
  });
  const returnHeader = await page.locator('#rt-table').evaluate(el => el.closest('table')?.querySelector('thead')?.innerText || '');
  assert.match(returnHeader, /مسؤول المرتجع/, 'PARENT_RETURN_HANDLER_HEADER_MISSING');
  const returnRows = await page.locator('#rt-table').innerText();
  assert.match(returnRows, /QA-RETURN-001/, 'PARENT_RETURN_ROW_MISSING');
  assert.match(returnRows, /QA Return Operator/, 'PARENT_RETURN_ACTOR_NOT_RENDERED');

  await page.evaluate(async () => {
    window.__qaFixtures.runsheets = [{
      id: 'QA-RUNSHEET-LOADED',
      runsheet_code: 'QA-LOAD-001',
      run_date: '2026-11-14',
      driver_id: 'QA-DRIVER-003',
      loader_id: 'QA-USER-LOADER',
      loader_start: '2026-11-14T09:00:00.000Z',
      loader_end: '2026-11-14T09:10:00.000Z',
      status: 'Loaded',
      notes: 'QA loading note',
      company_id: 'QA-COMPANY-001'
    }];
    window.__qaFixtures.users = [{
      id: 'QA-USER-LOADER',
      company_id: 'QA-COMPANY-001',
      name: 'QA Loading Operator',
      email: 'qa.loader@rawaea.invalid'
    }];
    await window.RW_Warehouse.loadLoading();
  });
  const loadingRows = await page.locator('#ld-table').innerText();
  assert.match(loadingRows, /QA-LOAD-001/, 'PARENT_LOADING_ROW_MISSING');
  assert.match(loadingRows, /QA Loading Operator/, 'PARENT_LOADING_ACTOR_NOT_RENDERED');
  const loadingHistory = await page.locator('#ld-completed-table').innerText();
  assert.match(loadingHistory, /QA-LOAD-001/, 'PARENT_LOADING_HISTORY_ROW_MISSING');
  assert.match(loadingHistory, /qa\.loader@rawaea\.invalid/, 'PARENT_LOADING_HISTORY_ACTOR_MISSING');
  assert.match(loadingHistory, /٧|7/, 'PARENT_LOADING_HISTORY_TOTAL_MISSING');

  const counters = await page.evaluate(() => window.__qaCounters());
  assert.equal(counters.writes, 0, 'TEST_ATTEMPTED_A_DATA_WRITE');
  assert.ok(counters.reads >= 5, 'EXPECTED_READ_REFRESHES_DID_NOT_RUN');
  assert.equal(counters.realtimeFilter.table, 'erp_operation_registry', 'WRONG_REALTIME_TABLE');
  assert.equal(counters.realtimeFilter.filter, 'company_id=eq.QA-COMPANY-001', 'REALTIME_COMPANY_SCOPE_MISSING');

  console.log('PARENT_UNLOADING_QUEUE_RENDER=PASS');
  console.log('PARENT_UNLOADING_COMPLETED_HISTORY_AND_ACTOR=PASS');
  console.log('PARENT_UNLOADING_FILTER_PARITY=PASS');
  console.log('PARENT_UNLOADING_REALTIME_REFRESH=PASS');
  console.log('PARENT_RETURN_ACTOR_ATTRIBUTION=PASS');
  console.log('PARENT_VOUCHER_AND_COUNT_CREATOR_COLUMNS=PASS');
  console.log('PARENT_UNLOADING_COMPANY_FILTER=PASS');
  console.log('PARENT_NO_DATA_WRITES=PASS');
} finally {
  await browser.close();
}
