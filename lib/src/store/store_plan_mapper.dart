import 'package:in_app_purchase/in_app_purchase.dart';

import '../model/iap_enums.dart';
import '../model/iap_plan.dart';

/// Overlays what the store will really charge onto the backend plans. The
/// backend stays the source of truth for names and features; the store is the
/// source of truth for the price.
class StorePlanMapper {
  StorePlanMapper._();

  /// A store can list several products under ONE product id: Google Play
  /// returns one entry per base plan of a subscription (monthly + yearly under
  /// the same id). [candidates] are those entries; this picks the one that
  /// matches [cycle]. With several entries the cheaper is the monthly one and
  /// the dearer the yearly one (a yearly price always exceeds the monthly).
  static ProductDetails? pick(
    List<ProductDetails> candidates,
    IapBillingCycle? cycle,
  ) {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1 || cycle == null) return candidates.first;

    final byPrice = [...candidates]
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return cycle == IapBillingCycle.yearly ? byPrice.last : byPrice.first;
  }

  static Map<String, List<ProductDetails>> groupById(
    List<ProductDetails> products,
  ) {
    final grouped = <String, List<ProductDetails>>{};
    for (final product in products) {
      grouped.putIfAbsent(product.id, () => []).add(product);
    }
    return grouped;
  }

  static List<IapPlan> mapWithStoreProducts({
    required List<IapPlan> backendPlans,
    required List<ProductDetails> storeProducts,
  }) {
    final grouped = groupById(storeProducts);

    return backendPlans.map((plan) {
      final product =
          pick(grouped[plan.storeProductId] ?? const [], plan.cycle);
      if (product == null) return plan;

      return plan.withStorePrice(
        storePrice: product.price,
        rawPrice: product.rawPrice,
        currency: product.currencyCode,
      );
    }).toList();
  }
}
