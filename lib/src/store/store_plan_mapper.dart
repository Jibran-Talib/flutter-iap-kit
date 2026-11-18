import 'package:in_app_purchase/in_app_purchase.dart';

import '../model/iap_plan.dart';

/// Overlays what the store will really charge onto the backend plans. The
/// backend stays the source of truth for names and features; the store is the
/// source of truth for the price.
class StorePlanMapper {
  StorePlanMapper._();

  static List<IapPlan> mapWithStoreProducts({
    required List<IapPlan> backendPlans,
    required List<ProductDetails> storeProducts,
  }) {
    final byId = {for (final p in storeProducts) p.id: p};

    return backendPlans.map((plan) {
      final product = byId[plan.storeProductId];
      if (product == null) return plan;

      return plan.withStorePrice(
        storePrice: product.price,
        rawPrice: product.rawPrice,
        currency: product.currencyCode,
      );
    }).toList();
  }
}
