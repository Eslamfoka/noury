import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/format/arabic_numerals.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import 'ai_client.dart';
import 'ai_provider.dart';
import 'ai_providers.dart';

/// الذكاء الاصطناعي — the CONNECT part.
///
/// The user's request on 13 September 2026, in his words: «عايزك تبني الجزء
/// الخاص ب CONNECT ومش لازم كلود يحطه في الخانة ويدوس عادي ai بس اي». Pick a
/// service, paste a key, press CONNECT. That is the whole screen.
///
/// **CONNECT proves the key before keeping it.** It asks the service for its
/// model list — free, no tokens — and only a key the service accepted is
/// written to the keystore. So the status row can say «متصل» and mean it,
/// and a key that failed is never the one the app carries.
///
/// **The key is shown to no one, including this screen.** The field is
/// obscured, and once a key is stored the field is empty rather than filled
/// — a stored key is a fact, not a string to display. Leaving the field
/// empty and pressing CONNECT again uses the stored one, so changing only the
/// provider or the model does not mean pasting the key a second time.
class AiConnectionPanel extends ConsumerStatefulWidget {
  const AiConnectionPanel({super.key, required this.settings});

  final SettingsRow settings;

  @override
  ConsumerState<AiConnectionPanel> createState() => _AiConnectionPanelState();
}

class _AiConnectionPanelState extends ConsumerState<AiConnectionPanel> {
  late AiProvider _provider;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _url;

  bool _showKey = false;
  bool _busy = false;

  /// What the last press said. Null until a press; cleared by the next.
  String? _note;
  bool _noteIsGood = false;

  /// What the service listed at the last CONNECT, for «اختار الموديل».
  List<AiModel> _models = const [];

