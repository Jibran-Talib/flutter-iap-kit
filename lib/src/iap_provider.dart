import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'iap_error_message.dart';
import 'iap_log.dart';
import 'iap_repository.dart';
import 'model/iap_enums.dart';
import 'model/iap_plan.dart';
import 'model/iap_purchase_update.dart';
import 'model/iap_status.dart';

/// Billing through the stores.
///
/// Flow: load plans → buy → the store reports on the purchase stream →
/// backend verifies → the transaction is finished → status is refreshed.
/// The backend, never the store callback, decides what the user owns.
class IapProvider extends ChangeNotifier {
  final IapRepository _repository;

  /// Returns the app's auth token, or null when nobody is signed in. A
  /// purchase re-delivered before login stays unfinished and is verified after.
  final Future<String?> Function() _readAuthToken;

  /// How long to wait for the store to list restored purchases after a restore
  /// request before sending what arrived to the backend.
  final Duration _restoreSettleDelay;

  /// Whether the app finishes (acknowledges) transactions itself.
  ///
  /// Default: true on both platforms. On Android an unacknowledged purchase is
  /// refunded by Google after 3 days, so set this to `false` on Android ONLY
  /// when your backend acknowledges through the Play Developer API.
  final bool _finishesTransactions;

  /// Called whenever the backend reports what the user owns, so the rest of
  /// the app (premium gates) always follows it, whichever screen is open.
  final void Function(IapStatus status)? _onStatusChanged;

  /// If the store never answers after the sheet was opened (dismissed without
  /// an event), the screen is released instead of staying blocked. A late
  /// answer is still handled when it arrives.
  final Duration _awaitingTimeout;
  Timer? _awaitingTimer;
  late final StreamSubscription<List<IapPurchaseUpdate>> _subscription;
  bool _isDisposed = false;

  IapViewStatus _viewStatus = IapViewStatus.initial;
  IapActionStatus _purchaseStatus = IapActionStatus.idle;
  List<IapPlan> _plans = [];
  IapStatus? _status;
  String? _accountToken;
  String? _activeProductId;
  String? _lastPurchasedProductId;
  String? _message;

  bool _isRestoring = false;
  final List<IapPurchaseUpdate> _restoreBuffer = [];
  Timer? _restoreTimer;
  Completer<void>? _restoreSettled;

  /// Purchase tokens being verified right now, and tokens the backend already
  /// activated this session: the store re-delivers the same purchase on
  /// several paths (purchase stream, restore, relaunch) and each must be
  /// verified once.
  final Set<String> _inFlightTokens = {};

  /// Cycle the user picked per product id (Google puts monthly and yearly
  /// under one id, so the purchase alone cannot tell them apart).
  final Map<String, IapBillingCycle> _cycleByProduct = {};
  final Set<String> _activatedTokens = {};

  IapProvider({
    required IapRepository repository,
    required Future<String?> Function() readAuthToken,
    Duration restoreSettleDelay = const Duration(milliseconds: 1500),
    bool? finishesTransactions,
    void Function(IapStatus status)? onStatusChanged,
    Duration awaitingTimeout = const Duration(seconds: 60),
  })  : _repository = repository,
        _readAuthToken = readAuthToken,
        _restoreSettleDelay = restoreSettleDelay,
        _finishesTransactions =
            finishesTransactions ?? (Platform.isIOS || Platform.isAndroid),
        _onStatusChanged = onStatusChanged,
        _awaitingTimeout = awaitingTimeout {
    // Subscribed at construction (create the provider eagerly) so purchases
    // the store re-delivers at launch are never missed.
    _subscription = _repository.watchPurchaseUpdates().listen(
          _handlePurchaseUpdates,
          onError: (Object e) => log('Purchase stream error: $e'),
        );
  }

  IapViewStatus get viewStatus => _viewStatus;
  IapActionStatus get purchaseStatus => _purchaseStatus;
  List<IapPlan> get plans => _plans;

  /// Subscription plans (monthly / yearly).
  List<IapPlan> get subscriptionPlans =>
      _plans.where((p) => !p.isOneTime).toList();

  /// One-time plans (programmes, packs).
  List<IapPlan> get oneTimePlans => _plans.where((p) => p.isOneTime).toList();

  IapStatus? get status => _status;
  bool get isPremium => _status?.isPremium ?? false;
  bool get ownsOneTimePlan => _status?.ownedPlanIds.isNotEmpty ?? false;

  String? get activeProductId => _activeProductId;
  String? get lastPurchasedProductId => _lastPurchasedProductId;
  String? get message => _message;

  /// True while the app itself is busy; a global loader can follow this.
  bool get isWorking => _purchaseStatus.isWorking;

