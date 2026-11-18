import 'dart:developer' as developer;

/// Billing trace (what the store sends, what the app asks of the store and the
/// backend). Goes through `dart:developer` so it also reaches release logcat
/// captures; it never carries a full purchase token or payment details.
void iapLog(String message) {
  developer.log(message, name: 'IAP');
}

/// Purchase tokens are secrets: the log only says whether one exists and how
/// long it is, never any of its characters.
String iapMask(String value) =>
    value.isEmpty ? 'none' : 'present(${value.length} chars)';
