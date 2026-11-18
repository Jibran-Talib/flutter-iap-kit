# Store setup

One product per plan **and** per billing cycle, the **same product id on both stores**. Do not share one id between monthly and yearly.

## Google Play Console
Monetize with Play, Products, Subscriptions, Create subscription: Product ID, Name, then one base plan (ID, billing period, auto-renewing, price, Convert regions), **Activate**. One-time products: Products, One-time products. Testers: Setup, License testing. Test with a release-signed build from the Internal testing track.

## App Store Connect
Monetization, Subscriptions. One subscription group for plans a user must not hold together (order the levels for upgrade/downgrade). Per product: Reference Name, Product ID, Duration, Price (Apple has fixed price points), Display Name (<= 30), Description (<= 45), review screenshot, review notes. Attach products to the app version. Testers: Users and Access, Sandbox.

## Naming
`<plan>_<cycle>`, e.g. `individual_basic_monthly`, `coach_pro_yearly`, `fai_programme_once`. Keep ids identical on both stores and in the backend.

## One id, two base plans (Google Play)

Google also allows ONE subscription id with several base plans (monthly + yearly under the same id). The kit supports it: the store returns one entry per base plan, `StorePlanMapper.pick` gives monthly the cheaper entry and yearly the dearer one, and `IapVerifyParams.cycle` carries the cycle the user picked to the backend (a purchase alone does not say which base plan it was). Rules for this layout:

- The backend must accept a cycle hint and treat a missing one as unknown (a purchase re-delivered after a restart). Prefer separate ids per cycle when you can; it removes the ambiguity.
- Never let two base plans of one id have the same price.
