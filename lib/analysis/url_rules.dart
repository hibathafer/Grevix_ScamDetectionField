import '../models/analysis_result.dart';

// Deterministic, fully transparent URL rules.
//
// Every rule produces an [Indicator] with a plain-English explanation so the
// user can see exactly *why* a link was flagged. Nothing here is hidden or
// scored by a black box.

/// Top level domains commonly abused by mass phishing kits.
const suspiciousTlds = <String>{
  'xyz',
  'top',
  'click',
  'link',
  'icu',
  'rest',
  'cfd',
  'zip',
  'mov',
  'tk',
  'ml',
  'ga',
  'cf',
  'gq',
  'work',
  'online',
  'site',
  'space',
  'fun',
  'buy',
  'deal',
  'racing',
  'review',
  'party',
  'stream',
  'download',
  'trade',
  'accountant',
  'science',
  'casino',
  'poker',
  'bet',
  'gdn',
  'buzz',
  'monster',
  'cyou',
  'beauty',
  'hair',
  'makeup',
  'quest',
};

/// Known link shorteners: they hide the real destination.
const shortenerDomains = <String>{
  'bit.ly',
  'tinyurl.com',
  'goo.gl',
  'is.gd',
  'ow.ly',
  'buff.ly',
  'cutt.ly',
  'cutt.us',
  'shorturl.at',
  'rebrand.ly',
  'rb.gy',
  'tiny.cc',
  'v.gd',
  't.co',
  'x.co',
  'lnkd.in',
  's.id',
  'trib.al',
};

/// Words that look like a credential or account checkpoint when they appear
/// inside a domain name.
const accountWords = <String>{
  'login',
  'logon',
  'signin',
  'secure',
  'security',
  'verify',
  'verification',
  'validate',
  'validation',
  'account',
  'auth',
  'unlock',
  'update',
  'confirm',
  'password',
  'passwd',
  'billing',
  'wallet',
  'recovery',
  'session',
  'profile',
  'credential',
};

/// Extra words that are frequently abused in domains.
const lureWords = <String>{
  'bank',
  'payment',
  'pay',
  'fee',
  'invoice',
  'prize',
  'claim',
  'reward',
  'gift',
  'bonus',
  'free',
  'money',
  'cash',
  'crypto',
  'invest',
  'profit',
  'offer',
  'sale',
  'cheap',
  'win',
  'winner',
};

/// Real brands that attackers impersonate, mapped to their official domain.
const brandDomains = <String, String>{
  'paypal': 'paypal.com',
  'apple': 'apple.com',
  'microsoft': 'microsoft.com',
  'google': 'google.com',
  'amazon': 'amazon.com',
  'netflix': 'netflix.com',
  'facebook': 'facebook.com',
  'instagram': 'instagram.com',
  'whatsapp': 'whatsapp.com',
  'telegram': 'telegram.org',
  'binance': 'binance.com',
  'coinbase': 'coinbase.com',
  'ebay': 'ebay.com',
  'alibaba': 'alibaba.com',
  'chase': 'chase.com',
  'hsbc': 'hsbc.com',
  'barclays': 'barclays.com',
  'santander': 'santander.com',
  'citibank': 'citibank.com',
  'wellsfargo': 'wellsfargo.com',
  'steam': 'steampowered.com',
  'spotify': 'spotify.com',
  'dhl': 'dhl.com',
  'fedex': 'fedex.com',
  'unionbank': 'unionbank.com',
};

/// Extensions that almost never arrive through an innocent link.
const dangerousExtensions = <String>{
  'exe',
  'apk',
  'scr',
  'msi',
  'bat',
  'cmd',
  'vbs',
  'lnk',
  'jar',
  'ps1',
  'reg',
  'hta',
  'chm',
  'com',
};

const archiveExtensions = <String>{'zip', 'rar', '7z', 'iso', 'gz'};

/// Query parameter names that mean credentials are being transmitted.
const credentialQueryKeys = <String>{
  'password',
  'passwd',
  'pwd',
  'pass',
  'otp',
  'pin',
  'token',
  'secret',
  'apikey',
  'api_key',
  'cvv',
  'credential',
};

