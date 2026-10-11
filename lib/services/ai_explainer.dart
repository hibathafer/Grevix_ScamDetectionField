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
  Future<AiExplanation?> explain({
    required String input,
    required InputKind kind,
    required RiskLevel riskLevel,
    required List<Indicator> indicators,
  }) async {
    if (!config.enabled) return null;

    final endpoint = Uri.parse(
      '${_normaliseBaseUrl(config.baseUrl)}/chat/completions',
    );

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
        {
          'role': 'system',
          'content':
              'You explain to an everyday user why a ${kind.name} looks '
              'suspicious. Be concrete, calm and honest. Never invent facts, '
              'never claim certainty, and never say the item definitely is or '
              'is not a scam. Reply with JSON only in this exact shape: '
              '{"summary": "2-3 sentences a non-technical person can follow", '
              '"observations": ["short point", "short point"]} '
              'with 1 to 3 observations.',
        },
        {
          'role': 'user',
          'content': jsonEncode({
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
          }),
        },
      ],
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode(payload),
          )
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
