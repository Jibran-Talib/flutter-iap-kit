import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'iap_enums.dart';

/// One purchase as the kit sees it. Wraps the plugin's [PurchaseDetails]
/// (kept because the store needs it back to finish the transaction); the
/// details are optional so tests can build updates without the plugin.
class IapPurchaseUpdate {
  final PurchaseDetails? purchaseDetails;
  final String productId;
  final IapPurchaseStatus status;
  final bool pendingCompletePurchase;

  /// Google: purchase token. Apple: transaction id.
  final String purchaseToken;

  /// Store error behind a [IapPurchaseStatus.error] update.
  final String? errorCode;
  final String? errorMessage;
  final String? errorDetails;

  const IapPurchaseUpdate({
    required this.productId,
    required this.status,
    required this.pendingCompletePurchase,
    required this.purchaseToken,
    this.purchaseDetails,
    this.errorCode,
    this.errorMessage,
    this.errorDetails,
  });

  factory IapPurchaseUpdate.fromPurchaseDetails(PurchaseDetails details) {
    return IapPurchaseUpdate(
      purchaseDetails: details,
      productId: details.productID,
      status: mapStatus(details.status),
      pendingCompletePurchase: details.pendingCompletePurchase,
      purchaseToken: Platform.isIOS
          ? details.purchaseID ?? ''
          : details.verificationData.serverVerificationData,
      errorCode: details.error?.code,
      errorMessage: details.error?.message,
      errorDetails: details.error?.details?.toString(),
    );
  }

  bool get hasToken => purchaseToken.isNotEmpty;

  /// Google Play answered the billing flow with no purchase object at all:
  /// the update only carries a result code.
  bool get isResultOnly => productId.isEmpty && purchaseToken.isEmpty;

  /// The user already owns this subscription in Google Play: the money was
  /// taken earlier and only the app-side activation is missing.
  bool get isAlreadyOwned => '${errorMessage ?? ''} ${errorCode ?? ''}'
      .toLowerCase()
      .contains('alreadyowned');

  /// One line for the log: never the token itself.
  String describe() =>
      'product=${productId.isEmpty ? 'none' : productId} status=${status.name} '
      'token=${hasToken ? 'present(${purchaseToken.length} chars)' : 'none'} '
      'pendingComplete=$pendingCompletePurchase '
      'errorCode=$errorCode errorMessage=$errorMessage';

  static IapPurchaseStatus mapStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.pending:
        return IapPurchaseStatus.pending;
      case PurchaseStatus.purchased:
        return IapPurchaseStatus.purchased;
      case PurchaseStatus.restored:
        return IapPurchaseStatus.restored;
      case PurchaseStatus.error:
        return IapPurchaseStatus.error;
      case PurchaseStatus.canceled:
        return IapPurchaseStatus.canceled;
    }
  }
}

/// One purchase as the backend wants it, for both verify and restore.
class IapVerifyParams {
  final String productId;
  final String purchaseToken;

  const IapVerifyParams({required this.productId, required this.purchaseToken});

  factory IapVerifyParams.fromPurchase(IapPurchaseUpdate purchase) =>
      IapVerifyParams(
        productId: purchase.productId,
        purchaseToken: purchase.purchaseToken,
      );

  /// `android` or `ios`.
  static String get platform => Platform.isAndroid ? 'android' : 'ios';
}
