//**********************************************
// Manual Maribor Stop Picker Fallback Card    *
//**********************************************

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m_mobilnost/core/accessibility/favorites_provider.dart';
import 'package:m_mobilnost/core/accessibility/semantics_helpers.dart';
import 'package:m_mobilnost/core/theme/colors.dart';
import 'package:m_mobilnost/core/widgets/big_button.dart';
import 'package:m_mobilnost/data/models/bus_stop.dart';

/// Calm non-blocking explanation card with manual Maribor stop selection
/// when GPS permissions are denied or manual location mode is selected.
class ManualLocationFallbackCard extends ConsumerWidget {
  /// Creates a [ManualLocationFallbackCard] allowing manual stop picking.
  const ManualLocationFallbackCard({
    super.key,
    required this.stops,
    this.selectedStop,
    this.onManualStopChanged,
  });

  /// Available Maribor stops to choose from.
  final List<BusStop> stops;

  /// Currently selected manual reference stop.
  final BusStop? selectedStop;

  /// Optional callback invoked after [favoritesProvider] updates the manual stop.
  final ValueChanged<BusStop>? onManualStopChanged;

  Future<void> _openStopPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final picked = await showModalBottomSheet<BusStop>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ManualStopPickerSheet(
        stops: stops,
        selectedStopId: selectedStop?.id,
      ),
    );
    if (picked == null) return;
    await ref.read(favoritesProvider.notifier).setManualStop(picked.id);
    onManualStopChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    return Card(
      color: statusColors.infoBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColors.infoFg,
          width: statusColors.highContrastBorders ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_searching_rounded,
                  color: statusColors.infoFg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mapLocationDeniedTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: statusColors.infoFg,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.mapLocationDeniedBody,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: statusColors.infoFg,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BigButton(
              icon: Icons.edit_location_alt_outlined,
              label: selectedStop != null
                  ? '${l10n.mapSelectManualStop}: ${selectedStop!.name}'
                  : l10n.mapSelectManualStop,
              variant: BigButtonVariant.outlined,
              expanded: true,
              onPressed:
                  stops.isEmpty ? null : () => _openStopPicker(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualStopPickerSheet extends StatefulWidget {
  const _ManualStopPickerSheet({
    required this.stops,
    this.selectedStopId,
  });

  final List<BusStop> stops;
  final String? selectedStopId;

  @override
  State<_ManualStopPickerSheet> createState() => _ManualStopPickerSheetState();
}

class _ManualStopPickerSheetState extends State<_ManualStopPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmed = _query.trim().toLowerCase();
    final filtered = trimmed.isEmpty
        ? widget.stops
        : widget.stops
            .where((s) => s.name.toLowerCase().contains(trimmed))
            .toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.mapSelectManualStop,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.a11yCloseButton,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: l10n.commonClose,
                      constraints:
                          const BoxConstraints(minWidth: 56, minHeight: 56),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: l10n.mapSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(l10n.mapNoNearbyStops))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final stop = filtered[index];
                          final isSelected = stop.id == widget.selectedStopId;
                          return ListTile(
                            minTileHeight: 56,
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.place_outlined,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(stop.name),
                            subtitle: stop.platform != null
                                ? Text(l10n.stopPlatform(stop.platform!))
                                : null,
                            onTap: () => Navigator.of(context).pop(stop),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
