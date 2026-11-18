import 'iap_status.dart';

/// Answer to "is this purchase valid?".
class IapVerifyResult {
  final bool success;
  final String? message;
  final String? state;
  final DateTime? expiresAt;
  final bool autoRenew;

  /// The store has not settled the payment yet (e.g. cash payment).
  final bool pending;
  final bool alreadyProcessed;
  final IapStatus? status;

  /// No answer from the backend at all (timeout / offline): the purchase may
  /// well have been verified, so it is never treated as rejected.
  final bool unreachable;

  const IapVerifyResult({
    required this.success,
    this.message,
    this.state,
    this.expiresAt,
    this.autoRenew = false,
    this.pending = false,
    this.alreadyProcessed = false,
    this.status,
    this.unreachable = false,
  });

  factory IapVerifyResult.failure(String message, {bool unreachable = false}) =>
      IapVerifyResult(
        success: false,
        message: message,
        unreachable: unreachable,
      );
}

class IapRestoreItem {
  final String? productId;
  final bool success;
  final String? message;

  const IapRestoreItem({this.productId, this.success = false, this.message});
}

/// Answer to "re-verify everything the store says this user owns".
class IapRestoreResult {
  final bool success;
  final String? message;
  final int restored;
  final List<IapRestoreItem> items;
  final IapStatus? status;

  const IapRestoreResult({
    required this.success,
    this.message,
    this.restored = 0,
    this.items = const [],
    this.status,
  });

  factory IapRestoreResult.failure(String message) =>
      IapRestoreResult(success: false, message: message);
}
