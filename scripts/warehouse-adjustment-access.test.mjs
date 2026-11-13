import test from "node:test";
import assert from "node:assert/strict";
import { canAdjustStock, canAccessAdjustmentBranch } from "../supabase/functions/bulk-stock-adjustment/warehouse-adjustment-access.mjs";

const branchA = { id: "branch-a", branch_code: "BR-A", is_active: true };
const branchB = { id: "branch-b", branch_code: "BR-B", is_active: true };

test("unified warehouse with effective warehouse permission can use adjustment engine", () => {
  assert.equal(canAdjustStock({ active_warehouse_role: "مخزن شامل", permissions: ["warehouse"] }), true);
});

test("unified warehouse without warehouse permission is denied", () => {
  assert.equal(canAdjustStock({ active_warehouse_role: "مخزن شامل", permissions: [] }), false);
});

test("legacy explicit stock_adjustment permission remains supported", () => {
  assert.equal(canAdjustStock({ active_warehouse_role: "استلام", permissions: ["stock_adjustment"] }), true);
});

test("unified storekeeper with one allowed branch can adjust only that branch", () => {
  const profile = { active_warehouse_role: "مخزن شامل", permissions: ["warehouse"], allowed_branch_ids: ["branch-a"] };
  assert.equal(canAccessAdjustmentBranch(profile, branchA), true);
  assert.equal(canAccessAdjustmentBranch(profile, branchB), false);
});

test("default branch is honored when allowed_branch_ids is empty", () => {
  const profile = { active_warehouse_role: "مخزن شامل", permissions: ["warehouse"], default_branch_id: "branch-a", allowed_branch_ids: [] };
  assert.equal(canAccessAdjustmentBranch(profile, branchA), true);
  assert.equal(canAccessAdjustmentBranch(profile, branchB), false);
});

test("branch code and explicit wildcard scopes are supported", () => {
  assert.equal(canAccessAdjustmentBranch({ active_warehouse_role: "مخزن شامل", permissions: ["warehouse"], allowed_branch_ids: ["BR-A"] }, branchA), true);
  assert.equal(canAccessAdjustmentBranch({ active_warehouse_role: "مخزن شامل", permissions: ["warehouse"], allowed_branch_ids: ["*"] }, branchB), true);
});

test("missing, inactive, or out-of-scope branch is rejected for unified storekeeper", () => {
  const profile = { active_warehouse_role: "مخزن شامل", permissions: ["warehouse"], allowed_branch_ids: [] };
  assert.equal(canAccessAdjustmentBranch(profile, branchA), false);
  assert.equal(canAccessAdjustmentBranch(profile, { ...branchA, is_active: false }), false);
  assert.equal(canAccessAdjustmentBranch(profile, null), false);
});

test("verified owner bypasses branch scope", () => {
  const owner = { isOwner: true, active_warehouse_role: "مخزن شامل", permissions: ["*"] };
  assert.equal(canAdjustStock(owner), true);
  assert.equal(canAccessAdjustmentBranch(owner, branchB), true);
});

test("non-unified explicit stock adjustment capability keeps existing company-wide behavior", () => {
  const profile = { active_warehouse_role: "مدير مخازن", permissions: ["stock_adjustment"], allowed_branch_ids: ["branch-a"] };
  assert.equal(canAccessAdjustmentBranch(profile, branchB), true);
});
