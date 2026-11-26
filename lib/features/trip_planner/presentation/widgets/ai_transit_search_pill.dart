//**********************************************
// Hands-Free AI Voice & Text Search Pill      *
//**********************************************

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/accessibility/voice_input.dart';
import '../../../../core/network/gemini_transit_service.dart';
import '../../../../core/theme/colors.dart';
import '../../domain/route_planner.dart';

//**********************************************
// Quick destination preset model              *
//**********************************************

class _QuickDestinationChipData {
  const _QuickDestinationChipData({
    required this.labelSl,
    required this.labelEn,
    required this.promptSl,
    required this.promptEn,
    required this.icon,
  });

  final String labelSl;
  final String labelEn;
  final String promptSl;
  final String promptEn;
  final IconData icon;
}

const List<_QuickDestinationChipData> _kQuickDestinations = [
  _QuickDestinationChipData(
    labelSl: 'Europark',
    labelEn: 'Europark',
    promptSl: 'Pelji me v Europark',
    promptEn: 'Take me to Europark Maribor',
    icon: Icons.shopping_bag_outlined,
  ),
  _QuickDestinationChipData(
    labelSl: 'UKC Maribor',
    labelEn: 'UKC Maribor',
    promptSl: 'Pelji me v UKC Maribor',
    promptEn: 'Take me to UKC Maribor hospital',
    icon: Icons.local_hospital_outlined,
  ),
  _QuickDestinationChipData(
    labelSl: 'Železniška',
    labelEn: 'Train Station',
    promptSl: 'Pelji me na Železniško postajo Maribor',
    promptEn: 'Take me to Maribor train station',
    icon: Icons.train_outlined,
  ),
  _QuickDestinationChipData(
    labelSl: 'Glavni trg',
    labelEn: 'Glavni trg',
    promptSl: 'Pelji me na Glavni trg',
    promptEn: 'Take me to Glavni trg',
    icon: Icons.location_city_outlined,
  ),
  _QuickDestinationChipData(
    labelSl: 'Pohorje',
    labelEn: 'Pohorje',
    promptSl: 'Pelji me do Pohorske vzpenjače',
    promptEn: 'Take me to Pohorje gondola',
    icon: Icons.landscape_outlined,
  ),
];

//**********************************************
// AiTransitSearchPill widget                  *
//**********************************************

/// Prominent hands-free AI Voice + Text search pill powered by Gemini 2.5 Flash
/// with Grounding with Google Maps + Live GPS, plus 1-tap destination chips
/// and a clean switch to Manual Searchable Pickers.
class AiTransitSearchPill extends ConsumerStatefulWidget {
  /// Creates an [AiTransitSearchPill].
  const AiTransitSearchPill({
    super.key,
    required this.userLatLng,
    required this.onResult,
    required this.onLoadingChanged,
    required this.onError,
    required this.onToggleManualMode,
    this.isManualMode = false,
  });

  /// Live GPS coordinate (nullable if denied).
  final LatLng? userLatLng;

  /// Invoked when Gemini + Google Routes compute candidate transit options.
  final ValueChanged<AiTransitSearchResult> onResult;

  /// Notifies parent when AI + Routes calculation starts/finishes.
  final ValueChanged<bool> onLoadingChanged;

  /// Friendly error callback if Gemini or Routes fails.
  final ValueChanged<String> onError;

  /// Switches between AI Search mode and Manual Searchable Station Pickers.
  final VoidCallback onToggleManualMode;

  /// Whether Manual Mode is currently visible.
  final bool isManualMode;

  @override
  ConsumerState<AiTransitSearchPill> createState() =>
      _AiTransitSearchPillState();
}

