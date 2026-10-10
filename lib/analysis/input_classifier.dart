import '../models/analysis_result.dart';
import 'url_rules.dart';

// Decides what kind of input the user pasted and pulls links out of text.

/// TLDs used only to recognise a bare domain inside a message.
const _extractionTlds = <String>{
  'com', 'net', 'org', 'io', 'co', 'me', 'app', 'dev', 'info', 'biz',
  'uk', 'de', 'fr', 'es', 'it', 'nl', 'pl', 'se', 'no', 'dk', 'fi',
  'cz', 'gr', 'pt', 'ch', 'at', 'be', 'ie', 'ro', 'hu', 'bg', 'ua',
  'ru', 'kz', 'tr', 'ir', 'eg', 'sa', 'ae', 'qa', 'kw', 'iq', 'jo',
  'lb', 'pk', 'in', 'bd', 'id', 'my', 'ph', 'sg', 'th', 'vn', 'jp',
  'kr', 'cn', 'au', 'nz', 'ca', 'mx', 'br', 'ar', 'cl', 'za', 'ng',
  'ke', 'tz', 'gh', 'dz', 'ma', 'tn', 'ly', 'sd',
  ...suspiciousTlds,
};

String get _tldPattern => _extractionTlds.join('|');

/// True when [value] looks like a single website address.
bool looksLikeUrl(String value) {
  final t = value.trim();
  if (t.isEmpty) return false;
  if (RegExp(r'^[a-z][a-z0-9+.\-]*://', caseSensitive: false).hasMatch(t)) {
    return true;
  }
  if (RegExp(r'^www\.', caseSensitive: false).hasMatch(t)) return true;
  if (t.contains(' ') || t.contains('\n')) return false;
  final match =
      RegExp(r'^[\w\-]+(?:\.[\w\-]+)+(?:[/?#]\S*)?$').hasMatch(t);
  return match && t.split('.').length >= 2;
}

/// Best-effort guess used to pre-select the right input tab.
InputKind detectInputKind(String value) {
  final t = value.trim();
  if (t.isEmpty) return InputKind.message;
  return looksLikeUrl(t) ? InputKind.link : InputKind.message;
}

/// Pulls up to [limit] links out of free text, ignoring e-mail addresses.
List<String> extractUrls(String text, {int limit = 3}) {
  final results = <String>[];
  final seen = <String>{};

  void addMatch(Match m) {
    if (results.length >= limit) return;
    final index = m.start;
    if (index > 0) {
      final prev = text[index - 1];
      // Skip e-mail addresses and parts of longer words.
      if (prev == '@' || RegExp(r'[\w.\-]').hasMatch(prev)) return;
    }
    var url = m.group(0) ?? '';
    url = url.replaceAll(RegExp(r'[.,;:!?)\]}]+$'), '');
    if (url.isEmpty) return;
    if (seen.add(url.toLowerCase())) results.add(url);
  }

  final withScheme =
      RegExp(r'(?:https?://|www\.)[^\s<>]+', caseSensitive: false);
  for (final m in withScheme.allMatches(text)) {
    addMatch(m);
    if (results.length >= limit) break;
  }

  final bare = RegExp(
    r'(?:[\w\-]+\.)+(?:' + _tldPattern + r')(?::\d+)?(?:[/?#][^\s<>]*)?',
    caseSensitive: false,
  );
  for (final m in bare.allMatches(text)) {
    addMatch(m);
    if (results.length >= limit) break;
  }

  return results;
}
