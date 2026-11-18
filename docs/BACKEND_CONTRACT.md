# Backend contract

The kit does not care about your URLs or JSON shape: you implement `IapBackend`. What it **requires** your server to do:

| Operation | Purpose | Must |
|---|---|---|
| `getCatalog()` | Plans to show | return product ids for both stores per plan (`appleProductId`, `googleProductId`), the billing cycle (`monthly`/`yearly`/`oneTime`), name, features. May include the user's current status. |
| `getStatus()` | What the user owns now | return `isPremium` (granted **and** not expired, server clock), `accountToken` (stable per user), billing `source` (`apple`/`google`/other), `expiresAt`, `autoRenew`, owned one-time plan ids |
| `verify(productId, token)` | Validate one purchase | call Apple (App Store Server API) / Google (`purchases.subscriptionsv2.get` or `purchases.products.get`), bind it to the user, store the expiry **from the store**, be idempotent per `originalTransactionId` / purchase token, acknowledge on Google (if the app does not) |
| `restore(purchases[])` | Re-verify all store purchases | run `verify` for each, return one result per product plus the new status |

## Server rules

- Bind a purchase to the app user. Give each user an `accountToken` (UUID) and compare it with Apple `appAccountToken` / Google `obfuscatedExternalAccountId`. If a store account already belongs to another app user, reject (or transfer, by policy) with a clear message.
- Idempotency: unique key on Apple `originalTransactionId` / Google purchase token.
- Expiry always comes from the store response, never from the phone's clock.
- Receive store notifications: **App Store Server Notifications V2** and **Google Play RTDN**. Without them renewals, cancels, refunds, grace and hold never reach the backend.
- Entitlement function: `state in (active, grace) AND expiresAt > now`.
- Refund / revoke removes access immediately.
- Failure messages: a rejected purchase returns `success: false` with a short human message. An expired purchase should say "expired" or "no longer active" so the app finishes it and the store stops re-delivering it.

## Verify result semantics

| `IapVerifyResult` | Meaning for the app |
|---|---|
| `success: true` | finish the transaction, apply `status`, re-read status |
| `success: true, pending: true` | payment not settled; show "pending", do not finish |
| `success: false, unreachable: true` | server gave no answer; keep the transaction, show the recoverable message |
| `success: false` | rejected; keep the transaction (Restore retries), except messages containing "expired" / "no longer active" which are finished |
