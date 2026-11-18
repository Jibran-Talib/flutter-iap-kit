import 'package:in_app_purchase/in_app_purchase.dart';

import '../iap_log.dart';
import '../model/iap_enums.dart';
import '../model/iap_purchase_update.dart';
import 'store_plan_mapper.dart';

/// The only file that talks to `package:in_app_purchase`.
class IapStoreService {
  final InAppPurchase? _injected;

  /// All store entries per product id (Google lists one per base plan).
  final Map<String, List<ProductDetails>> _productCache = {};
  final Map<String, IapPurchaseUpdate> _purchaseCache = {};

  IapStoreService({InAppPurchase? inAppPurchase}) : _injected = inAppPurchase;

  /// Resolved lazily so constructing the service never touches the platform
  /// channel (unit tests and unsupported platforms stay safe).
  InAppPurchase get _inAppPurchase => _injected ?? InAppPurchase.instance;

  Future<bool> isStoreAvailable() => _inAppPurchase.isAvailable();

  Future<List<ProductDetails>> getProducts(Set<String> productIds) async {
    iapLog('STORE ← asking for products $productIds');
    final response = await _inAppPurchase.queryProductDetails(productIds);
    iapLog(
      'STORE → found ${response.productDetails.length}, '
      'not found ${response.notFoundIDs}, error ${response.error?.message}',
    );

    if (response.error != null) {
      throw response.error!.message;
    }
    if (response.productDetails.isEmpty) {
      throw 'No products found in the store.';
    }

    final products = [...response.productDetails]
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    _productCache
      ..clear()
      ..addAll(StorePlanMapper.groupById(products));

    return products;
  }

  /// Subscriptions and one-time products are both bought through
  /// `buyNonConsumable` (the plugin has no separate subscription call).
  /// [accountToken] is Apple's appAccountToken / Google's obfuscatedAccountId.
  ///
  /// [cycle] picks the right base plan when the store lists several entries
  /// under one product id (see [StorePlanMapper.pick]).
  Future<bool> buy({
    required String productId,
    required String accountToken,
    IapBillingCycle? cycle,
  }) {
    final product = StorePlanMapper.pick(
      _productCache[productId] ?? const [],
      cycle,
    );
    if (product == null) {
      throw 'This plan is not available in the store right now.';
    }

    iapLog(
      'STORE ← launching purchase flow product=$productId cycle=${cycle?.name} '
      '(account token sent: ${accountToken.isNotEmpty})',
    );
    return _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: accountToken,
      ),
    );
  }

  Future<void> restorePurchases() {
    iapLog('STORE ← restorePurchases()');
    return _inAppPurchase.restorePurchases();
  }

  Stream<List<IapPurchaseUpdate>> watchPurchaseUpdates() {
    return _inAppPurchase.purchaseStream.map((updates) {
      final mapped =
          updates.map(IapPurchaseUpdate.fromPurchaseDetails).toList();

      for (final purchase in mapped) {
        iapLog('STORE → purchaseStream update ${purchase.describe()}');
        _purchaseCache[_cacheKey(purchase)] = purchase;
      }

      return mapped;
    });
  }

  /// Finishes the transaction: acknowledges on Android, finishes on iOS.
  Future<void> completePurchase(IapPurchaseUpdate purchase) {
    iapLog('STORE ← completePurchase/acknowledge ${purchase.productId}');
    final cached = _purchaseCache[_cacheKey(purchase)] ?? purchase;
    final details = cached.purchaseDetails;
    if (details == null) return Future.value();
    return _inAppPurchase.completePurchase(details).then((_) {
      iapLog('STORE → completePurchase done ${purchase.productId}');
    });
  }

  String _cacheKey(IapPurchaseUpdate purchase) =>
      '${purchase.productId}:${purchase.purchaseToken}';
}