  /// Restore stays available while a store sheet is open or after one was
  /// dismissed; only a running verify / restore blocks it.
  bool get canRestore =>
      _purchaseStatus != IapActionStatus.verifying &&
      _purchaseStatus != IapActionStatus.restoring;

  bool isProcessingProduct(String? productId) =>
      productId != null && _activeProductId == productId && isWorking;

  IapPlan? _planForProduct(String productId) {
    for (final plan in _plans) {
      if (plan.storeProductId == productId) return plan;
    }
    return null;
  }

  /// True when the backend already grants what [productId] sells. A one-time
  /// purchase is judged by its own plan, never by the subscription: a member
  /// buying a programme is not a renewal.
  bool _isProductActive(String productId) {
    final plan = _planForProduct(productId);
    if (plan != null && plan.isOneTime) {
      return _status?.ownedPlanIds.contains(plan.id) == true;
    }
    return isPremium || ownsOneTimePlan;
  }

  Future<void> loadPlans() async {
    _emit(() {
      _viewStatus = IapViewStatus.loading;
      _message = null;
    });

    final response = await _repository.getCatalog();

    if (!response.success) {
      _emit(() {
        _viewStatus = IapViewStatus.error;
        _message = response.message ?? 'Could not load the plans.';
      });
      return;
    }

    _emit(() {
      _plans = response.plans;
      _applyStatus(response.status);
      _viewStatus = IapViewStatus.success;
    });
  }

  /// Re-reads what the user owns from the backend. Returns false when the
  /// backend could not be reached.
  Future<bool> refreshStatus() async {
    final response = await _repository.getStatus();
    if (!response.success || response.status == null) return false;

    _emit(() => _applyStatus(response.status));
    return true;
  }

  Future<void> buyPlan(IapPlan plan) async {
    final productId = plan.storeProductId;
    if (productId == null) {
      _fail('This plan is not available on this device.');
      return;
    }

    if (!plan.isOneTime && isPremium) {
      _emit(() => _message = 'You already have an active plan.');
      return;
    }
    if (plan.isOneTime && _status?.ownedPlanIds.contains(plan.id) == true) {
      _emit(() => _message = 'You already have access to this plan.');
      return;
    }

    if (_accountToken == null) await refreshStatus();
    final accountToken = _accountToken;
    if (accountToken == null) {
      _fail('Could not start the purchase. Please try again.');
      return;
    }

    _cycleByProduct[productId] = plan.cycle;
    _emit(() {
      _activeProductId = productId;
      _purchaseStatus = IapActionStatus.processing;
      _message = null;
    });
    iapLog('PURCHASE started product=$productId cycle=${plan.cycle.name}');

    // Never charge twice: if the store already holds this user's purchase
    // (paid earlier, never activated), activate that instead.
    await _runRestore(quiet: true);
    final isAlreadyOwned = plan.isOneTime
        ? (_status?.ownedPlanIds.contains(plan.id) == true)
        : isPremium;
    if (isAlreadyOwned) {
      iapLog('PURCHASE skipped, existing store purchase was activated');
      _emit(() {
        _purchaseStatus = IapActionStatus.idle;
        _activeProductId = null;
        _message = 'Your existing purchase was found and activated.';
      });
      return;
    }

    final error = await _repository.buy(
      productId: productId,
      accountToken: accountToken,
      cycle: plan.cycle,
    );

    if (error != null) {
      _fail(error);
      return;
    }
    // Not purchased yet: the store answers on the purchase stream.
    _emit(() => _purchaseStatus = IapActionStatus.awaitingStoreConfirmation);
    _awaitingTimer?.cancel();
    _awaitingTimer = Timer(_awaitingTimeout, () {
      if (_purchaseStatus != IapActionStatus.awaitingStoreConfirmation) return;
      _emit(() {
        _purchaseStatus = IapActionStatus.idle;
        _activeProductId = null;
      });
    });
  }

  /// Asks the store for the user's earlier purchases, then has the backend
  /// re-verify them in one call.
  Future<void> restorePurchases() => _runRestore(quiet: false);

