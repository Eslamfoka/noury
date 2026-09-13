import 'ai_provider.dart';

/// Everything needed to reach one AI service: which, where, as whom, which
/// model.
///
/// A value, assembled from the settings row and the keystore at the moment of
/// a call. Nothing in it is cached between calls, so a key cleared in
/// settings is gone from the next request.
class AiConnection {
  const AiConnection({
    required this.provider,
    required this.apiKey,
    String? model,
    String? baseUrl,
  })  : _model = model,
        _baseUrl = baseUrl;

  // ignore_for_file: prefer_initializing_formals

  final AiProvider provider;
  final String apiKey;
  final String? _model;
  final String? _baseUrl;

  /// The model to call: the user's choice, or the provider's default.
  String get model {
    final chosen = _model?.trim() ?? '';
    return chosen.isEmpty ? provider.defaultModel : chosen;
  }

  /// Where to send it: the user's URL, or the provider's own host.
  ///
  /// Trailing slashes are dropped so the paths below can be appended plainly.
  String get baseUrl {
    final chosen = _baseUrl?.trim() ?? '';
    final url = chosen.isEmpty ? provider.defaultBaseUrl : chosen;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  bool get hasKey => apiKey.trim().isNotEmpty;
  bool get hasBaseUrl => baseUrl.isNotEmpty;
}

/// One model a service reports it can run.
class AiModel {
  const AiModel({required this.id, this.displayName});

  final String id;
  final String? displayName;

  String get label => displayName == null || displayName == id
      ? id
      : '$displayName — $id';
}

/// Why a call did not produce an answer, in words the user can read.
///
/// Nothing here is an exception. The client returns one of these rather than
/// throwing, because the UI has to say something either way and "an error
/// occurred" is not it.
enum AiFailureKind {
  /// No key stored, or the field was empty.
  noKey,

  /// The compatible provider with no URL to send to.
  noBaseUrl,

  /// 401 or 403: the service does not accept the key.
  badKey,

  /// 429: too many requests, or the account's balance.
  rateLimited,

  /// Could not reach the host at all — no internet, DNS, timeout.
  network,

  /// 5xx, or a 200 whose body was not what the service documents.
  service,

  /// The service answered, but the reply had no text in it.
  emptyReply,
}

class AiFailure {
  const AiFailure(this.kind, {this.detail});

  final AiFailureKind kind;

  /// Whatever the service said, trimmed — for the status row's small print
  /// and for a bug report. Never the whole body.
  final String? detail;

  /// What the settings row says. Plain and in Nouri's register: it names
  /// the thing that happened and what to do, and it never blames the user
  /// for a key that did not work.
  String get message => switch (kind) {
        AiFailureKind.noKey => 'حطّ المفتاح الأول.',
        AiFailureKind.noBaseUrl => 'حطّ عنوان الخدمة الأول.',
        AiFailureKind.badKey => 'الخدمة مش قابلة المفتاح ده. اتأكد إنه '
            'متنسخ كله ومن نفس الخدمة اللي مختارها.',
        AiFailureKind.rateLimited =>
          'الخدمة بتقول كتير في وقت قصير، أو الرصيد خلص. جرّب بعد شوية.',
        AiFailureKind.network =>
          'مش قادر أوصل للخدمة دلوقتي. اتأكد من الإنترنت وجرّب تاني.',
        AiFailureKind.service => 'الخدمة ردّت بخطأ من عندها. جرّب بعد شوية.',
        AiFailureKind.emptyReply => 'الخدمة ردّت بس من غير كلام.',
      };

  @override
  String toString() => 'AiFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Either a value or a failure. Never both, never neither.
class AiResult<T> {
  const AiResult.ok(T value)
      : value = value,
        failure = null;

  const AiResult.failed(AiFailure failure)
      : value = null,
        failure = failure;

  final T? value;
  final AiFailure? failure;

  bool get ok => failure == null;
}

/// What Nouri asks of an AI service.
///
/// Two calls, and only two. [listModels] is what CONNECT presses: it proves
/// the key without spending a token, and brings back the names to pick from.
/// [complete] is the one that costs money and is pressed on purpose — see
/// `build_plan_button.dart` for the rule that nothing else may call it.
abstract interface class AiClient {
  Future<AiResult<List<AiModel>>> listModels(AiConnection connection);

  Future<AiResult<String>> complete(
    AiConnection connection, {
    required String system,
    required String user,
    int maxTokens = 4096,
  });
}
