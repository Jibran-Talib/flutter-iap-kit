import 'backend/iap_backend.dart';
import 'iap_error_message.dart';
import 'model/iap_plan.dart';
import 'model/iap_purchase_update.dart';
import 'model/iap_status.dart';
import 'model/iap_verify_result.dart';
import 'store/iap_store_service.dart';
import 'store/store_plan_mapper.dart';

/// Orchestrates the store and the backend so the provider never touches
/// either directly.
class IapRepository {
  final IapStoreService _store;
  final IapBackend _backend;

  IapRepository({required IapBackend backend, IapStoreService? store})
      : _backend = backend,
        _store = store ?? IapStoreService();

  /// Backend plans first, then the store for the platform product ids, then
  /// the store price is laid over the backend plan.
  Future<IapCatalog> getCatalog() async {
    final available = await _store.isStoreAvailable();
    if (!available) {
      return IapCatalog.failure('The store is not available on this device.');
    }

    final backend = await _backend.getCatalog();
    if (!backend.success) return backend;

    final productIds =
        backend.plans.map((p) => p.storeProductId).whereType<String>().toSet();
    if (productIds.isEmpty) return backend;

    try {
      final storeProducts = await _store.getProducts(productIds);
      final mapped = StorePlanMapper.mapWithStoreProducts(
        backendPlans: backend.plans,
        storeProducts: storeProducts,
      );
      // A one-time plan the store does not sell yet (missing or inactive in the
      // console) would only show a dead button: hide it. Subscriptions stay so
      // the screen still explains what is on offer.
      return backend.copyWith(
        plans:
            mapped.where((p) => !p.isOneTime || p.storePrice != null).toList(),
      );
    } catch (e) {
      return IapCatalog.failure(iapErrorMessage(e));
    }
  }

  /// Returns an error message, or null when the store accepted the request.
  /// The purchase itself is reported later on [watchPurchaseUpdates].
  Future<String?> buy({
    required String productId,
    required String accountToken,
  }) async {
    try {
      final started = await _store.buy(
        productId: productId,
        accountToken: accountToken,
      );
      return started ? null : 'Could not start the purchase.';
    } catch (e) {
      return iapErrorMessage(e);
    }
  }

  Future<String?> restoreFromStore() async {
    try {
      await _store.restorePurchases();
      return null;
    } catch (e) {
      return iapErrorMessage(e);
    }
  }

  Stream<List<IapPurchaseUpdate>> watchPurchaseUpdates() =>
      _store.watchPurchaseUpdates();

  Future<IapVerifyResult> verify(IapVerifyParams params) =>
      _backend.verify(params);

  Future<IapRestoreResult> restore(List<IapVerifyParams> purchases) =>
      _backend.restore(purchases);

  Future<IapStatusResult> getStatus() => _backend.getStatus();

  Future<void> completePurchase(IapPurchaseUpdate purchase) =>
      _store.completePurchase(purchase);
}
