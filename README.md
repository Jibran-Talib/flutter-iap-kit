# flutter_iap_kit

A small, reusable, **backend-verified** in-app purchase kit for Flutter. Subscriptions (monthly / yearly) and one-time products, on top of [`in_app_purchase`](https://pub.dev/packages/in_app_purchase).

It was extracted from a production app and generalised: the store handling, the purchase state machine and the recovery rules are in the kit; the only thing each app writes is an `IapBackend` (4 methods) and the paywall UI.

## What it gives you

- Store access in **one** file (`IapStoreService`), everything else is plain Dart and testable.
- A provider (`IapProvider`, `ChangeNotifier`) with a clear state machine: `idle → processing → awaitingStoreConfirmation → verifying → success / failure / canceled`, plus `restoring`.
- **The backend decides.** The app never unlocks anything because the store said "purchased"; it unlocks after the backend verified and the status was re-read.
- Never charges twice: a quiet restore runs before every purchase, `itemAlreadyOwned` recovers through restore.
- Idempotent: the same purchase token arriving from the purchase stream, restore and relaunch is verified once.
- A failed verification **leaves the transaction unfinished** so the store hands it back (Restore / next launch). Money taken but not activated shows a recoverable message, never a "purchase failed".
- Quiet renewals: a renewal while the plan is active is verified without loader or toast.
- Account binding: sends Apple `appAccountToken` / Google `obfuscatedAccountId` with every purchase.
- Store price is shown, backend price is reference only. Yearly saving badge computed from store prices.
- Logs never contain a token (`iapMask`).
- 20 unit tests with fake store and fake backend.

## Layout

```
lib/
  flutter_iap_kit.dart            barrel
  src/
    backend/iap_backend.dart      the interface an app implements
    store/iap_store_service.dart  the only file that imports in_app_purchase
    store/store_plan_mapper.dart  overlays store price on backend plans
    iap_repository.dart           store + backend orchestration
    iap_provider.dart             state machine (ChangeNotifier)
    model/                        plan, status, verify / restore results, purchase update
    manage_link.dart              "manage subscription" URL per store
    iap_error_message.dart        short readable store errors
    iap_log.dart                  safe billing log
docs/
  INTEGRATION.md  BACKEND_CONTRACT.md  STORE_SETUP.md  TEST_CASES.md
test/             fakes + provider and model tests
```

## Install

Git dependency:

```yaml
dependencies:
  flutter_iap_kit:
    git:
      url: https://github.com/Jibran-Talib/flutter-iap-kit.git
      ref: main
```

or copy `lib/src` into your feature folder (the kit has no other dependency than `in_app_purchase`).

## Use it in 4 steps

1. **Implement `IapBackend`** with your own HTTP client (see `docs/BACKEND_CONTRACT.md`). Map your JSON to `IapCatalog`, `IapStatus`, `IapVerifyResult`, `IapRestoreResult`. Never throw: return a failure result with the server's message.

```dart
class MyIapBackend implements IapBackend {
  @override
  Future<IapCatalog> getCatalog() async { /* GET plans -> IapPlan list */ }
  @override
  Future<IapStatusResult> getStatus() async { /* GET status */ }
  @override
  Future<IapVerifyResult> verify(IapVerifyParams p) async { /* POST verify */ }
  @override
  Future<IapRestoreResult> restore(List<IapVerifyParams> purchases) async { /* POST restore */ }
}
```

2. **Create the provider eagerly** (so launch-time re-deliveries are never missed):

```dart
ChangeNotifierProvider(
  lazy: false,
  create: (_) => IapProvider(
    repository: IapRepository(backend: MyIapBackend()),
    readAuthToken: TokenStorage.getToken,
    onStatusChanged: (status) => premiumGate.update(status.isPremium),
  ),
);
```

3. **Build the paywall** from `provider.plans` / `subscriptionPlans` / `oneTimePlans`; call `provider.buyPlan(plan)`, `provider.restorePurchases()`. React to `purchaseStatus` and `message`. Show the global loader while `provider.isWorking`.

4. **Lifecycle hooks:** call `provider.loadPlans()` when the paywall opens, `provider.refreshStatus()` on app start, sign in and **app resume**, `provider.clear()` on logout.

## Rules the kit enforces (do not bypass)

1. The backend is the only authority for entitlement; the client caches.
2. Entitlement = state AND `expiresAt > now` (server clock), never a status string alone.
3. Identify plans by backend id / product id, never by display name.
4. Finish (acknowledge) a transaction only after the backend accepted it. On Android an unacknowledged purchase is refunded after 3 days: the app acknowledges by default (`finishesTransactions`), set it to `false` on Android only if your backend acknowledges through the Play Developer API.
5. Re-read the status after every purchase, restore and resume.
6. Never disable a button without saying why.
7. Never log tokens, receipts or personal data.

Paywall policy items you still own: Restore button, price + period + auto-renew text, Terms and Privacy links, "Manage subscription" link (`IapManageLink`). See `docs/INTEGRATION.md`.

## Tests

```bash
flutter test
```

## License

MIT
