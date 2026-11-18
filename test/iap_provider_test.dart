import 'package:flutter_iap_kit/flutter_iap_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late FakeBackend backend;
  late FakeStore store;
  late IapProvider provider;
  var signedIn = true;

  setUp(() {
    signedIn = true;
    backend = FakeBackend()
      ..catalog = IapCatalog(
        success: true,
        plans: [monthlyPlan(), oneTimePlan()],
        status: const IapStatus(accountToken: 'acct-1'),
      );
    store = FakeStore();
    provider = IapProvider(
      repository: IapRepository(backend: backend, store: store),
      readAuthToken: () async => signedIn ? 'auth' : null,
      restoreSettleDelay: Duration.zero,
      finishesTransactions: true,
    );
  });

  tearDown(() => provider.dispose());

  /// The user is already premium when the plans load.
  void premiumCatalog() {
    const premium = IapStatus(accountToken: 'acct-1', isPremium: true);
    backend
      ..status = premium
      ..catalog = IapCatalog(
        success: true,
        plans: [monthlyPlan(), oneTimePlan()],
        status: premium,
      );
  }

  test('loadPlans overlays store prices and splits plan kinds', () async {
    await provider.loadPlans();

    expect(provider.viewStatus, IapViewStatus.success);
    expect(provider.subscriptionPlans.single.storePrice, '\$9.99');
    expect(provider.oneTimePlans.single.id, 'o1');
  });

  test('buy then verified purchase activates and finishes once', () async {
    await provider.loadPlans();
    backend.status = IapStatus(
      accountToken: 'acct-1',
      isPremium: true,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    await provider.buyPlan(provider.subscriptionPlans.single);
    expect(provider.purchaseStatus, IapActionStatus.awaitingStoreConfirmation);
    expect(store.bought, ['plan_monthly']);

    store.emit([update('plan_monthly')]);
    await pump();

    expect(provider.purchaseStatus, IapActionStatus.success);
    expect(provider.isPremium, isTrue);
    expect(store.completed, ['plan_monthly']);
    expect(backend.verifyCalls, 1);
  });

  test('the same token delivered twice is verified once', () async {
    await provider.loadPlans();
    backend.status = const IapStatus(accountToken: 'acct-1', isPremium: true);

    store.emit([update('plan_monthly'), update('plan_monthly')]);
    await pump();
    store.emit([update('plan_monthly')]);
    await pump();

    expect(backend.verifyCalls, 1);
  });

  test('rejected verify leaves the transaction unfinished', () async {
    await provider.loadPlans();
    backend.verifyResult = IapVerifyResult.failure('Linked to another account');

    store.emit([update('plan_monthly')]);
    await pump();

    expect(provider.purchaseStatus, IapActionStatus.failure);
    expect(provider.message, contains('Restore'));
    expect(store.completed, isEmpty);
  });

  test('unreachable backend gives the recoverable message', () async {
    await provider.loadPlans();
    backend.verifyResult =
        IapVerifyResult.failure('timeout', unreachable: true);

    store.emit([update('plan_monthly')]);
    await pump();

    expect(provider.message, contains('not be charged twice'));
    expect(store.completed, isEmpty);
  });

  test('an expired rejection is finished so the store stops resending',
      () async {
    await provider.loadPlans();
    backend.verifyResult = IapVerifyResult.failure('Subscription expired');

    store.emit([update('plan_monthly')]);
    await pump();

    expect(store.completed, ['plan_monthly']);
  });

  test('nobody signed in: verification is deferred, nothing finished',
      () async {
    await provider.loadPlans();
    signedIn = false;

    store.emit([update('plan_monthly')]);
    await pump();

    expect(backend.verifyCalls, 0);
    expect(store.completed, isEmpty);
  });

  test('a renewal while premium is verified quietly', () async {
    premiumCatalog();
    await provider.loadPlans();

    store.emit([update('plan_monthly', token: 'renew-1')]);
    await pump();

    expect(backend.verifyCalls, 1);
    expect(provider.purchaseStatus, IapActionStatus.idle);
    expect(provider.message, isNull);
  });

  test('cannot buy a subscription while premium', () async {
    premiumCatalog();
    await provider.loadPlans();

    await provider.buyPlan(provider.subscriptionPlans.single);

    expect(store.bought, isEmpty);
    expect(provider.message, contains('already'));
  });

  test('user cancelling the sheet is not an error', () async {
    await provider.loadPlans();

    store.emit([update('plan_monthly', status: IapPurchaseStatus.canceled)]);
    await pump();

    expect(provider.purchaseStatus, IapActionStatus.canceled);
    expect(provider.message, isNull);
  });

  test('restore with nothing in the store says so', () async {
    await provider.loadPlans();

    await provider.restorePurchases();

    expect(provider.purchaseStatus, IapActionStatus.idle);
    expect(provider.message, 'No active purchases were found to restore.');
  });

  test('restore sends every store purchase in one backend call', () async {
    await provider.loadPlans();
    store.restoreEmits = [
      update('plan_monthly', status: IapPurchaseStatus.restored, token: 'a'),
      update('programme_once', status: IapPurchaseStatus.restored, token: 'b'),
    ];
    backend.restoreResult = const IapRestoreResult(
      success: true,
      restored: 2,
      items: [
        IapRestoreItem(productId: 'plan_monthly', success: true),
        IapRestoreItem(productId: 'programme_once', success: true),
      ],
      status: IapStatus(accountToken: 'acct-1', isPremium: true),
    );

    await provider.restorePurchases();

    expect(backend.restoreCalls, 1);
    expect(backend.lastRestored.map((p) => p.productId).toSet(), {
      'plan_monthly',
      'programme_once',
    });
    expect(provider.message, 'Purchases restored successfully.');
    expect(store.completed.toSet(), {'plan_monthly', 'programme_once'});
  });

  test('already owned store error recovers through restore', () async {
    await provider.loadPlans();

    store.emit([
      update(
        'plan_monthly',
        status: IapPurchaseStatus.error,
        errorMessage: 'BillingResponse.itemAlreadyOwned',
      ),
    ]);
    await pump();

    expect(backend.restoreCalls, 1);
  });

  test('clear forgets the previous user', () async {
    premiumCatalog();
    await provider.loadPlans();
    expect(provider.isPremium, isTrue);

    provider.clear();

    expect(provider.isPremium, isFalse);
    expect(provider.plans, isEmpty);
    expect(provider.viewStatus, IapViewStatus.initial);
  });
}