  @override
  void initState() {
    super.initState();
    _provider = AiProvider.fromName(widget.settings.aiProvider);
    _key = TextEditingController();
    _model = TextEditingController(text: widget.settings.aiModel);
    _url = TextEditingController(text: widget.settings.aiBaseUrl);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();

    // Everything off `ref` before the first await — the rule this project
    // keeps re-learning about widgets that go away mid-write.
    final controller = ref.read(aiConnectionControllerProvider);

    setState(() {
      _busy = true;
      _note = null;
    });

    final result = await controller.connect(
      provider: _provider,
      apiKey: _key.text,
      model: _model.text,
      baseUrl: _url.text,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _models = result.value!;
        _key.clear();
        _noteIsGood = true;
        _note = _models.isEmpty
            ? 'اتصل. الخدمة مرجّعتش أسماء موديلات — اكتب الموديل بنفسك.'
            : 'اتصل. المفتاح شغّال.';
      } else {
        _noteIsGood = false;
        final f = result.failure!;
        _note = f.detail == null ? f.message : '${f.message}\n${f.detail}';
      }
    });

    ref
      ..invalidate(aiStoredKeyProvider)
      ..invalidate(settingsProvider);
  }

  Future<void> _disconnect() async {
    final controller = ref.read(aiConnectionControllerProvider);
    await controller.disconnect();
    if (!mounted) return;
    setState(() {
      _models = const [];
      _note = 'اتمسح المفتاح.';
      _noteIsGood = true;
    });
    ref
      ..invalidate(aiStoredKeyProvider)
      ..invalidate(settingsProvider);
  }

  Future<void> _pickModel() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NouriColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text('الموديلات اللي الخدمة قالت عليها',
                  style: cairo(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final m in _models)
                ListTile(
                  key: ValueKey('ai-model-${m.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.label, style: cairo(size: 13)),
                  trailing: m.id == _model.text.trim()
                      ? const Icon(Icons.check,
                          size: 18, color: NouriColors.success)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(m.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;

    final controller = ref.read(aiConnectionControllerProvider);
    setState(() => _model.text = chosen);
    await controller.updateModel(chosen);
    ref.invalidate(settingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final storedKey = ref.watch(aiStoredKeyProvider).value;
    final hasKey = storedKey != null;
    final connectedAt = widget.settings.aiConnectedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusCard(
          connected: hasKey && connectedAt != null,
          provider: AiProvider.fromName(widget.settings.aiProvider),
          model: widget.settings.aiModel,
          connectedAt: connectedAt,
        ),
        const SizedBox(height: 16),

        _Label('الخدمة'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in AiProvider.values)
              _ProviderChip(
                key: ValueKey('ai-provider-${p.name}'),
                provider: p,
                selected: p == _provider,
                onTap: () => setState(() {
                  _provider = p;
                  _models = const [];
                  _note = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (_provider.needsBaseUrl) ...[
          _Label('عنوان الخدمة'),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('ai-url-field'),
            controller: _url,
            keyboardType: TextInputType.url,
            style: cairo(size: 13),
            textDirection: TextDirection.ltr,
            decoration: _decoration().copyWith(
              // No example URL here: no_network_test allows a host literal
              // in exactly one file, and the hint is not it.
              hintText: 'العنوان الأساسي — بينتهي غالبًا بـ /v1',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _provider.keyHint,
            style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
          ),
          const SizedBox(height: 14),
        ],

        _Label('المفتاح — API key'),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('ai-key-field'),
          controller: _key,
          obscureText: !_showKey,
          autocorrect: false,
          enableSuggestions: false,
          style: cairo(size: 13),
          textDirection: TextDirection.ltr,
          decoration: _decoration().copyWith(
            hintText: hasKey ? 'فيه مفتاح متخزّن — سيبها فاضية عشان تستخدمه' : 'الصق المفتاح هنا',
            suffixIcon: IconButton(
              key: const ValueKey('ai-key-toggle'),
              icon: Icon(
                _showKey ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: NouriColors.muted,
              ),
              onPressed: () => setState(() => _showKey = !_showKey),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (!_provider.needsBaseUrl)
          Text(
            _provider.keyHint,
            style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
          ),
        const SizedBox(height: 14),

        _Label('الموديل'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('ai-model-field'),
                controller: _model,
                autocorrect: false,
                style: cairo(size: 13),
                textDirection: TextDirection.ltr,
                decoration: _decoration().copyWith(
                  hintText: _provider.defaultModel.isEmpty
                      ? 'اسم الموديل'
                      : _provider.defaultModel,
                  hintTextDirection: TextDirection.ltr,
                ),
                // Saved on leaving the field, like the profile does.
                onTapOutside: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  ref.read(aiConnectionControllerProvider).updateModel(_model.text);
                },
                onSubmitted: (v) =>
                    ref.read(aiConnectionControllerProvider).updateModel(v),
              ),
            ),
            if (_models.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('ai-pick-model'),
                onPressed: _pickModel,
                child: Text('اختار', style: cairo(size: 12.5, color: NouriColors.gold)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _provider.defaultModel.isEmpty
              ? 'اكتب اسم الموديل زي ما الخدمة بتسمّيه.'
              : 'سيبه فاضي وهيستخدم ${_provider.defaultModel}. بعد ما توصّل، '
                  '«اختار» بيجيب لك اللستة من الخدمة نفسها.',
          style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
        ),
        const SizedBox(height: 18),

        Material(
          color: _busy ? NouriColors.surfaceActive : NouriColors.gold,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const ValueKey('ai-connect'),
            borderRadius: BorderRadius.circular(14),
            onTap: _busy ? null : _connect,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NouriColors.gold,
                      ),
                    )
                  else
                    const Icon(Icons.link, color: NouriColors.background, size: 19),
                  const SizedBox(width: 9),
                  Text(
                    _busy ? 'بجرّب المفتاح…' : 'CONNECT',
                    style: cairo(
                      size: 15,
                      weight: FontWeight.w700,
                      color: _busy ? NouriColors.muted : NouriColors.background,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_note != null) ...[
          const SizedBox(height: 10),
          Text(
            _note!,
            key: const ValueKey('ai-note'),
            style: cairo(
              size: 12,
              height: 1.7,
              // Attention orange, never red — a key that did not work is a
              // thing to fix, not a verdict.
              color: _noteIsGood ? NouriColors.success : NouriColors.attention,
            ),
          ),
        ],

        if (hasKey) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('ai-disconnect'),
              onPressed: _busy ? null : _disconnect,
              child: Text('امسح المفتاح',
                  style: cairo(size: 12.5, color: NouriColors.muted)),
            ),
          ),
        ],

        const Divider(color: NouriColors.border, height: 26),
        Text(
          'المفتاح متخزّن في الخزنة الآمنة بتاعة الجهاز، ومش بيتبعت لأي حد غير '
          'الخدمة اللي اخترتها. نوري مش بيكلّم الخدمة لوحده — بس لما تدوس '
          '«ابني خطتي»، وساعتها بيبعت ملخّص، مش بياناتك نفسها. الحساب '
          'والفلوس على المفتاح بتاعك انت.',
          style: cairo(size: 10.5, color: NouriColors.muted, height: 1.8),
        ),
      ],
    );
  }

  InputDecoration _decoration() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: NouriColors.background,
        hintStyle: cairo(size: 12, color: NouriColors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NouriColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NouriColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NouriColors.gold),
        ),
      );
}

/// «متصل» or «مش متصل», and with what.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.connected,
    required this.provider,
    required this.model,
    required this.connectedAt,
  });

  final bool connected;
  final AiProvider provider;
  final String model;
  final DateTime? connectedAt;

  @override
  Widget build(BuildContext context) {
    final modelName = model.trim().isEmpty ? provider.defaultModel : model.trim();

    return Container(
      key: const ValueKey('ai-status'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: connected ? NouriColors.surfaceActive : NouriColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: connected ? NouriColors.success : NouriColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle_outline : Icons.link_off,
            size: 20,
            color: connected ? NouriColors.success : NouriColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'متصل' : 'مش متصل',
                  style: cairo(
                    size: 14,
                    weight: FontWeight.w700,
                    color: connected ? NouriColors.success : NouriColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? '${provider.label} · $modelName'
                          '${connectedAt == null ? '' : ' · اتأكد ${formatClock(connectedAt!)}'}'
                      : 'حطّ مفتاح وادوس CONNECT، و«ابني خطتي» هيشتغل.',
                  style: cairo(size: 11, color: NouriColors.muted, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    super.key,
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final AiProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? NouriColors.gold : NouriColors.surfaceActive,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NouriColors.border),
          ),
          child: Text(
            provider.label,
            style: cairo(
              size: 12.5,
              weight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? NouriColors.background : NouriColors.text,
            ),
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: cairo(size: 13, weight: FontWeight.w600));
}
