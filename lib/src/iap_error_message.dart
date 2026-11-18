import 'iap_log.dart';

const String _genericStoreError =
    'The store could not complete this request. Please try again.';

/// Short, readable text for anything the store or plugin throws. The raw
/// error (often a long platform stack text) goes to the debug log only.
String iapErrorMessage(Object error) {
  iapLog('ERROR raw: $error');

  if (error is String) {
    final text = error.trim();
    if (text.isNotEmpty && text.length <= 120 && !text.contains('\n')) {
      return text;
    }
  }
  return _genericStoreError;
}

/// Server messages can be long; keep toasts to a couple of lines.
String iapShorten(String message, {int max = 140}) {
  final text = message.trim();
  return text.length <= max ? text : '${text.substring(0, max - 1)}…';
}

/// Readable text for a store purchase error. Google Play reports a
/// `BillingResponse.*` name in [message]; unknown values fall back to the raw
/// message (short) so the real reason is never hidden behind a generic toast.
String iapStoreErrorMessage({String? code, String? message, String? details}) {
  final raw = (message ?? '').toLowerCase();
  const known = <String, String>{
    'serviceunavailable':
        'Google Play is unavailable right now. Check your connection and try again.',
    'servicetimeout': 'Google Play took too long to respond. Please try again.',
    'billingunavailable':
        'Google Play billing is not available on this device or account.',
    'itemunavailable': 'This plan is not available in Google Play right now.',
    'developererror':
        'This build is not set up for Google Play billing. Contact support.',
    'featurenotsupported':
        'Subscriptions are not supported by this Google Play version.',
    'networkerror': 'Network problem while talking to Google Play.',
  };
  for (final entry in known.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }
  final reason = [message, details]
      .whereType<String>()
      .map((t) => t.trim())
      .firstWhere((t) => t.isNotEmpty, orElse: () => '');
  final label = (code == null || code.isEmpty) ? 'store error' : code;
  return reason.isEmpty
      ? 'The store could not complete the purchase ($label).'
      : iapShorten('Store: $reason');
}
