//**********************************************
// Smart Diacritic-Insensitive Station Picker  *
//**********************************************

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/geo.dart';
import '../../../../data/models/bus_line.dart';
import '../../../../data/models/bus_stop.dart';
import '../../../../data/models/place.dart';
import '../../../../data/seed/seed_lines.dart';
import 'trip_endpoint.dart';

//**********************************************
// Slovenian Diacritic Normalization & Ranking *
//**********************************************

/// Normalizes Slovenian/Croatian/German diacritics (`č/ć→c`, `š→s`, `ž→z`, `đ→d`)
/// and lowercases text for instant diacritic-insensitive matching.
String normalizeSlovenianSearch(String input) {
  final lower = input.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    switch (rune) {
      case 0x010D: // č
      case 0x0107: // ć
        buf.write('c');
      case 0x0161: // š
        buf.write('s');
      case 0x017E: // ž
        buf.write('z');
      case 0x0111: // đ
        buf.write('d');
      case 0x00E4: // ä
        buf.write('a');
      case 0x00F6: // ö
        buf.write('o');
      case 0x00FC: // ü
        buf.write('u');
      default:
        buf.writeCharCode(rune);
    }
  }
  return buf.toString().trim();
}

/// Candidate item inside [SmartStationPairSelector].
@immutable
class StationSearchEntry {
  /// Creates a [StationSearchEntry] from a stop, place, or GPS location.
  const StationSearchEntry({
    required this.endpoint,
    required this.title,
    required this.subtitle,
    this.lineIds = const [],
    this.isStepFree = true,
    this.isCurrentLocation = false,
  });

  /// Underlying [TripEndpoint].
  final TripEndpoint endpoint;

  /// Display title.
  final String title;

  /// Address or line summary subtitle.
  final String subtitle;

  /// Serving Marprom line codes.
  final List<String> lineIds;

  /// Whether the stop is wheelchair-accessible.
  final bool isStepFree;

  /// True for the pinned "Moja lokacija / My Current Location" option.
  final bool isCurrentLocation;
}

/// Filters and ranks stops/places by:
/// 1) Prefix match (`startsWith`) first,
/// 2) Substring match (`contains`) second,
/// 3) Distance to [userPosition] (when known) or alphabetical order within tier.
List<StationSearchEntry> filterAndSortStationEntries({
  required String rawQuery,
  required List<BusStop> stops,
  required List<Place> places,
  LatLng? userPosition,
  bool allowCurrentLocation = false,
  String currentLocationLabel = 'Moja lokacija',
  bool accessibleOnly = false,
}) {
  final q = normalizeSlovenianSearch(rawQuery);
  final out = <({StationSearchEntry entry, int tier, double dist})>[];

  if (allowCurrentLocation &&
      (q.isEmpty ||
          normalizeSlovenianSearch(currentLocationLabel).contains(q) ||
          'gps'.contains(q))) {
    final pos = userPosition ?? GeoUtils.mariborCenter;
    out.add((
      entry: StationSearchEntry(
        endpoint: TripEndpoint.gps(pos),
        title: currentLocationLabel,
        subtitle: userPosition != null
            ? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'
            : 'Maribor GPS',
        isCurrentLocation: true,
      ),
      tier: -1,
      dist: 0.0,
    ));
  }

  for (final place in places) {
    final normName = normalizeSlovenianSearch(place.name);
    final normAddr = normalizeSlovenianSearch(place.address);
    var tier = 2;
    if (q.isEmpty) {
      tier = 1;
    } else if (normName.startsWith(q)) {
      tier = 0;
    } else if (normName.contains(q) || normAddr.contains(q)) {
      tier = 1;
    } else {
      continue;
    }
    final dist = userPosition != null
        ? GeoUtils.haversineMeters(userPosition, place.position)
        : 0.0;
    out.add((
      entry: StationSearchEntry(
        endpoint: TripEndpoint.place(place),
        title: place.name,
        subtitle: place.address,
      ),
      tier: tier,
      dist: dist,
    ));
  }

  for (final stop in stops) {
    if (accessibleOnly && !stop.isStepFree) continue;
    final normName = normalizeSlovenianSearch(stop.name);
    var tier = 2;
    if (q.isEmpty) {
      tier = 1;
    } else if (normName.startsWith(q)) {
      tier = 0;
    } else if (normName.contains(q)) {
      tier = 1;
    } else {
      continue;
    }
    final dist = userPosition != null
        ? GeoUtils.haversineMeters(userPosition, stop.position)
        : 0.0;
    out.add((
      entry: StationSearchEntry(
        endpoint: TripEndpoint.stop(stop),
        title: stop.name,
        subtitle: stop.lineIds.join(' • '),
        lineIds: stop.lineIds,
        isStepFree: stop.isStepFree,
      ),
      tier: tier,
      dist: dist,
    ));
  }

  out.sort((a, b) {
    final tierCmp = a.tier.compareTo(b.tier);
    if (tierCmp != 0) return tierCmp;
    if (userPosition != null) {
      final distCmp = a.dist.compareTo(b.dist);
      if (distCmp != 0) return distCmp;
    }
    return normalizeSlovenianSearch(a.entry.title)
        .compareTo(normalizeSlovenianSearch(b.entry.title));
  });

  return out.map((e) => e.entry).toList(growable: false);
}

