import '../model/iap_plan.dart';
import '../model/iap_status.dart';
import '../model/iap_verify_result.dart';
import '../model/iap_purchase_update.dart';

/// The only thing an app has to implement: how to talk to ITS backend.
///
/// Never throw from these methods. Return a failure result with the server's
/// own message; set `unreachable: true` on [IapVerifyResult] when the server
/// gave no answer at all (timeout, offline).
abstract class IapBackend {
  /// Plans to show, with backend product ids for both stores.
  Future<IapCatalog> getCatalog();

  /// What the user owns right now (also gives the account token).
  Future<IapStatusResult> getStatus();

  /// The server must verify with Apple / Google. Idempotent per token.
  Future<IapVerifyResult> verify(IapVerifyParams params);

  /// Re-verify everything the store lists for this user.
  Future<IapRestoreResult> restore(List<IapVerifyParams> purchases);
}
