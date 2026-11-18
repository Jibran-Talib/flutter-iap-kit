/// Where a store-billed plan is managed or cancelled. Apple and Google only let
/// the user do that in their own subscription settings.
class IapManageLink {
  final String androidPackage;

  const IapManageLink({required this.androidPackage});

  static const String _appleUrl =
      'https://apps.apple.com/account/subscriptions';

  /// [source] is the backend's billing source: `apple` or `google`. Anything
  /// else (web, admin, none) has no store page and returns null.
  Uri? forSource(String? source, {String? productId}) {
    switch (source) {
      case 'apple':
        return Uri.parse(_appleUrl);
      case 'google':
        final sku = productId == null ? '' : '&sku=$productId';
        return Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?package=$androidPackage$sku',
        );
      default:
        return null;
    }
  }
}