//**********************************************
// SmartStationPairSelector widget             *
//**********************************************

/// Fast, diacritic-insensitive searchable Origin + Destination station selector
/// with animated 180° Swap button, Web inline dropdown + keyboard navigation,
/// and full-height search sheet on Mobile (`< 900px`).
class SmartStationPairSelector extends StatefulWidget {
  /// Creates a [SmartStationPairSelector].
  const SmartStationPairSelector({
    super.key,
    required this.stops,
    required this.places,
    required this.origin,
    required this.destination,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onSwap,
    this.userPosition,
    this.accessibleOnly = false,
    this.localeCode = 'sl',
    this.linesById,
  });

  /// All Marprom stops.
  final List<BusStop> stops;

  /// All Maribor landmarks/places.
  final List<Place> places;

  /// Current origin endpoint.
  final TripEndpoint? origin;

  /// Current destination endpoint.
  final TripEndpoint? destination;

  /// Called when user picks an origin.
  final ValueChanged<TripEndpoint> onOriginChanged;

  /// Called when user picks a destination.
  final ValueChanged<TripEndpoint> onDestinationChanged;

  /// Called when user taps the swap button.
  final VoidCallback onSwap;

  /// User GPS position used for proximity sorting & "My Current Location".
  final LatLng? userPosition;

  /// Filters out non-step-free stops when active.
  final bool accessibleOnly;

  /// Active locale code (`sl` or `en`).
  final String localeCode;

  /// Optional line lookup for line badge colors.
  final Map<String, BusLine>? linesById;

  @override
  State<SmartStationPairSelector> createState() =>
      _SmartStationPairSelectorState();
}

class _SmartStationPairSelectorState extends State<SmartStationPairSelector> {
  double _swapTurns = 0.0;

