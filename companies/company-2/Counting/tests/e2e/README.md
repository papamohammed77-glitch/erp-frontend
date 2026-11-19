# CountFlow browser E2E

This suite is deliberately non-destructive by default. It logs in with existing CountFlow test accounts and verifies the two applications' authenticated workspaces. The scan test increments the draft quantity but never clicks Save, so it does not create a count entry.

## Run

```bash
npm install
npx playwright install chromium
npm run test:e2e
```

Set these environment variables before running:

- `COUNTFLOW_BASE_URL`: deployed static-app origin, without a trailing slash.
- `COUNTFLOW_SUPERVISOR_EMAIL`, `COUNTFLOW_SUPERVISOR_PASSWORD`: active supervisor account.
- `COUNTFLOW_COUNTER_EMAIL`, `COUNTFLOW_COUNTER_PASSWORD`: active counter account.
- Optional scan test: `COUNTFLOW_TEST_LOCATION_CODE` and `COUNTFLOW_TEST_PRODUCT_BARCODE`. The counter must be assigned to that location and the product must belong to its project.

The suite was added but not executed in this session because no permanent CountFlow users/project/session or deployed app origin were provisioned. Do not put production passwords in source control; use environment variables or CI secrets.
