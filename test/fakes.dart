import 'dart:async';

import 'package:flutter_iap_kit/flutter_iap_kit.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Scriptable backend: set the fields, count the calls.
class FakeBackend implements IapBackend {
  IapCatalog catalog = const IapCatalog(success: true);
  IapStatus status = const IapStatus(accountToken: 'acct-1');
  IapVerifyResult? verifyResult;
  IapRestoreResult? restoreResult;
  bool statusFails = false;

  int verifyCalls = 0;
  int restoreCalls = 0;
  List<IapVerifyParams> lastRestored = const [];

  @override
  Future<IapCatalog> getCatalog() async => catalog;

  @override
  Future<IapStatusResult> getStatus() async => statusFails
      ? IapStatusResult.failure('offline')
      : IapStatusResult(success: true, status: status);

  @override
  Future<IapVerifyResult> verify(IapVerifyParams params) async {
    verifyCalls++;
    return verifyResult ?? IapVerifyResult(success: true, status: status);
  }

  @override
  Future<IapRestoreResult> restore(List<IapVerifyParams> purchases) async {
    restoreCalls++;
    lastRestored = purchases;
    return restoreResult ??
        IapRestoreResult(success: true, restored: 0, status: status);
  }
}

/// Store without the platform channel. Emit updates with [emit].
class FakeStore extends IapStoreService {
  final StreamController<List<IapPurchaseUpdate>> _controller =
      StreamController<List<IapPurchaseUpdate>>.broadcast();

  List<IapPurchaseUpdate> restoreEmits = const [];
  String? buyError;
  final List<String> bought = [];
  final List<String> completed = [];

  void emit(List<IapPurchaseUpdate> updates) => _controller.add(updates);

  @override
  Future<bool> isStoreAvailable() async => true;

  @override
  Future<List<ProductDetails>> getProducts(Set<String> productIds) async => [
        for (final id in productIds)
          ProductDetails(
            id: id,
            title: id,
            description: id,
            price: '\$9.99',
            rawPrice: 9.99,
            currencyCode: 'USD',
          ),
      ];

  @override
  Future<bool> buy({required String productId, required String accountToken}) {
    if (buyError != null) throw buyError!;
    bought.add(productId);
    return Future.value(true);
  }

  @override
  Future<void> restorePurchases() async {
    if (restoreEmits.isNotEmpty) emit(restoreEmits);
  }

  @override
  Stream<List<IapPurchaseUpdate>> watchPurchaseUpdates() => _controller.stream;

  @override
  Future<void> completePurchase(IapPurchaseUpdate purchase) async {
    completed.add(purchase.productId);
  }
}

IapPlan monthlyPlan() => const IapPlan(
      id: 'p1',
      name: 'Monthly',
      cycle: IapBillingCycle.monthly,
      appleProductId: 'plan_monthly',
      googleProductId: 'plan_monthly',
    );

IapPlan oneTimePlan() => const IapPlan(
      id: 'o1',
      name: 'Programme',
      cycle: IapBillingCycle.oneTime,
      appleProductId: 'programme_once',
      googleProductId: 'programme_once',
    );

IapPurchaseUpdate update(
  String productId, {
  IapPurchaseStatus status = IapPurchaseStatus.purchased,
  String token = 'tok-1',
  String? errorMessage,
}) =>
    IapPurchaseUpdate(
      productId: productId,
      status: status,
      pendingCompletePurchase: true,
      purchaseToken: token,
      errorMessage: errorMessage,
    );
