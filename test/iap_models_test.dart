import 'package:flutter_iap_kit/flutter_iap_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const monthly = IapPlan(
    id: 'm',
    name: 'Monthly',
    cycle: IapBillingCycle.monthly,
    price: 10,
    storeRawPrice: 10,
  );

  test('yearly saving is computed from store prices', () {
    const yearly = IapPlan(
      id: 'y',
      name: 'Yearly',
      cycle: IapBillingCycle.yearly,
      storeRawPrice: 60,
    );
    expect(yearly.savingsComparedTo(monthly), 50);
  });

  test('yearly saving falls back to the backend discount', () {
    const yearly = IapPlan(
      id: 'y',
      name: 'Yearly',
      cycle: IapBillingCycle.yearly,
      discount: 20,
    );
    expect(yearly.savingsComparedTo(null), 20);
  });

  test('non yearly plans have no saving', () {
    expect(monthly.savingsComparedTo(monthly), isNull);
  });

  test('manage link: apple, google and others', () {
    const link = IapManageLink(androidPackage: 'com.example.app');
    expect(link.forSource('apple')!.host, 'apps.apple.com');
    expect(
      link.forSource('google', productId: 'p')!.toString(),
      'https://play.google.com/store/account/subscriptions'
      '?package=com.example.app&sku=p',
    );
    expect(link.forSource('web'), isNull);
  });

  test('log mask never leaks a token', () {
    expect(iapMask('secret-token'), 'present(12 chars)');
    expect(iapMask(''), 'none');
  });

  test('store error text maps known Google codes', () {
    expect(
      iapStoreErrorMessage(message: 'BillingResponse.serviceUnavailable'),
      contains('unavailable'),
    );
  });
}
