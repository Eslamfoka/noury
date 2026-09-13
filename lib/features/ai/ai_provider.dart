/// The AI services Nouri can talk to.
///
/// The user's words on 13 September 2026: «مش لازم كلود يحطه في الخانة ويدوس
/// عادي ai بس اي» — he puts *a* key in the field and presses CONNECT, and it
/// does not have to be Claude. So the service is a choice, and each one here
/// knows the three things that differ between them: where to send the
/// request, how to say the key, and what the reply looks like. Everything
/// else in the app — the prompt, the parser, the plan — is the same whichever
/// he picks.
///
/// Four, not "any". Three named services, and a fourth for everything that
/// speaks the OpenAI chat shape from a URL he types himself — Groq,
/// OpenRouter, DeepSeek, a local Ollama, and whatever is invented next.
enum AiProvider {
  /// Claude, from Anthropic. The default, because the brief and every prompt
  /// in the app were written for it.
  anthropic(
    label: 'Claude',
    keyHint: 'مفتاح من console.anthropic.com',
    defaultBaseUrl: 'https://api.anthropic.com',
    // Haiku, by the brief's own rule — §7: «Use a cheap model (e.g. Claude
    // Haiku) for routine work» — and by the 10 September decision: «Haiku
    // for the build». The stronger models are one tap away in the list
    // CONNECT brings back.
    defaultModel: 'claude-haiku-4-5',
  ),

  openai(
    label: 'OpenAI',
    keyHint: 'مفتاح من platform.openai.com',
    defaultBaseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
  ),

  gemini(
    label: 'Gemini',
    keyHint: 'مفتاح من aistudio.google.com',
    defaultBaseUrl: 'https://generativelanguage.googleapis.com',
    defaultModel: 'gemini-2.5-flash',
  ),

  /// Anything that speaks OpenAI's `/chat/completions`. The user supplies the
  /// base URL; the key goes in the same `Authorization: Bearer` header.
  compatible(
    label: 'متوافق مع OpenAI',
    keyHint: 'أي خدمة بتشتغل بنفس شكل OpenAI — Groq، OpenRouter، DeepSeek…',
    defaultBaseUrl: '',
    defaultModel: '',
  ),
  ;

  const AiProvider({
    required this.label,
    required this.keyHint,
    required this.defaultBaseUrl,
    required this.defaultModel,
  });

  final String label;

  /// One line under the key field: where a key for this service comes from.
  final String keyHint;

  /// Where requests go unless the user overrides it. Empty for
  /// [compatible], which has no default and must be typed.
  final String defaultBaseUrl;

  /// The model used when the user has not chosen one. Empty for
  /// [compatible], where the service decides what exists.
  final String defaultModel;

  /// Whether the user has to supply the URL himself.
  bool get needsBaseUrl => this == AiProvider.compatible;

  /// The stored name → the provider, defaulting to Claude for anything the
  /// row might hold from a build that did not know a value.
  static AiProvider fromName(String? name) => AiProvider.values.firstWhere(
        (p) => p.name == name,
        orElse: () => AiProvider.anthropic,
      );
}
