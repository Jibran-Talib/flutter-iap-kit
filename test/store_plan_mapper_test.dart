import 'package:flutter_iap_kit/flutter_iap_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

ProductDetails product(String id, double price) => ProductDetails(
      id: id,
      title: id,
      description: id,
      price: '\$$price',
      rawPrice: price,
      currencyCode: 'USD',
    );

IapPlan plan(String id, IapBillingCycle cycle, String productId) => IapPlan(
      id: id,
      name: id,
      cycle: cycle,
      appleProductId: productId,
      googleProductId: productId,
    );

void main() {
  // Google Play: one subscription id, two base plans (monthly + yearly).
  final shared = [
    product('individual_basic', 29.99),
    product('individual_basic', 2.99)
  ];

  test(
      'one id with two base plans: monthly gets the cheaper, yearly the dearer',
      () {
    final plans = StorePlanMapper.mapWithStoreProducts(
      backendPlans: [
        plan('6:monthly', IapBillingCycle.monthly, 'individual_basic'),
        plan('6:yearly', IapBillingCycle.yearly, 'individual_basic'),
      ],
      storeProducts: shared,
    );

    expect(plans[0].storePrice, '\$2.99');
    expect(plans[1].storePrice, '\$29.99');
  });

  test('pick returns the only entry whatever the cycle', () {
    final only = [product('coach_basic', 249.99)];
    expect(
        StorePlanMapper.pick(only, IapBillingCycle.yearly)!.rawPrice, 249.99);
    expect(
        StorePlanMapper.pick(only, IapBillingCycle.monthly)!.rawPrice, 249.99);
  });

  test('pick chooses by cycle among several entries', () {
    expect(
        StorePlanMapper.pick(shared, IapBillingCycle.monthly)!.rawPrice, 2.99);
    expect(
        StorePlanMapper.pick(shared, IapBillingCycle.yearly)!.rawPrice, 29.99);
    expect(StorePlanMapper.pick(const [], IapBillingCycle.yearly), isNull);
  });

  test('separate ids per cycle (Apple style) still map one to one', () {
    final plans = StorePlanMapper.mapWithStoreProducts(
      backendPlans: [
        plan('6:monthly', IapBillingCycle.monthly, 'individual_basic_monthly'),
        plan('6:yearly', IapBillingCycle.yearly, 'individual_basic_yearly'),
      ],
      storeProducts: [
        product('individual_basic_monthly', 2.99),
        product('individual_basic_yearly', 29.99),
      ],
    );
    expect(plans.map((p) => p.storePrice), ['\$2.99', '\$29.99']);
  });

  test('a plan the store does not list keeps no store price', () {
    final plans = StorePlanMapper.mapWithStoreProducts(
      backendPlans: [plan('9:monthly', IapBillingCycle.monthly, 'missing')],
      storeProducts: shared,
    );
    expect(plans.single.storePrice, isNull);
  });
}