/// Words in the path/query that suggest an account checkpoint page.
const checkpointPathWords = <String>{
  'login',
  'logon',
  'signin',
  'verify',
  'verification',
  'update',
  'confirm',
  'account',
  'secure',
  'password',
  'otp',
  'wallet',
  'billing',
  'unlock',
  'recover',
};

Indicator _hit(
  String id,
  String title,
  String explanation,
  IndicatorSeverity severity,
) =>
    Indicator(
      id: id,
      title: title,
      explanation: explanation,
      severity: severity,
      source: IndicatorSource.link,
    );

bool _isPrivateOrReservedIp(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final values = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value > 255) return false;
    values.add(value);
  }
  final first = values[0];
  final second = values[1];
  if (first == 10 || first == 127 || first == 0) return true;
  if (first == 192 && second == 168) return true;
  if (first == 169 && second == 254) return true;
  if (first == 172 && second >= 16 && second <= 31) return true;
  return false;
}

bool _isIpv4(String host) =>
    RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);

/// Splits a host name into lowercase alphanumeric tokens
/// (`secure-login.paypal.com` -> [secure, login, paypal, com]).
List<String> _tokens(String host) => host
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// Host part of a raw, possibly malformed URL string.
String _rawHost(String raw) {
  var s = raw.trim();
  final schemeIndex = s.indexOf('://');
  if (schemeIndex != -1) s = s.substring(schemeIndex + 3);
  for (final c in ['/', '?', '#']) {
    final i = s.indexOf(c);
    if (i != -1) s = s.substring(0, i);
  }
  final atIndex = s.lastIndexOf('@');
  if (atIndex != -1) s = s.substring(atIndex + 1);
  final colonIndex = s.indexOf(':');
  if (colonIndex != -1) s = s.substring(0, colonIndex);
  return s.toLowerCase();
}

