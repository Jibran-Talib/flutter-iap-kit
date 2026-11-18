/// What the backend says the user owns. The backend is the only authority:
/// the app caches this, it never grants access on its own.
class IapStatus {
  /// Apple `appAccountToken` / Google `obfuscatedAccountId` for this user.
  /// Sent with every purchase so the server can bind a purchase to an app user.
  final String? accountToken;

  /// True only while the backend says access is granted AND not expired.
  final bool isPremium;

  /// `apple`, `google` or anything else (web, admin) with no store page.
  final String? source;

  /// Backend plan id of the active subscription, if any.
  final String? activePlanId;
  final String? state;
  final DateTime? expiresAt;
  final bool autoRenew;

  /// Backend ids of one-time plans the user still has access to.
  final Set<String> ownedPlanIds;

  const IapStatus({
    this.accountToken,
    this.isPremium = false,
    this.source,
    this.activePlanId,
    this.state,
    this.expiresAt,
    this.autoRenew = false,
    this.ownedPlanIds = const {},
  });
}

class IapStatusResult {
  final bool success;
  final String? message;
  final IapStatus? status;

  const IapStatusResult({required this.success, this.message, this.status});

  factory IapStatusResult.failure(String message) =>
      IapStatusResult(success: false, message: message);
}