  /// [quiet] is the pre-purchase check: it only activates what the store
  /// already holds and reports nothing when there is nothing to restore.
  Future<void> _runRestore({required bool quiet}) async {
    if (_isRestoring) return;
    _awaitingTimer?.cancel();
    _isRestoring = true;
    _restoreBuffer.clear();
    if (!quiet) {
      _emit(() {
        _purchaseStatus = IapActionStatus.restoring;
        _activeProductId = null;
        _message = null;
      });
    }

    try {
      final error = await _repository.restoreFromStore();
      if (error != null) {
        iapLog('RESTORE store query failed: $error');
        if (!quiet) _fail(error);
        return;
      }

      await _waitForRestoredPurchases();

      final restored = _restoreBuffer.where((p) => p.hasToken).toList();
      iapLog('RESTORE store returned ${restored.length} purchase(s)');
      // The pre-purchase check has nothing to send for an empty store; a
      // user-triggered restore still asks the backend, which re-verifies what
      // it already knows about the account.
      if (restored.isEmpty && quiet) return;

      final response = await _repository.restore(
        restored.map(_paramsFor).toList(),
      );
      iapLog(
        'RESTORE backend success=${response.success} '
        'restored=${response.restored} message=${response.message}',
      );

      if (!response.success) {
        if (!quiet) _fail(response.message ?? 'Could not restore purchases.');
        return;
      }

      final succeeded = response.items
          .where((r) => r.success)
          .map((r) => r.productId)
          .toSet();
      for (final purchase in restored) {
        if (succeeded.contains(purchase.productId)) {
          await _finishTransaction(purchase);
        }
      }

      _emit(() {
        _applyStatus(response.status);
        if (quiet) return;
        _purchaseStatus = IapActionStatus.idle;
        _message = response.restored > 0
            ? 'Purchases restored successfully.'
            : 'No active purchases were found to restore.';
      });
    } finally {
      _isRestoring = false;
      _restoreBuffer.clear();
    }
  }

  void clearFeedback() {
    _emit(() {
      if (!_purchaseStatus.isWorking) _purchaseStatus = IapActionStatus.idle;
      _message = null;
      _lastPurchasedProductId = null;
      _activeProductId = null;
    });
  }

  /// Logout: forget the previous user's plans, status and account token.
  void clear() {
    _emit(() {
      _viewStatus = IapViewStatus.initial;
      _purchaseStatus = IapActionStatus.idle;
      _plans = [];
      _status = null;
      _accountToken = null;
      _activeProductId = null;
      _lastPurchasedProductId = null;
      _message = null;
    });
    _activatedTokens.clear();
    _cycleByProduct.clear();
  }

  Future<void> _handlePurchaseUpdates(List<IapPurchaseUpdate> updates) async {
    _awaitingTimer?.cancel();
    iapLog('CALLBACK purchaseStream delivered ${updates.length} update(s)');
    for (final purchase in updates) {
      iapLog('CALLBACK ${purchase.describe()}');
      try {
        await _handleOne(purchase);
      } catch (e, stack) {
        // Whatever threw here (UI listener, parsing), the purchase itself is
        // not failed: it stays unfinished and verifiable through Restore.
        log('IAP update handling threw: $e', stackTrace: stack, name: 'IAP');
        _emit(() {
          _purchaseStatus = IapActionStatus.idle;
          _message = _recoverableMessage;
        });
      }
    }
  }

  Future<void> _handleOne(IapPurchaseUpdate purchase) async {
    switch (purchase.status) {
      case IapPurchaseStatus.pending:
        _emit(() {
          _activeProductId = purchase.productId;
          _purchaseStatus = IapActionStatus.idle;
          _message =
              'Your payment is pending. Access starts once it completes.';
        });
      case IapPurchaseStatus.purchased:
        if (!purchase.hasToken) {
          iapLog('PURCHASED update without a purchase token, cannot verify');
          _fail('The store did not return a purchase token. Try Restore.');
          return;
        }
        await _verifyAndFinish(purchase);
      case IapPurchaseStatus.restored:
        if (_isRestoring) {
          _restoreBuffer.add(purchase);
          _restartRestoreTimer();
        } else if (purchase.hasToken) {
          await _verifyAndFinish(purchase);
        }
      case IapPurchaseStatus.canceled:
        // The user closed the sheet: not an error, nothing to tell them.
        _emit(() {
          _activeProductId = purchase.productId;
          _purchaseStatus = IapActionStatus.canceled;
          _message = null;
        });
        await _finishTransaction(purchase);
      case IapPurchaseStatus.error:
        await _handleStoreError(purchase);
    }
  }

  Future<void> _handleStoreError(IapPurchaseUpdate purchase) async {
    if (purchase.isAlreadyOwned) {
      // Paid earlier, never activated: recover instead of reporting failure.
      iapLog('ERROR itemAlreadyOwned, recovering the existing subscription');
      await _runRestore(quiet: false);
      return;
    }
    final text = iapStoreErrorMessage(
      code: purchase.errorCode,
      message: purchase.errorMessage,
      details: purchase.errorDetails,
    );
    iapLog('ERROR store reported a purchase error: $text');
    _emit(() {
      _activeProductId = purchase.productId;
      _purchaseStatus = IapActionStatus.failure;
      _message = text;
    });
    await _finishTransaction(purchase);
  }

  static const String _recoverableMessage =
      'Your payment went through, but we could not activate it yet. '
      'Tap Restore purchases to try again; you will not be charged twice.';

