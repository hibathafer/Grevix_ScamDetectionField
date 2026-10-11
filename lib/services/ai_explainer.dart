import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/analysis_result.dart';

/// A failure of the optional AI step, carrying a fixed [AiFailure] category
/// plus a short detail.
///
/// [detail] is only ever built by this file from a status code, a transport
/// message or one of the literals below. It must never receive the API key,
/// and never a raw provider response body.
class AiException implements Exception {
  const AiException(this.failure, [this.detail]);

  final AiFailure failure;
  final String? detail;

  @override
  String toString() => detail == null
      ? 'AiException(${failure.name})'
      : 'AiException(${failure.name}: $detail)';
}

/// Configuration for the optional AI explanation step.
///
/// The key is never written to source code. It is injected at build/run time
/// with `--dart-define`, and the easiest way to supply it locally is to copy
/// `env.ai.example.ps1` to the git-ignored `env.ai.ps1` and fill in the key
/// there:
///
/// ```
/// flutter run --dart-define=AI_API_KEY=... --dart-define=AI_MODEL=gemini-3.8-flash
/// ```
///
/// A build made with a key carries that key inside the binary, so such a
/// build must never be distributed.
class AiConfig {
  const AiConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  const AiConfig.empty()
      : apiKey = '',
        baseUrl = 'https://api.openai.com/v1',
        model = 'gpt-4o-mini';

  final String apiKey;
  final String baseUrl;
  final String model;

  /// Reads configuration passed with `--dart-define`.
  factory AiConfig.fromEnvironment() => const AiConfig(
        apiKey: String.fromEnvironment('AI_API_KEY'),
        baseUrl: String.fromEnvironment(
          'AI_BASE_URL',
          defaultValue: 'https://api.openai.com/v1',
        ),
        model: String.fromEnvironment(
          'AI_MODEL',
          defaultValue: 'gpt-4o-mini',
        ),
      );

  bool get enabled => apiKey.trim().isNotEmpty;
}

/// Plain-language explanation returned by the model.
class AiExplanation {
  const AiExplanation({required this.summary, this.observations = const []});

  final String summary;
  final List<String> observations;
}

/// Optional AI step: it never sets the risk level, it only explains the
/// signals that the deterministic rules already found.
///
/// It has two ways to reach Gemini - an OpenAI-compatible primary and a
/// native Google AI Studio fallback - but they are two doors into the same
/// step, not two independent judges: whichever runs, the wording it produces
/// is checked against the rules and can only be *described*, never scored
/// with. See [explain].
class AiExplainer {
  AiExplainer(this.config, {http.Client? client}) : _overrideClient = client;

  factory AiExplainer.fromEnvironment() =>
      AiExplainer(AiConfig.fromEnvironment());

  final AiConfig config;
  final http.Client? _overrideClient;
  http.Client? _ownClient;

  /// Only created when AI is actually used, so no socket is opened in builds
  /// without an AI configuration.
  http.Client get _client {
    final override = _overrideClient;
    if (override != null) return override;
    return _ownClient ??= http.Client();
  }

  static const Duration timeout = Duration(seconds: 20);

  /// Returns `null` only when AI is not configured, so no request is made at
  /// all. Any actual failure - timeout, network, rate limit, error status or
  /// an unreadable body - is thrown as an [AiException] carrying a fixed
  /// [AiFailure] category, so the caller can fall back to the rules *and*
  /// still tell the developer why. Nothing thrown here contains the key.
  ///
  /// Two attempts are made, in strict order:
  ///
  /// 1. **Primary** - the OpenAI-compatible `POST {baseUrl}/chat/completions`
  ///    that `env.ai.ps1` configures. This is the path that always runs.
  /// 2. **Fallback** - Google AI Studio's native
  ///    `POST {root}/models/{model}:generateContent`, tried only after the
  ///    primary failed with a timeout, a transport error, an error status or
  ///    an unreadable body.
  ///
  /// The fallback is deliberately narrow: a **429 never reaches it** (the
  /// quota belongs to the credential, so the same key would be rejected
  /// again), an **unclassified exception never reaches it** (retrying an
  /// error nobody understood is a guess), and **nothing runs at all** when
  /// AI is not configured. When both attempts fail the *primary* failure is
  /// reported, because that is the configured path and it is the reason the
  /// fallback was tried. Either way the caller still returns the untouched
  /// rule-based result.
  Future<AiExplanation?> explain({
    required String input,
    required InputKind kind,
    required RiskLevel riskLevel,
    required List<Indicator> indicators,
  }) async {
    if (!config.enabled) return null;

    // Both endpoints are asked for exactly the same thing, so a successful
    // fallback cannot change what the AI is allowed to say.
    final systemPrompt = _systemPrompt(kind);
    final userPrompt = jsonEncode({
      'risk_level': riskLevel.name.toUpperCase(),
      'input': input,
      'signals': [
        for (final i in indicators)
          {
            'id': i.id,
            'severity': i.severity.name,
            'title': i.title,
            'why': i.explanation,
          },
      ],
    });

    try {
      return await _explainPrimary(systemPrompt, userPrompt);
    } on AiException catch (primaryError) {
      if (!_shouldFallBack(primaryError) || _nativeEndpoint() == null) {
        rethrow;
      }
      try {
        return await _explainNative(systemPrompt, userPrompt);
      } on AiException {
        // Both attempts failed. Report the primary failure: it is the
        // configured path, and it explains why the fallback ran at all.
        throw primaryError;
      }
    }
  }