  @override
  Widget build(BuildContext context) {
    final isSl = widget.localeCode == 'sl';
    final linesLookup = widget.linesById ?? seedLinesById;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StationAutocompleteField(
                label: isSl ? 'Odhod' : 'Origin',
                hint: isSl
                    ? 'Moja lokacija ali postajališče...'
                    : 'My location or bus stop...',
                icon: Icons.my_location_rounded,
                value: widget.origin,
                stops: widget.stops,
                places: widget.places,
                userPosition: widget.userPosition,
                allowCurrentLocation: true,
                accessibleOnly: widget.accessibleOnly,
                localeCode: widget.localeCode,
                linesById: linesLookup,
                onSelected: widget.onOriginChanged,
              ),
              const SizedBox(height: 8),
              _StationAutocompleteField(
                label: isSl ? 'Cilj' : 'Destination',
                hint: isSl
                    ? 'Išči postajo (npr. zelez → Železniška)...'
                    : 'Search stop or landmark...',
                icon: Icons.place_rounded,
                value: widget.destination,
                stops: widget.stops,
                places: widget.places,
                userPosition: widget.userPosition,
                allowCurrentLocation: false,
                accessibleOnly: widget.accessibleOnly,
                localeCode: widget.localeCode,
                linesById: linesLookup,
                onSelected: widget.onDestinationChanged,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: isSl ? 'Zamenjaj odhod in cilj' : 'Swap origin and destination',
          child: IconButton.filledTonal(
            tooltip: isSl ? 'Zamenjaj' : 'Swap',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () {
              setState(() => _swapTurns += 0.5);
              widget.onSwap();
            },
            icon: AnimatedRotation(
              turns: _swapTurns,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: const Icon(Icons.swap_vert_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

//**********************************************
// Single searchable autocomplete field         *
//**********************************************

// Public single searchable stop/landmark autocomplete field shared across
// Route Planner and Profile & Settings (Home Station picker).
class SmartStationAutocompleteField extends StatelessWidget {
  // Creates a [SmartStationAutocompleteField].
  const SmartStationAutocompleteField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.stops,
    required this.places,
    required this.onSelected,
    this.userPosition,
    this.allowCurrentLocation = false,
    this.accessibleOnly = false,
    this.localeCode = 'sl',
    this.linesById,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TripEndpoint? value;
  final List<BusStop> stops;
  final List<Place> places;
  final LatLng? userPosition;
  final bool allowCurrentLocation;
  final bool accessibleOnly;
  final String localeCode;
  final Map<String, BusLine>? linesById;
  final ValueChanged<TripEndpoint> onSelected;

  @override
  Widget build(BuildContext context) {
    return _StationAutocompleteField(
      label: label,
      hint: hint,
      icon: icon,
      value: value,
      stops: stops,
      places: places,
      userPosition: userPosition,
      allowCurrentLocation: allowCurrentLocation,
      accessibleOnly: accessibleOnly,
      localeCode: localeCode,
      linesById: linesById ?? seedLinesById,
      onSelected: onSelected,
    );
  }
}

class _StationAutocompleteField extends StatefulWidget {
  const _StationAutocompleteField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.stops,
    required this.places,
    required this.userPosition,
    required this.allowCurrentLocation,
    required this.accessibleOnly,
    required this.localeCode,
    required this.linesById,
    required this.onSelected,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TripEndpoint? value;
  final List<BusStop> stops;
  final List<Place> places;
  final LatLng? userPosition;
  final bool allowCurrentLocation;
  final bool accessibleOnly;
  final String localeCode;
  final Map<String, BusLine> linesById;
  final ValueChanged<TripEndpoint> onSelected;

  @override
  State<_StationAutocompleteField> createState() =>
      _StationAutocompleteFieldState();
}

class _StationAutocompleteFieldState extends State<_StationAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final ValueNotifier<List<StationSearchEntry>> _results =
      ValueNotifier<List<StationSearchEntry>>(const []);
  final ValueNotifier<int> _highlightedIdx = ValueNotifier<int>(0);

  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  bool _programmaticEdit = false;

  @override
  void initState() {
    super.initState();
    _syncTextFromValue();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _StationAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncTextFromValue();
    }
  }

  void _syncTextFromValue() {
    final isSl = widget.localeCode == 'sl';
    final nextText = widget.value == null
        ? ''
        : (widget.value!.kind == TripEndpointKind.gps
            ? (isSl ? 'Moja lokacija' : 'My Current Location')
            : widget.value!.rawName);
    if (_controller.text != nextText) {
      _programmaticEdit = true;
      _controller.text = nextText;
      _programmaticEdit = false;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    _results.dispose();
    _highlightedIdx.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    if (isMobile) return;
    if (_focusNode.hasFocus) {
      _runFilter(_controller.text);
      _showOverlay();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onChanged(String raw) {
    if (_programmaticEdit) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _runFilter(raw);
      if (MediaQuery.sizeOf(context).width >= 900 && _focusNode.hasFocus) {
        _showOverlay();
      }
    });
  }

  void _runFilter(String query) {
    final isSl = widget.localeCode == 'sl';
    final filtered = filterAndSortStationEntries(
      rawQuery: query,
      stops: widget.stops,
      places: widget.places,
      userPosition: widget.userPosition,
      allowCurrentLocation: widget.allowCurrentLocation,
      currentLocationLabel: isSl ? 'Moja lokacija' : 'My Current Location',
      accessibleOnly: widget.accessibleOnly,
    );
    _results.value = filtered;
    _highlightedIdx.value = 0;
  }

  void _selectEntry(StationSearchEntry entry) {
    _removeOverlay();
    _focusNode.unfocus();
    _programmaticEdit = true;
    _controller.text = entry.title;
    _programmaticEdit = false;
    widget.onSelected(entry.endpoint);
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 320.0;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(ctx).colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 290),
              child: ValueListenableBuilder<List<StationSearchEntry>>(
                valueListenable: _results,
                builder: (_, items, _) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        widget.localeCode == 'sl'
                            ? 'Ni najdenih postajališč.'
                            : 'No matching stops found.',
                      ),
                    );
                  }
                  return ValueListenableBuilder<int>(
                    valueListenable: _highlightedIdx,
                    builder: (_, activeIdx, _) {
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: items.length.clamp(0, 30),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _AutocompleteResultTile(
                            entry: item,
                            query: _controller.text,
                            highlighted: index == activeIdx,
                            linesById: widget.linesById,
                            onTap: () => _selectEntry(item),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _openMobileSearchSheet() async {
    final isSl = widget.localeCode == 'sl';
    final picked = await showModalBottomSheet<StationSearchEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _MobileStationSearchSheet(
        title: widget.label,
        initialQuery: '',
        stops: widget.stops,
        places: widget.places,
        userPosition: widget.userPosition,
        allowCurrentLocation: widget.allowCurrentLocation,
        accessibleOnly: widget.accessibleOnly,
        localeCode: widget.localeCode,
        linesById: widget.linesById,
        currentLocationLabel: isSl ? 'Moja lokacija' : 'My Current Location',
      ),
    );
    if (picked != null && mounted) {
      _selectEntry(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final scheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent || _overlayEntry == null) return;
          final items = _results.value;
          if (items.isEmpty) return;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _highlightedIdx.value =
                (_highlightedIdx.value + 1) % items.length.clamp(1, 30);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            final maxLen = items.length.clamp(1, 30);
            _highlightedIdx.value = (_highlightedIdx.value - 1 + maxLen) % maxLen;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            final idx = _highlightedIdx.value.clamp(0, items.length - 1);
            _selectEntry(items[idx]);
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            _removeOverlay();
            _focusNode.unfocus();
          }
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          readOnly: isMobile,
          onTap: isMobile ? _openMobileSearchSheet : null,
          onChanged: _onChanged,
          decoration: InputDecoration(
            isDense: true,
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, size: 20, color: scheme.primary),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                      if (!isMobile) _focusNode.requestFocus();
                    },
                  )
                : const Icon(Icons.search_rounded, size: 18),
          ),
        ),
      ),
    );
  }
}