class _AiTransitSearchPillState extends ConsumerState<AiTransitSearchPill> {
  final TextEditingController _textController = TextEditingController();
  final ValueNotifier<bool> _listening = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _aiReply = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _textController.dispose();
    _listening.dispose();
    _busy.dispose();
    _aiReply.dispose();
    super.dispose();
  }

  Future<void> _submitQuery(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;

    final settings = ref.read(a11ySettingsProvider);
    final gemini = ref.read(geminiTransitServiceProvider);
    final planner = ref.read(routePlannerProvider);

    _busy.value = true;
    widget.onLoadingChanged(true);

    try {
      final result = await gemini.resolveAndPlan(
        userQuery: query,
        planner: planner,
        userLatLng: widget.userLatLng,
        profileWheelchairOnly: settings.wheelchairAccessibleOnly,
        localeCode: settings.localeCode,
      );
      if (!mounted) return;
      _aiReply.value = result.resolvedTrip.shortReply;
      // Sync global wheelchair toggle automatically if user spoke/asked for it
      if (result.resolvedTrip.wheelchairOnly &&
          !settings.wheelchairAccessibleOnly) {
        await ref
            .read(a11ySettingsProvider.notifier)
            .setWheelchairAccessibleOnly(true);
      }
      widget.onResult(result);
    } catch (e) {
      if (!mounted) return;
      final isSl = settings.localeCode == 'sl';
      widget.onError(
        isSl
            ? 'AI načrtovalec trenutno ni dosegljiv. Poskusite ročni izbor postaj.'
            : 'AI route assistant is temporarily unavailable. Try manual stop search.',
      );
    } finally {
      _busy.value = false;
      widget.onLoadingChanged(false);
    }
  }

  Future<void> _toggleVoice() async {
    final settings = ref.read(a11ySettingsProvider);
    final voice = ref.read(voiceInputProvider);
    if (_listening.value) {
      await voice.stop();
      _listening.value = false;
      return;
    }

    _listening.value = true;
    final started = await voice.startListening(
      localeCode: settings.localeCode,
      onResult: (text, isFinal) {
        if (!mounted) return;
        _textController.text = text;
        if (isFinal && text.trim().isNotEmpty) {
          _listening.value = false;
          _submitQuery(text);
        }
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status != 'listening') {
          _listening.value = false;
        }
      },
      onError: (_) {
        _listening.value = false;
      },
    );

    if (!started && mounted) {
      _listening.value = false;
      final isSl = settings.localeCode == 'sl';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSl
                ? 'Mikrofon v tem brskalniku ni podprt — vpišite cilj ali izberite hiter gumb.'
                : 'Microphone unavailable in this browser — type your destination or tap a quick chip.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = ref.watch(
      a11ySettingsProvider.select((s) => s.localeCode),
    );
    final isSl = locale == 'sl';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main floating search pill with Microphone & Manual mode switcher
        Material(
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          color: scheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Icon(
                  Icons.auto_awesome_rounded,
                  color: MarpromColors.marpromRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submitQuery,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      hintText: isSl
                          ? 'Kam želite? (npr. "Pelji me v Europark")'
                          : 'Where to? (e.g. "Take me to Europark")',
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _busy,
                  builder: (_, isBusy, _) {
                    if (isBusy) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      );
                    }
                    return IconButton(
                      tooltip: isSl ? 'Poišči pot z AI' : 'Search route with AI',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.primary,
                      ),
                      onPressed: () => _submitQuery(_textController.text),
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _listening,
                  builder: (_, isListening, _) {
                    return IconButton.filledTonal(
                      tooltip: isSl ? 'Glasovni ukaz' : 'Voice search',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isListening
                            ? MarpromColors.marpromRed
                            : scheme.secondaryContainer,
                        foregroundColor: isListening
                            ? Colors.white
                            : scheme.onSecondaryContainer,
                      ),
                      icon: Icon(
                        isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      ),
                      onPressed: _toggleVoice,
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: widget.isManualMode
                      ? (isSl ? 'Skrij ročni izbor' : 'Hide manual pickers')
                      : (isSl ? 'Ročni izbor postaj' : 'Manual stop pickers'),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: Icon(
                    widget.isManualMode
                        ? Icons.expand_less_rounded
                        : Icons.tune_rounded,
                    color: widget.isManualMode
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  onPressed: widget.onToggleManualMode,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 1-tap quick destination chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chip in _kQuickDestinations) ...[
                ActionChip(
                  avatar: Icon(chip.icon, size: 16, color: scheme.primary),
                  label: Text(
                    isSl ? chip.labelSl : chip.labelEn,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: scheme.surface.withValues(alpha: 0.94),
                  side: BorderSide(color: scheme.outlineVariant),
                  onPressed: () {
                    final prompt = isSl ? chip.promptSl : chip.promptEn;
                    _textController.text = prompt;
                    _submitQuery(prompt);
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        // Concise 1-sentence AI reply bubble
        ValueListenableBuilder<String?>(
          valueListenable: _aiReply,
          builder: (_, reply, _) {
            if (reply == null || reply.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Material(
                color: scheme.primaryContainer.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.smart_toy_outlined,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reply,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      IconButton(
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _aiReply.value = null,
                        icon: Icon(
                          Icons.close_rounded,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
