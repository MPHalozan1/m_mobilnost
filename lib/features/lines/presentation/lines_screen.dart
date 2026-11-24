// Searchable list of Maribor city bus lines with badges, directions, and favorites.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m_mobilnost/core/accessibility/a11y_settings.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/accessibility/haptic_cues.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/layout/responsive_builder.dart';
import 'package:m_mobilnost/core/widgets/offline_banner.dart';
import 'package:m_mobilnost/core/widgets/simulated_data_badge.dart';
import 'package:m_mobilnost/core/widgets/state_views.dart';
import 'package:m_mobilnost/core/widgets/ui_kit.dart';
import 'package:m_mobilnost/data/models/bus_line.dart';

import '../data/transit_providers.dart';
import 'widgets/line_badge.dart';

/// Displays all searchable Marprom bus lines with favorite toggles.
class LinesScreen extends ConsumerStatefulWidget {
  /// Creates a [LinesScreen].
  const LinesScreen({super.key});

  @override
  ConsumerState<LinesScreen> createState() => _LinesScreenState();
}

class _LinesScreenState extends ConsumerState<LinesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BusLine> _filterLines(List<BusLine> lines, Set<String> favoriteIds) {
    final trimmed = _query.trim().toLowerCase();
    return lines.where((line) {
      if (_favoritesOnly && !favoriteIds.contains(line.id)) {
        return false;
      }
      if (trimmed.isEmpty) return true;
      if (line.code.toLowerCase().contains(trimmed)) return true;
      if (line.name.toLowerCase().contains(trimmed)) return true;
      return line.directions.any(
        (d) => d.name.toLowerCase().contains(trimmed),
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final linesAsync = ref.watch(allLinesProvider);
    final favorites = ref.watch(favoritesProvider);
    final hapticEnabled = ref.watch(
      a11ySettingsProvider.select((s) => s.hapticAlertsEnabled),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.linesTitle),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: linesAsync.when(
              loading: () => const LoadingStateView(),
              error: (_, _) => ErrorStateView(
                onRetry: () => ref.invalidate(allLinesProvider),
              ),
              data: (lines) {
                final filtered = _filterLines(lines, favorites.lineIds);
                return ListView(
                  children: [
                    ResponsiveContentContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SimulatedDataBadge(),
                          const SizedBox(height: 12),
                          Semantics(
                            textField: true,
                            label: l10n.a11ySearchField,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: l10n.linesSearchHint,
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _query.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded),
                                        tooltip: l10n.commonClear,
                                        constraints: const BoxConstraints(
                                          minWidth: 56,
                                          minHeight: 56,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) => setState(() => _query = val),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _FilterTabButton(
                                label: l10n.commonAll,
                                icon: Icons.directions_bus_rounded,
                                selected: !_favoritesOnly,
                                onTap: () =>
                                    setState(() => _favoritesOnly = false),
                              ),
                              _FilterTabButton(
                                label: l10n.commonFavorites,
                                icon: Icons.star_rounded,
                                selected: _favoritesOnly,
                                onTap: () =>
                                    setState(() => _favoritesOnly = true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (filtered.isEmpty)
                            EmptyStateView(
                              icon: Icons.directions_bus_outlined,
                              title: l10n.commonEmpty,
                              actionLabel: _query.isNotEmpty || _favoritesOnly
                                  ? l10n.commonClear
                                  : null,
                              onAction: _query.isNotEmpty || _favoritesOnly
                                  ? () {
                                      _searchController.clear();
                                      setState(() {
                                        _query = '';
                                        _favoritesOnly = false;
                                      });
                                    }
                                  : null,
                            )
                          else
                            Column(
                              children: [
                                for (final line in filtered) ...[
                                  _LineSummaryCard(
                                    line: line,
                                    isFavorite:
                                        favorites.isLineFavorite(line.id),
                                    onTap: () => context.push(
                                      '/lines/${Uri.encodeComponent(line.id)}',
                                    ),
                                    onToggleFavorite: () {
                                      HapticCues.trigger(
                                        HapticCueType.tap,
                                        enabled: hapticEnabled,
                                      );
                                      ref
                                          .read(favoritesProvider.notifier)
                                          .toggleLine(line.id);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  const _FilterTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: selected
          ? FilledButton.tonalIcon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _LineSummaryCard extends StatelessWidget {
  const _LineSummaryCard({
    required this.line,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final BusLine line;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final primaryDirection =
        line.directions.isNotEmpty ? line.directions.first.name : '';

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LineBadge(
                          code: line.code,
                          color: line.color,
                          showLineWord: true,
                        ),
                        if (line.isLowFloorDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.accessible_rounded,
                                  size: 16,
                                  color: scheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    l10n.linesLowFloor,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: scheme.onSecondaryContainer,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      line.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (primaryDirection.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.linesDirectionLabel}: $primaryDirection',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                toggled: isFavorite,
                label:
                    '${l10n.a11yFavoriteToggle}: ${l10n.linesBadge(line.code)}',
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  tooltip: isFavorite
                      ? l10n.linesFavoriteRemove
                      : l10n.linesFavoriteAdd,
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    minHeight: 56,
                  ),
                  onPressed: onToggleFavorite,
                ),
              ),
            ],
          ),
    );
  }
}