class _MobileStationSearchSheet extends StatefulWidget {
  const _MobileStationSearchSheet({
    required this.title,
    required this.initialQuery,
    required this.stops,
    required this.places,
    required this.userPosition,
    required this.allowCurrentLocation,
    required this.accessibleOnly,
    required this.localeCode,
    required this.linesById,
    required this.currentLocationLabel,
  });

  final String title;
  final String initialQuery;
  final List<BusStop> stops;
  final List<Place> places;
  final LatLng? userPosition;
  final bool allowCurrentLocation;
  final bool accessibleOnly;
  final String localeCode;
  final Map<String, BusLine> linesById;
  final String currentLocationLabel;

  @override
  State<_MobileStationSearchSheet> createState() =>
      _MobileStationSearchSheetState();
}

class _MobileStationSearchSheetState extends State<_MobileStationSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final ValueNotifier<List<StationSearchEntry>> _entries =
      ValueNotifier<List<StationSearchEntry>>(const []);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialQuery;
    _updateEntries(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _entries.dispose();
    super.dispose();
  }

  void _updateEntries(String q) {
    _entries.value = filterAndSortStationEntries(
      rawQuery: q,
      stops: widget.stops,
      places: widget.places,
      userPosition: widget.userPosition,
      allowCurrentLocation: widget.allowCurrentLocation,
      currentLocationLabel: widget.currentLocationLabel,
      accessibleOnly: widget.accessibleOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSl = widget.localeCode == 'sl';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 100), () {
                    if (mounted) _updateEntries(v);
                  });
                },
                decoration: InputDecoration(
                  hintText: isSl
                      ? 'Vpišite postajo (brez šumnikov, npr. zelez)...'
                      : 'Type stop or destination...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      _updateEntries('');
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ValueListenableBuilder<List<StationSearchEntry>>(
                  valueListenable: _entries,
                  builder: (_, items, _) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          isSl
                              ? 'Ni ujemajočih postajališč.'
                              : 'No matching stops.',
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, idx) => _AutocompleteResultTile(
                        entry: items[idx],
                        query: _ctrl.text,
                        highlighted: false,
                        linesById: widget.linesById,
                        onTap: () => Navigator.of(context).pop(items[idx]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutocompleteResultTile extends StatelessWidget {
  const _AutocompleteResultTile({
    required this.entry,
    required this.query,
    required this.highlighted,
    required this.linesById,
    required this.onTap,
  });

  final StationSearchEntry entry;
  final String query;
  final bool highlighted;
  final Map<String, BusLine> linesById;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: highlighted
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      child: ListTile(
        dense: true,
        minTileHeight: 50,
        leading: Icon(
          entry.isCurrentLocation
              ? Icons.my_location_rounded
              : (entry.lineIds.isEmpty
                  ? Icons.place_outlined
                  : Icons.directions_bus_rounded),
          color: entry.isCurrentLocation ? scheme.primary : null,
        ),
        title: _HighlightedText(text: entry.title, query: query),
        subtitle: entry.lineIds.isEmpty
            ? Text(
                entry.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final code in entry.lineIds.take(6))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: (linesById[code]?.color ?? scheme.primary)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: linesById[code]?.color ?? scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
        trailing: entry.isStepFree && entry.lineIds.isNotEmpty
            ? Icon(Icons.accessible_rounded, size: 17, color: scheme.secondary)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final normQ = normalizeSlovenianSearch(query);
    if (normQ.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final normText = normalizeSlovenianSearch(text);
    final matchStart = normText.indexOf(normQ);
    if (matchStart < 0 || matchStart + normQ.length > text.length) {
      return Text(text, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final matchEnd = matchStart + normQ.length;
    final scheme = Theme.of(context).colorScheme;

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (matchStart > 0) TextSpan(text: text.substring(0, matchStart)),
          TextSpan(
            text: text.substring(matchStart, matchEnd),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: scheme.primary,
              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
            ),
          ),
          if (matchEnd < text.length) TextSpan(text: text.substring(matchEnd)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