  /// Whether a failure of the primary path justifies a second request.
  ///
  /// * `timeout` / `network` / `apiError` / `badResponse` - yes. The native
  ///   surface is a different code path and may still answer.
  /// * `rateLimited` - **no.** Retrying a 429 with the same credential is a
  ///   wasted request that is certain to fail again.
  /// * `unknown` - **no.** Retrying an error nobody could classify is a
  ///   guess, and guessing costs the user another wait.
  static bool _shouldFallBack(AiException e) {
    switch (e.failure) {
      case AiFailure.timeout:
      case AiFailure.network:
      case AiFailure.apiError:
      case AiFailure.badResponse:
        return true;
      case AiFailure.rateLimited:
      case AiFailure.unknown:
        return false;
    }
  }

  /// The native Gemini endpoint, or `null` when this configuration is not a
  /// Google endpoint.
  ///
  /// Deriving it from the configured base URL keeps one source of truth and
  /// guarantees a non-Google provider is never sent a Gemini-shaped request.
  Uri? _nativeEndpoint() {
    final root = _nativeRoot(config.baseUrl);
    if (root == null) return null;
    return Uri.parse('$root/models/${config.model}:generateContent');
  }

  static String? _nativeRoot(String baseUrl) {
    final normalised = _normaliseBaseUrl(baseUrl);
    final uri = Uri.tryParse(normalised);
    if (uri == null) return null;
    // Google's Gemini API only. A wrong host means "no native path here".
    if (uri.host != 'generativelanguage.googleapis.com') return null;
    const openAiSuffix = '/openai';
    if (normalised.endsWith(openAiSuffix)) {
      return normalised.substring(0, normalised.length - openAiSuffix.length);
    }
    return normalised;
  }

  /// The instruction both endpoints share.
  static String _systemPrompt(InputKind kind) =>
      'You explain to an everyday user why a ${kind.name} looks '
      'suspicious. Be concrete, calm and honest. Never invent facts, '
      'never claim certainty, and never say the item definitely is or '
      'is not a scam. Reply with JSON only in this exact shape: '
      '{"summary": "2-3 sentences a non-technical person can follow", '
      '"observations": ["short point", "short point"]} '
      'with 1 to 3 observations.';

  /// Primary path: the OpenAI-compatible Gemini surface.
  Future<AiExplanation> _explainPrimary(
    String systemPrompt,
    String userPrompt,
  ) async {
    final payload = {
      'model': config.model,
      'temperature': 0.2,
      // Thinking models (Gemini 3.x) count their internal reasoning towards
      // the same output budget. At 400 a thinking model could spend the whole
      // budget on reasoning and return an empty answer, which the parser
      // treats as a failed reply. The answer stays short in practice anyway:
      // the prompt asks for 2-3 sentences and at most 3 observations.
      'max_tokens': 1024,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    };

    final response = await _postJson(
      Uri.parse('${_normaliseBaseUrl(config.baseUrl)}/chat/completions'),
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      jsonEncode(payload),
    );

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const AiException(AiFailure.badResponse, 'body was not valid JSON');
    }
    if (decoded is! Map) {
      throw const AiException(
          AiFailure.badResponse, 'body was not a JSON object');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiException(AiFailure.badResponse, 'missing choices[]');
    }
    final firstChoice = choices.first;
    final message = firstChoice is Map ? firstChoice['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AiException(AiFailure.badResponse, 'missing assistant text');
    }