/// Runs every URL rule against [rawInput] and returns the signals found.
List<Indicator> analyzeLink(String rawInput) {
  final findings = <Indicator>[];
  final raw = rawInput.trim();
  if (raw.isEmpty) return findings;

  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://').hasMatch(raw);
  final target = hasScheme ? raw : 'https://$raw';

  // Text before "@" in the authority hides the real destination.
  final schemeIndex = target.indexOf('://');
  if (schemeIndex != -1) {
    var authorityEnd = target.length;
    for (final c in ['/', '?', '#']) {
      final i = target.indexOf(c, schemeIndex + 3);
      if (i != -1 && i < authorityEnd) authorityEnd = i;
    }
    final authority = target.substring(schemeIndex + 3, authorityEnd);
    if (authority.contains('@')) {
      findings.add(_hit(
        'userinfo_at',
        'Address hides the real destination',
        'The part before "@" is only a label. The real website you would open '
            'is the one after it, which is a classic trick used to make a '
            'malicious link look legitimate.',
        IndicatorSeverity.critical,
      ));
    }
  }

  final uri = Uri.tryParse(target);
  final host = uri?.host.isNotEmpty == true ? uri!.host.toLowerCase() : '';

  if (host.isEmpty) {
    findings.add(_hit(
      'malformed',
      'Address could not be parsed',
      'This does not look like a complete website address, so only limited '
          'checks could be run. Be extra careful with it.',
      IndicatorSeverity.warning,
    ));
    return findings;
  }

  final rawHost = _rawHost(raw);

  // Punycode / non-ASCII characters can imitate another brand's letters.
  if (host.contains('xn--') || rawHost.runes.any((r) => r > 127)) {
    findings.add(_hit(
      'homograph',
      'Unusual characters in the address',
      'The address uses encoded or non-standard characters. Attackers use '
          'this to make one brand look like another (for example a letter that '
          'resembles an "a").',
      IndicatorSeverity.critical,
    ));
  }

  if (_isIpv4(host)) {
    final isPrivate = _isPrivateOrReservedIp(host);
    findings.add(_hit(
      'ip_host',
      'Address uses a number instead of a domain name',
      isPrivate
          ? 'The link points at a private network address. Only do this if '
              'you personally set up that device.'
          : 'The link points straight at an IP number rather than a named '
              'website. Scam pages are frequently hosted this way to hide who '
              'runs them.',
      isPrivate ? IndicatorSeverity.warning : IndicatorSeverity.critical,
    ));
  } else if (!host.contains('.')) {
    findings.add(_hit(
      'no_tld',
      'Address is missing a domain ending',
      'A normal website address ends with something like .com or .org. This '
          'one does not, so it may not lead where you expect.',
      IndicatorSeverity.warning,
    ));
  }

  // brand.com.attacker.tld -> the brand is only decoration.
  for (final entry in brandDomains.entries) {
    if (host == entry.value) continue;
    final spoofPattern = '${entry.value}.';
    if (host.contains(spoofPattern)) {
      findings.add(_hit(
        'spoofed_structure',
        'Brand name used as a fake sub-domain',
        'The address places "${entry.value}" in front of the real domain name, '
            'so the site you would actually visit is controlled by someone '
            'else.',
        IndicatorSeverity.critical,
      ));
      break;
    }
  }

  final hostTokens = _tokens(host);
  final accountHits = hostTokens.where(accountWords.contains).toSet();
  final lureHits = hostTokens.where(lureWords.contains).toSet();

  // Brand impersonation: real brand name + credential wording, not official.
  for (final entry in brandDomains.entries) {
    final brand = entry.key;
    final official = entry.value;
    if (host == official || host.endsWith('.$official')) continue;
    if (!hostTokens.contains(brand) && !host.contains(brand)) continue;
    if (accountHits.isEmpty && !lureHits.contains('pay') && !lureHits.contains('fee')) {
      findings.add(_hit(
        'brand_in_domain',
        'Familiar brand name inside a different address',
        'The address contains the name "$brand" but it is not the official '
            'site ($official). Brand names inside unrelated domains are a '
            'common way to gain trust.',
        IndicatorSeverity.warning,
      ));
    } else {
      findings.add(_hit(
        'brand_impersonation',
        'Impersonates $brand',
        'The address combines the $brand name with words like '
            '"${(accountHits.toList()..sort()).join('", "')}" while not being '
            'the official $official domain. This is a phishing pattern.',
        IndicatorSeverity.critical,
      ));
    }
    break;
  }

  // Two or more suspicious words in one domain is a strong signal.
  final combinedWords = <String>{...accountHits, ...lureHits};
  if (combinedWords.length >= 2) {
    findings.add(_hit(
      'suspicious_domain_words',
      'Domain is packed with scam wording',
      'The domain name contains several loaded words at once: '
          '"${(combinedWords.toList()..sort()).join('", "')}". Legitimate '
          'websites rarely need this many triggers in their address.',
      IndicatorSeverity.critical,
    ));
  } else if (combinedWords.length == 1) {
    findings.add(_hit(
      'suspicious_domain_word',
      'Domain contains a loaded word',
      'The domain name includes the word "${combinedWords.first}", which is '
          'often used to make a link look urgent or official.',
      IndicatorSeverity.warning,
    ));
  }

  final labels = host.split('.');
  if (labels.length >= 5) {
    findings.add(_hit(
      'excessive_subdomains',
      'Unusually many sub-domains',
      'The address has ${labels.length} parts separated by dots. Deeply '
          'nested addresses are often used to make a link look like a long, '
          'official one.',
      IndicatorSeverity.warning,
    ));
  }

  final sld = labels.length >= 2 ? labels[labels.length - 2] : host;
  final hyphens = '-'.allMatches(sld).length;
  if (hyphens >= 3) {
    findings.add(_hit(
      'many_hyphens',
      'Domain name is split by many dashes',
      'The main part of the address contains $hyphens dashes. Randomly '
          'hyphenated domains are common in generated scam links.',
      IndicatorSeverity.warning,
    ));
  }

  final digitsInHost = host.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (digitsInHost >= 5) {
    findings.add(_hit(
      'many_digits',
      'Domain contains many numbers',
      'The address contains $digitsInHost digits, which usually means it was '
          'generated rather than chosen by a real organisation.',
      IndicatorSeverity.info,
    ));
  }

  final tld = labels.length >= 2 ? labels.last : '';
  if (suspiciousTlds.contains(tld)) {
    findings.add(_hit(
      'suspicious_tld',
      'Domain ending commonly abused by scammers',
      'Websites ending in ".$tld" are cheap to register in bulk and are '
          'frequently reported for phishing, so treat this link with caution.',
      IndicatorSeverity.warning,
    ));
  }

  if (shortenerDomains.contains(host) ||
      shortenerDomains.any((d) => host.endsWith('.$d'))) {
    findings.add(_hit(
      'shortener',
      'Link is shortened, destination is hidden',
      'This is a link shortener. The visible text does not tell you where you '
          'will really end up, so the destination cannot be judged from the '
          'link itself.',
      IndicatorSeverity.warning,
    ));
  }

  if (hasScheme && uri?.hasScheme == true && uri!.scheme == 'http') {
    findings.add(_hit(
      'http_scheme',
      'Connection is not encrypted',
      'The link starts with "http://" instead of "https://". Anything you '
          'type on that page can be read in transit.',
      IndicatorSeverity.warning,
    ));
  }

  final port = uri?.port;
  if (port != null && port != 80 && port != 443) {
    findings.add(_hit(
      'non_standard_port',
      'Unusual network port',
      'The link uses port $port instead of the normal web ports. Ordinary '
          'websites almost never need this.',
      IndicatorSeverity.warning,
    ));
  }

  final pathAndQuery = '${uri?.path ?? ''}${uri?.query ?? ''}';

  for (final entry in brandDomains.entries) {
    if (!pathAndQuery.toLowerCase().contains(entry.key)) continue;
    if (host == entry.value || host.endsWith('.${entry.value}')) continue;
    findings.add(_hit(
      'brand_in_path',
      'Brand name used inside the link address',
      'The path of the link mentions "${entry.key}" while the domain is '
          'different from ${entry.value}. This is often used to make a fake '
          'page look official.',
      IndicatorSeverity.warning,
    ));
    break;
  }

  final pathTokens =
      pathAndQuery.toLowerCase().split(RegExp(r'[^a-z0-9]+')).toSet();
  final checkpointHits = pathTokens.where(checkpointPathWords.contains).toSet();
  if (checkpointHits.isNotEmpty) {
    findings.add(_hit(
      'checkpoint_path',
      'Link points at an account checkpoint page',
      'The address leads to a page about '
          '"${(checkpointHits.toList()..sort()).join('", "')}", which is where '
          'scammers ask people to confirm account details.',
      IndicatorSeverity.warning,
    ));
  }

  final queryKeys = (uri?.queryParameters.keys ?? const <String>[])
      .map((k) => k.toLowerCase());
  final credentialKeys = queryKeys.where(credentialQueryKeys.contains).toSet();
  if (credentialKeys.isNotEmpty) {
    findings.add(_hit(
      'credential_in_query',
      'Link carries secret data in its address',
      'The link already contains '
          '"${(credentialKeys.toList()..sort()).join('", "')}" in its '
          'parameters. Links should never carry passwords or codes.',
      IndicatorSeverity.critical,
    ));
  }

  final lastSegment = pathAndQuery.isNotEmpty
      ? pathAndQuery.split('?').first.toLowerCase()
      : '';
  for (final ext in dangerousExtensions) {
    if (lastSegment.endsWith('.$ext')) {
      findings.add(_hit(
        'dangerous_download',
        'Link downloads a program',
        'The address points to a ".$ext" file. Installing or opening a '
            'program from an unexpected link is one of the fastest ways to '
            'lose control of a device.',
        IndicatorSeverity.critical,
      ));
      break;
    }
  }
  for (final ext in archiveExtensions) {
    if (lastSegment.endsWith('.$ext')) {
      findings.add(_hit(
        'archive_download',
        'Link downloads a compressed file',
        'The address points to a ".$ext" archive, which can hide its real '
            'contents. Only open archives you were expecting.',
        IndicatorSeverity.warning,
      ));
      break;
    }
  }

  final percentCount = '%'.allMatches(raw).length;
  if (percentCount >= 5) {
    findings.add(_hit(
      'heavy_encoding',
      'Address is heavily encoded',
      'The link contains $percentCount encoded characters, which can be used '
          'to disguise the real destination.',
      IndicatorSeverity.warning,
    ));
  }

  if (raw.length > 120) {
    findings.add(_hit(
      'very_long',
      'Very long address',
      'The link is ${raw.length} characters long. Long addresses are often '
          'used to hide the suspicious part somewhere in the middle.',
      IndicatorSeverity.info,
    ));
  }

  return findings;
}