  Future<void> _verifyAndFinish(IapPurchaseUpdate purchase) async {
    final key = purchase.purchaseToken;
    if (_activatedTokens.contains(key) &&
        _isProductActive(purchase.productId)) {
      iapLog('VERIFY skipped, token already activated this session');
      return;
    }
    if (!_inFlightTokens.add(key)) {
      iapLog('VERIFY skipped, same token is already being verified');
      return;
    }
    try {
      await _verifyOnce(purchase);
    } finally {
      _inFlightTokens.remove(key);
    }
  }

  Future<void> _verifyOnce(IapPurchaseUpdate purchase) async {
    final authToken = await _readAuthToken();
    if (authToken == null || authToken.isEmpty) {
      iapLog('VERIFY deferred, nobody is signed in');
      return;
    }

    // A subscription purchase that arrives while a plan is already active is a
    // renewal (or a re-delivery): verify it quietly, with no loader or toast.
    // A one-time plan is never a renewal, even for a member.
    final plan = _planForProduct(purchase.productId);
    final isRenewal = isPremium && !(plan?.isOneTime ?? false);

    if (!isRenewal) {
      _emit(() {
        _activeProductId = purchase.productId;
        _purchaseStatus = IapActionStatus.verifying;
        _message = null;
      });
    }

    final response = await _repository.verify(_paramsFor(purchase));

    // A failed verification leaves the transaction unfinished on purpose so
    // the store hands it back (Restore / next launch). The payment is NOT
    // reported as a failed purchase: the store already took it.
    if (!response.success) {
      iapLog(
        'VERIFY failed unreachable=${response.unreachable} '
        'message=${response.message}',
      );
      // An expired purchase can never become valid: finish it so the store
      // stops handing it back at every launch.
      if (_isExpiredRejection(response.message)) {
        await _finishTransaction(purchase);
      }
      if (!isRenewal) {
        _fail(
          response.unreachable
              ? _recoverableMessage
              : 'Payment received but activation failed: '
                  '${response.message ?? 'verification error'}. '
                  'Tap Restore purchases to retry.',
        );
      }
      return;
    }
    if (response.pending) {
      iapLog('VERIFY backend reports the payment as pending');
      if (!isRenewal) {
        _emit(() {
          _purchaseStatus = IapActionStatus.idle;
          _message =
              'Your payment is pending. Access starts once it completes.';
        });
      }
      return;
    }

    await _finishTransaction(purchase);
    _activatedTokens.add(purchase.purchaseToken);

    // The backend, not the store callback, decides: apply what verify said,
    // then re-read the status before showing success.
    _emit(() => _applyStatus(response.status));
    final refreshed = await refreshStatus();
    final activated = _isProductActive(purchase.productId);
    iapLog(
      'ACTIVATION statusRefetched=$refreshed product=${purchase.productId} '
      'premium=$isPremium oneTime=$ownsOneTimePlan activated=$activated',
    );

    _emit(() {
      if (isRenewal) return;
      if (activated) {
        _purchaseStatus = IapActionStatus.success;
        _lastPurchasedProductId = purchase.productId;
        _message = null;
      } else {
        _purchaseStatus = IapActionStatus.idle;
        _message = 'Payment confirmed. Your purchase is still being activated; '
            'check again in a moment.';
      }
    });
  }

  IapVerifyParams _paramsFor(IapPurchaseUpdate purchase) =>
      IapVerifyParams.fromPurchase(
        purchase,
        cycle: _cycleByProduct[purchase.productId],
      );

  bool _isExpiredRejection(String? message) {
    final text = message?.toLowerCase() ?? '';
    return text.contains('no longer active') || text.contains('expired');
  }

  Future<void> _finishTransaction(IapPurchaseUpdate purchase) async {
    if (!_finishesTransactions || !purchase.pendingCompletePurchase) {
      iapLog(
        'COMPLETE skipped for ${purchase.productId} '
        '(finishesTransactions=$_finishesTransactions)',
      );
      return;
    }

    try {
      await _repository.completePurchase(purchase);
    } catch (e) {
      iapLog('COMPLETE failed for ${purchase.productId}: $e');
    }
  }

  void _applyStatus(IapStatus? status) {
    if (status == null) return;
    _status = status;
    _accountToken = status.accountToken ?? _accountToken;
    _onStatusChanged?.call(status);
  }

  void _restartRestoreTimer() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(_restoreSettleDelay, () {
      if (_restoreSettled?.isCompleted == false) _restoreSettled!.complete();
    });
  }

  Future<void> _waitForRestoredPurchases() {
    _restoreSettled = Completer<void>();
    _restartRestoreTimer();
    return _restoreSettled!.future;
  }

  void _fail(String message) {
    _emit(() {
      _purchaseStatus = IapActionStatus.failure;
      _message = iapShorten(message);
    });
  }

  void _emit(VoidCallback change) {
    if (_isDisposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _restoreTimer?.cancel();
    _awaitingTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
