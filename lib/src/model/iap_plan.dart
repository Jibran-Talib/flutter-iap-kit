import 'dart:io';

import 'iap_enums.dart';
import 'iap_status.dart';

/// A purchasable plan from your backend, with the store's real price overlaid
/// once the store has answered. The app builds these in its [IapBackend].
class IapPlan {
  /// Backend id of the plan (any string).
  final String id;
  final String name;
  final String? description;

  /// Backend price, for reference only. The UI shows [storePrice].
  final num? price;
  final String? currency;
  final IapBillingCycle cycle;
  final List<String> features;
  final bool isPopular;

  /// Backend-declared saving in whole percent (fallback for the yearly badge).
  final int? discount;
  final String? appleProductId;
  final String? googleProductId;

  /// Formatted price straight from the store (e.g. "£9.99").
  final String? storePrice;

  /// Store price as a number, for the saving shown on a yearly card.
  final double? storeRawPrice;

  /// Anything app-specific the backend sends (access days, role, limits...).
  final Map<String, dynamic> extra;

  const IapPlan({
    required this.id,
    required this.name,
    required this.cycle,
    this.description,
    this.price,
    this.currency,
    this.features = const [],
    this.isPopular = false,
    this.discount,
    this.appleProductId,
    this.googleProductId,
    this.storePrice,
    this.storeRawPrice,
    this.extra = const {},
  });

  /// Store product id for the platform the app is running on.
  String? get storeProductId =>
      Platform.isAndroid ? googleProductId : appleProductId;

  bool get isYearly => cycle == IapBillingCycle.yearly;
  bool get isMonthly => cycle == IapBillingCycle.monthly;
  bool get isOneTime => cycle == IapBillingCycle.oneTime;

  IapPlan withStorePrice({
    required String storePrice,
    double? rawPrice,
    String? currency,
  }) {
    return IapPlan(
      id: id,
      name: name,
      cycle: cycle,
      description: description,
      price: price,
      currency: currency ?? this.currency,
      features: features,
      isPopular: isPopular,
      discount: discount,
      appleProductId: appleProductId,
      googleProductId: googleProductId,
      storePrice: storePrice,
      storeRawPrice: rawPrice,
      extra: extra,
    );
  }

  /// How much cheaper this yearly plan is than twelve months of [monthly], in
  /// whole percent. Uses the store prices when both are known, otherwise the
  /// backend `discount`. Null when there is no saving to show.
  int? savingsComparedTo(IapPlan? monthly) {
    if (!isYearly) return null;

    final yearlyPrice = storeRawPrice ?? price?.toDouble();
    final monthlyPrice = monthly?.storeRawPrice ?? monthly?.price?.toDouble();
    if (yearlyPrice != null && monthlyPrice != null && monthlyPrice > 0) {
      final percent = ((1 - yearlyPrice / (monthlyPrice * 12)) * 100).round();
      if (percent > 0) return percent;
    }

    final fallback = discount;
    return (fallback != null && fallback > 0) ? fallback : null;
  }

  /// "/month", "/year" or "" for one-time plans.
  String get cycleLabel {
    switch (cycle) {
      case IapBillingCycle.monthly:
        return '/month';
      case IapBillingCycle.yearly:
        return '/year';
      case IapBillingCycle.oneTime:
        return '';
    }
  }
}

/// What the backend returns for the plan list.
class IapCatalog {
  final bool success;
  final String? message;
  final List<IapPlan> plans;

  /// What the user already owns, when the backend sends it with the plans.
  final IapStatus? status;

  const IapCatalog({
    required this.success,
    this.message,
    this.plans = const [],
    this.status,
  });

  factory IapCatalog.failure(String message) =>
      IapCatalog(success: false, message: message);

  IapCatalog copyWith({List<IapPlan>? plans}) => IapCatalog(
        success: success,
        message: message,
        plans: plans ?? this.plans,
        status: status,
      );
}
