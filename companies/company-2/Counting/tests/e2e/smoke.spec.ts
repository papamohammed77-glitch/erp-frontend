import { test, expect } from "@playwright/test";

const supervisorEmail = process.env.COUNTFLOW_SUPERVISOR_EMAIL || "";
const supervisorPassword = process.env.COUNTFLOW_SUPERVISOR_PASSWORD || "";
const counterEmail = process.env.COUNTFLOW_COUNTER_EMAIL || "";
const counterPassword = process.env.COUNTFLOW_COUNTER_PASSWORD || "";
const baseUrl = process.env.COUNTFLOW_BASE_URL || "";

function requireEnv(...values: string[]) {
  if (values.some(value => !value)) test.skip(true, "CountFlow E2E environment is not configured.");
}

test.describe("CountFlow supervisor", () => {
  test("authenticates and exposes project controls and logout", async ({ page }) => {
    requireEnv(baseUrl, supervisorEmail, supervisorPassword);
    await page.goto("/companies/company-2/Counting/Counter-supervisor.html");
    await page.locator("#email").fill(supervisorEmail);
    await page.locator("#password").fill(supervisorPassword);
    await page.locator("#loginBtn").click();

    await expect(page.locator("#login")).toBeHidden({ timeout: 20000 });
    await expect(page.locator("#logout")).toBeVisible();
    await expect(page.locator("#app")).toBeVisible();
    await expect(page.locator("#tab-live")).toBeVisible();
  });
});

test.describe("CountFlow counter", () => {
  test("authenticates and loads the field-counting workspace", async ({ page }) => {
    requireEnv(baseUrl, counterEmail, counterPassword);
    await page.goto("/companies/company-2/Counting/Counter.html");
    await page.locator("#email").fill(counterEmail);
    await page.locator("#password").fill(counterPassword);
    await page.locator("#loginBtn").click();

    await expect(page.locator("#login")).toBeHidden({ timeout: 20000 });
    await expect(page.locator("#logoutBtn")).toBeVisible();
    await expect(page.locator("#tab-count")).toBeVisible();
    await expect(page.locator("#barcode")).toBeVisible();
    await expect(page.locator("#location")).toBeVisible();
    await expect(page.locator("#quantity")).toBeVisible();
  });

  test("location barcode selection and repeated same-product scan increment quantity without saving", async ({ page }) => {
    const locationCode = process.env.COUNTFLOW_TEST_LOCATION_CODE || "";
    const productBarcode = process.env.COUNTFLOW_TEST_PRODUCT_BARCODE || "";
    requireEnv(baseUrl, counterEmail, counterPassword, locationCode, productBarcode);

    await page.goto("/companies/company-2/Counting/Counter.html");
    await page.locator("#email").fill(counterEmail);
    await page.locator("#password").fill(counterPassword);
    await page.locator("#loginBtn").click();
    await expect(page.locator("#login")).toBeHidden({ timeout: 20000 });

    await page.locator("#barcode").fill(locationCode);
    await page.locator("#barcode").press("Enter");
    await expect(page.locator("#location")).not.toHaveValue("");

    await page.locator("#barcode").fill(productBarcode);
    await page.locator("#barcode").press("Enter");
    await expect(page.locator("#quantity")).toHaveValue("1");
    await page.locator("#barcode").fill(productBarcode);
    await page.locator("#barcode").press("Enter");
    await expect(page.locator("#quantity")).toHaveValue("2");

    // Deliberately do not click Save: this test is read-only against CountFlow data.
  });
});
