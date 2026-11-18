# Store setup

One product per plan **and** per billing cycle, the **same product id on both stores**. Do not share one id between monthly and yearly.

## Google Play Console
Monetize with Play, Products, Subscriptions, Create subscription: Product ID, Name, then one base plan (ID, billing period, auto-renewing, price, Convert regions), **Activate**. One-time products: Products, One-time products. Testers: Setup, License testing. Test with a release-signed build from the Internal testing track.

## App Store Connect
Monetization, Subscriptions. One subscription group for plans a user must not hold together (order the levels for upgrade/downgrade). Per product: Reference Name, Product ID, Duration, Price (Apple has fixed price points), Display Name (<= 30), Description (<= 45), review screenshot, review notes. Attach products to the app version. Testers: Users and Access, Sandbox.

## Naming
`<plan>_<cycle>`, e.g. `individual_basic_monthly`, `coach_pro_yearly`, `fai_programme_once`. Keep ids identical on both stores and in the backend.
