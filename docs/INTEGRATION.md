# Integration checklist

## App
- [ ] `in_app_purchase` ^3.3.1 only (no other IAP plugin)
- [ ] `IapBackend` implemented; never throws
- [ ] `IapProvider` created eagerly (`lazy: false`) at app start
- [ ] `loadPlans()` on paywall open; `refreshStatus()` on start, sign in, **resume**
- [ ] `clear()` on logout
- [ ] Global loader follows `provider.isWorking`; **no** loader during `awaitingStoreConfirmation`
- [ ] Buttons: Subscribe disabled while `isWorking`, with the reason shown; hidden when already active
- [ ] Price shown is `plan.storePrice`, never `plan.price`
- [ ] Restore button on the paywall and in settings
- [ ] Auto-renew disclosure: price, period, "renews until cancelled", how to cancel
- [ ] Terms of Use and Privacy Policy links on the paywall
- [ ] "Manage subscription" opens `IapManageLink.forSource(status.source, productId: ...)`
- [ ] Premium gates read the backend status (`onStatusChanged`), never the purchase callback

## Android
- [ ] Billing permission comes with the plugin (no manual permission)
- [ ] Release-signed build installed from the Internal testing track to test
- [ ] `finishesTransactions` true unless the backend acknowledges

## iOS
- [ ] In-App Purchase capability enabled in Xcode
- [ ] Paid Apps agreement and banking active in App Store Connect
- [ ] Subscription group has localisation and a review screenshot
- [ ] Sandbox tester created

## Before shipping
Run through `TEST_CASES.md` and the audit list in the `iap-complete` skill.
