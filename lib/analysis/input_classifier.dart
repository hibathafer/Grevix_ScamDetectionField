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

// ---------------------------------------------------------------------------
// Link validation
//
// A tester pasted free text into the Link tab and got "LOW RISK". That reads
// as "your input is safe", when in fact no usable address was ever checked.
// Random text must not be scored at all - it must be refused.
// ---------------------------------------------------------------------------

/// Why [validateLink] refused a value. The caller shows one friendly message
/// for every case, so this exists for tests and logs, not for the user.
enum UrlRejection {
  /// Contains whitespace, so it is a sentence rather than an address.
  hasSpaces,

  /// A scheme was written, but it is not `http` or `https`.
  unsupportedScheme,

  /// Parsed, but there is no host at all (`http://`).
  missingHost,

  /// Anything that does not parse into a usable domain or IP host.
  malformed,
}

/// Returns `null` when [value] is a website address this app may analyse.
///
/// Deliberately **stricter** than [looksLikeUrl], which only guesses which tab
/// to pre-select. It accepts what people actually paste:
///
/// * `https://example.com/x`, `http://example.com`, `example.com/x`,
///   `www.example.com/x`
/// * a raw IPv4 host such as `192.168.0.1` or `127.0.0.1:8080` — the rules
///   flag those on purpose, so validation must not reject them first
/// * `localhost`
///
/// and refuses free text, a non-http(s) scheme (`ftp:`, `file:`, `javascript:`,
/// `mailto:`, `data:`), an address with no host, and anything whose last label
/// cannot be a TLD. **Nothing here makes a network request**: the address is
/// parsed and inspected, never opened.
UrlRejection? validateLink(String value) {
  final t = value.trim();
  if (t.isEmpty) return UrlRejection.malformed;
  // A single space proves this is prose, and it is exactly the case the
  // original tester hit.
  if (RegExp(r'\s').hasMatch(t)) return UrlRejection.hasSpaces;

  final scheme =
      RegExp(r'^([a-z][a-z0-9+.\-]*):', caseSensitive: false).firstMatch(t);
  final String toParse;
  if (scheme == null) {
    // People paste `example.com/x` constantly; that is a real address.
    toParse = 'http://$t';
  } else {
    final name = scheme.group(1)!.toLowerCase();
    final rest = t.substring(scheme.end);
    // `localhost:8080` and `example.com:8080/a` are host:port, not a scheme
    // called "localhost". Only digits may follow, up to the path.
    if (RegExp(r'^\d+(?:[/?#]|$)').hasMatch(rest)) {
      toParse = 'http://$t';
    } else if (name != 'http' && name != 'https') {
      return UrlRejection.unsupportedScheme;
    } else {
      toParse = t;
    }
  }

  final uri = Uri.tryParse(toParse);
  if (uri == null) return UrlRejection.malformed;

  final host = uri.host.toLowerCase();
  if (host.isEmpty) return UrlRejection.missingHost;
  return _usableHost(host) ? null : UrlRejection.malformed;
}

final RegExp _ipv4Host = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
final RegExp _domainHost =
    RegExp(r'^(?:[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?\.)+[a-z]{2,63}$');

bool _usableHost(String host) {
  if (host == 'localhost') return true;
  // An IPv6 literal keeps its brackets in `Uri.host`.
  if (host.startsWith('[') && host.endsWith(']')) return true;
  if (_ipv4Host.hasMatch(host)) {
    // Every octet must be in range, so `999.1.1.1` is not a host.
    return host.split('.').every((part) {
      final octet = int.tryParse(part);
      return octet != null && octet <= 255;
    });
  }
  return _domainHost.hasMatch(host);
}