    final explanation = _parse(content.trim());
    if (explanation == null) {
      throw const AiException(
          AiFailure.badResponse, 'unusable assistant text');
    }
    return explanation;
  }

  /// Fallback path: Google AI Studio's native Gemini `generateContent`.
  ///
  /// Same credential and same model as the primary, but a different endpoint
  /// with a different request and response shape, so a failure specific to
  /// the OpenAI-compatible surface does not take the wording step down with
  /// it. It is never reached when the primary succeeded, and never reached
  /// for a 429 - see [_shouldFallBack].
  Future<AiExplanation> _explainNative(
    String systemPrompt,
    String userPrompt,
  ) async {
    final response = await _postJson(
      _nativeEndpoint()!,
      {
        'Content-Type': 'application/json',
        // The key travels in a header, never in the query string, so it can
        // never end up inside a URL that a transport error might report.
        'x-goog-api-key': config.apiKey,
      },
      jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt}
            ],
          },
        ],
        'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 1024},
      }),
    );

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const AiException(AiFailure.badResponse, 'body was not valid JSON');
    }
    if (decoded is! Map) {
      throw const AiException(
          AiFailure.badResponse, 'body was not a JSON object');
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiException(AiFailure.badResponse, 'missing candidates[]');
    }
    final first = candidates.first;
    final content = first is Map ? first['content'] : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty) {
      throw const AiException(
          AiFailure.badResponse, 'missing content.parts[]');
    }
    final texts = <String>[];
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        final text = (part['text'] as String).trim();
        if (text.isNotEmpty) texts.add(text);
      }
    }
    if (texts.isEmpty) {
      throw const AiException(AiFailure.badResponse, 'missing assistant text');
    }

    final explanation = _parse(texts.join('\n'));
    if (explanation == null) {
      throw const AiException(
          AiFailure.badResponse, 'unusable assistant text');
    }
    return explanation;
  }

  /// Posts [body] to [endpoint] and turns every transport problem into an
  /// [AiException]. Shared by both paths so their failure handling cannot
  /// drift apart.
  ///
  /// The credential only ever appears in a header - never in the URL - and
  /// the response body is never forwarded: the caller receives a status code
  /// or one of the fixed literals below, nothing else.
  Future<http.Response> _postJson(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(endpoint, headers: headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiFailure.timeout, 'no reply within the timeout');
    } on http.ClientException catch (e) {
      // Transport level failure. The key travels in a header, never in the
      // URL, so a client message cannot leak it.
      throw AiException(AiFailure.network, e.message);
    } catch (e) {
      // Not a recognised transport error, so do not *claim* it is a network
      // problem - report the type only and let it be classified as unknown.
      // The type is used instead of the message because an arbitrary message
      // could contain anything.
      throw AiException(AiFailure.unknown, e.runtimeType.toString());
    }

    if (response.statusCode != 200) {
      // 429 is reported separately so a developer can tell a quota problem
      // from a genuine outage. The body is deliberately not forwarded.
      throw AiException(
        response.statusCode == 429
            ? AiFailure.rateLimited
            : AiFailure.apiError,
        'HTTP ${response.statusCode}',
      );
    }
    return response;
  }

  static String _normaliseBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Accepts strict JSON, and also a model that answered in plain prose.
  static AiExplanation? _parse(String content) {
    var text = content;
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        final summary = decoded['summary'];
        if (summary is String && summary.trim().isNotEmpty) {
          final observations = decoded['observations'];
          return AiExplanation(
            summary: summary.trim(),
            observations: observations is List
                ? observations
                    .whereType<String>()
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .take(3)
                    .toList()
                : const [],
          );
        }
        // Valid JSON, but not the shape we asked for.
        return null;
      }
      if (decoded is String && decoded.trim().length >= 20) {
        return AiExplanation(summary: decoded.trim());
      }
      return null;
    } catch (_) {
      // Not JSON - fall through and use the raw text.
    }

    final fallback = text.replaceAll('"', '').trim();
    if (fallback.isEmpty ||
        fallback.length < 20 ||
        fallback.startsWith('{') ||
        fallback.startsWith('[')) {
      return null;
    }
    return AiExplanation(
      summary: fallback.substring(0, fallback.length > 400 ? 400 : fallback.length),
    );
  }
}
