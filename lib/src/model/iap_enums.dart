/// Result of a store purchase update, independent of the plugin's own enum.
enum IapPurchaseStatus { pending, purchased, restored, error, canceled }

/// Plan list loading.
enum IapViewStatus { initial, loading, success, error }

/// How a plan is billed.
enum IapBillingCycle { monthly, yearly, oneTime }

/// One purchase / restore action.
enum IapActionStatus {
  idle,
  processing,
  awaitingStoreConfirmation,
  verifying,
  restoring,
  success,
  failure,
  canceled,
}

extension IapActionStatusX on IapActionStatus {
  /// The app itself is working (starting the purchase, verifying, restoring),
  /// so a global loader may cover the screen. While the store's own sheet is
  /// open ([IapActionStatus.awaitingStoreConfirmation]) the app is waiting on
  /// the user, not working: no loader, because a dismissed sheet sends no
  /// event and the loader would never go away.
  bool get isWorking =>
      this == IapActionStatus.processing ||
      this == IapActionStatus.verifying ||
      this == IapActionStatus.restoring;
}
