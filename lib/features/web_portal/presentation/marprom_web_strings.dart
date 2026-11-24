// Multi-language copy (sl, en, de, sr_Latn) tailored to the Marprom Web Portal.

/// Provides localized editorial and analytics labels for the Marprom Web Portal.
class MarpromWebStrings {
  MarpromWebStrings._(this.localeCode);

  /// Active locale code (`sl`, `en`, `de`, `sr_Latn`).
  final String localeCode;

  /// Resolves [MarpromWebStrings] for [localeCode], defaulting to Slovenian (`sl`).
  static MarpromWebStrings of(String localeCode) =>
      MarpromWebStrings._(localeCode);

  String _pick({
    required String sl,
    required String en,
    required String de,
    required String sr,
  }) {
    switch (localeCode) {
      case 'en':
        return en;
      case 'de':
        return de;
      case 'sr_Latn':
        return sr;
      case 'sl':
      default:
        return sl;
    }
  }

  String get corporateStrip => _pick(
        sl: 'Javno podjetje Marprom d.o.o. • Skupina JHMB • Avtobusna postaja Maribor, Mlinska ul. 1',
        en: 'Marprom Public Transit Maribor • JHMB Group • Maribor Bus Station, Mlinska ul. 1',
        de: 'Marprom Stadtverkehr Maribor • JHMB-Gruppe • Busbahnhof Maribor, Mlinska ul. 1',
        sr: 'Javno preduzeće Marprom d.o.o. • Grupa JHMB • Autobuska stanica Maribor, Mlinska ul. 1',
      );

  String get navHome => _pick(
        sl: 'Domov',
        en: 'Home',
        de: 'Startseite',
        sr: 'Početna',
      );

  String get navSchedules => _pick(
        sl: 'Vozni redi in linije',
        en: 'Schedules & Lines',
        de: 'Fahrpläne & Linien',
        sr: 'Red vožnje i linije',
      );

  String get navPlanner => _pick(
        sl: 'Načrtovalec poti',
        en: 'Route Planner',
        de: 'Routenplaner',
        sr: 'Planer rute',
      );

  String get navLiveStats => _pick(
        sl: 'Avtobusi v živo & Statistika',
        en: 'Live Map & Stats',
        de: 'Live-Karte & Statistik',
        sr: 'Autobusi uživo i statistika',
      );

  String get navTickets => _pick(
        sl: 'Vozovnice',
        en: 'Tickets & Fares',
        de: 'Tickets & Tarife',
        sr: 'Karte i cene',
      );

  String get navDownload => _pick(
        sl: 'Mobilna aplikacija',
        en: 'Mobile App (APK / iOS)',
        de: 'Mobile App (APK / iOS)',
        sr: 'Mobilna aplikacija',
      );

  String get heroEyebrow => _pick(
        sl: 'MESTNI POTNIŠKI PROMET MARIBOR • 19 LINIJ (G1–G6 & P7–P19)',
        en: 'MARIBOR URBAN PUBLIC TRANSIT • 19 LINES (G1–G6 & P7–P19)',
        de: 'STADTVERKEHR MARIBOR • 19 LINIEN (G1–G6 & P7–P19)',
        sr: 'GRADSKI JAVNI PREVOZ MARIBOR • 19 LINIJA (G1–G6 & P7–P19)',
      );

  String get heroTitle => _pick(
        sl: 'Povezujemo Maribor.\nZanesljivo, zeleno in v živo.',
        en: 'Connecting Maribor.\nReliable, electric & live.',
        de: 'Wir verbinden Maribor.\nZuverlässig, elektrisch & live.',
        sr: 'Povezujemo Maribor.\nPouzdano, električno i uživo.',
      );

  String get heroSubtitle => _pick(
        sl: 'Preglejte vozne rede glavnih (G1–G6) in povezovalnih (P7–P19) linij za vsak dan v tednu, načrtujte pot z Google Maps Routes API, spremljajte 3D zemljevid ter točno število potnikov na vsakem avtobusu.',
        en: 'Explore 7-day schedules for all G1–G6 main and P7–P19 connector lines, plan routes with Google Routes API & Maps, inspect the 3D live map, and track exact passenger counts aboard every bus.',
        de: 'Entdecken Sie 7-Tage-Fahrpläne für G1–G6 & P7–P19, planen Sie mit der Google Routes API, verfolgen Sie Busse auf der 3D-Karte und sehen Sie genaue Fahrgastzahlen.',
        sr: 'Pregledajte red vožnje za sve linije G1–G6 i P7–P19 za svaki dan u nedelji, planirajte rutu uz Google Routes API, pratite 3D mapu i tačan broj putnika u svakom autobusu.',
      );

  String get quickPlannerTitle => _pick(
        sl: 'Hitri načrtovalec naslednje poti',
        en: 'Quick Next-Trip Planner',
        de: 'Schneller Routenplaner',
        sr: 'Brzi planer sledeće rute',
      );

  String get fromLabel => _pick(
        sl: 'Vstopno postajališče',
        en: 'From stop',
        de: 'Starthaltestelle',
        sr: 'Polazna stanica',
      );

  String get toLabel => _pick(
        sl: 'Ciljno postajališče',
        en: 'Destination stop',
        de: 'Zielhaltestelle',
        sr: 'Odredišna stanica',
      );

  String get planRouteCta => _pick(
        sl: 'Načrtuj pot z Google Maps & Marprom',
        en: 'Plan Route with Google Maps & Marprom',
        de: 'Route mit Google Maps & Marprom planen',
        sr: 'Planiraj rutu uz Google Maps i Marprom',
      );

  String get open3DMapCta => _pick(
        sl: 'Odpri 3D zemljevid v živo',
        en: 'Open 3D Live Map',
        de: '3D-Live-Karte öffnen',
        sr: 'Otvori 3D mapu uživo',
      );

  String get kpiActiveBuses => _pick(
        sl: 'Avtobusov na trasi',
        en: 'Active Buses Now',
        de: 'Aktive Busse jetzt',
        sr: 'Aktivnih autobusa',
      );

  String get kpiPassengersNow => _pick(
        sl: 'Potnikov na avtobusih',
        en: 'Passengers Aboard Now',
        de: 'Fahrgäste an Bord',
        sr: 'Putnika u vozilima',
      );

  String get kpiOnTime => _pick(
        sl: 'Točnost voznega parka',
        en: 'Fleet On-Time Rate',
        de: 'Pünktlichkeit',
        sr: 'Tačnost voznog parka',
      );

  String get kpiElectric => _pick(
        sl: 'Električnih avtobusov',
        en: 'Electric Buses Active',
        de: 'Elektrobusse aktiv',
        sr: 'Električnih autobusa',
      );

  String get allLines => _pick(
        sl: 'Vse linije (19)',
        en: 'All Lines (19)',
        de: 'Alle Linien (19)',
        sr: 'Sve linije (19)',
      );

  String get mainLines => _pick(
        sl: 'Glavne G1–G6',
        en: 'Main G1–G6',
        de: 'Hauptlinien G1–G6',
        sr: 'Glavne G1–G6',
      );

  String get connectorLines => _pick(
        sl: 'Povezovalne P7–P19',
        en: 'Connector P7–P19',
        de: 'Verbindung P7–P19',
        sr: 'Povezujuće P7–P19',
      );

  String weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return _pick(sl: 'Ponedeljek', en: 'Monday', de: 'Montag', sr: 'Ponedeljak');
      case DateTime.tuesday:
        return _pick(sl: 'Torek', en: 'Tuesday', de: 'Dienstag', sr: 'Utorak');
      case DateTime.wednesday:
        return _pick(sl: 'Sreda', en: 'Wednesday', de: 'Mittwoch', sr: 'Sreda');
      case DateTime.thursday:
        return _pick(sl: 'Četrtek', en: 'Thursday', de: 'Donnerstag', sr: 'Četvrtak');
      case DateTime.friday:
        return _pick(sl: 'Petek', en: 'Friday', de: 'Freitag', sr: 'Petak');
      case DateTime.saturday:
        return _pick(sl: 'Sobota', en: 'Saturday', de: 'Samstag', sr: 'Subota');
      case DateTime.sunday:
      default:
        return _pick(
          sl: 'Nedelja / Praznik',
          en: 'Sunday / Holiday',
          de: 'Sonntag / Feiertag',
          sr: 'Nedelja / Praznik',
        );
    }
  }

  String get passengersWord => _pick(
        sl: 'potnikov',
        en: 'passengers',
        de: 'Fahrgäste',
        sr: 'putnika',
      );

  String get downloadTitle => _pick(
        sl: 'Mobilna aplikacija M Mobilnost',
        en: 'M Mobilnost Mobile App',
        de: 'M Mobilnost Mobile App',
        sr: 'Mobilna aplikacija M Mobilnost',
      );

  String get downloadAndroidCta => _pick(
        sl: 'Prenesi Android APK (m-mobilnost.apk)',
        en: 'Download Android APK (m-mobilnost.apk)',
        de: 'Android-APK herunterladen (m-mobilnost.apk)',
        sr: 'Preuzmi Android APK (m-mobilnost.apk)',
      );

  //**********************************************
  // Live page: road geometry source & occupancy *
  //**********************************************

  String _slLines(int n) {
    final mod = n % 100;
    if (mod == 1) return '$n linija';
    if (mod == 2) return '$n liniji';
    if (mod == 3 || mod == 4) return '$n linije';
    return '$n linij';
  }

  String _srLines(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '$n linija';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n linije';
    }
    return '$n linija';
  }

  /// Truthful source line above the live map: bundled OSM road geometry.
  String liveRoadRoutesSummary(int lineCount) => _pick(
        sl: 'Cestne trase linij (OpenStreetMap, avtobusno usmerjanje) • ${_slLines(lineCount)}',
        en: 'Line road routes (OpenStreetMap, bus routing) • $lineCount ${lineCount == 1 ? 'line' : 'lines'}',
        de: 'Straßenverläufe der Linien (OpenStreetMap, Bus-Routing) • $lineCount ${lineCount == 1 ? 'Linie' : 'Linien'}',
        sr: 'Putne trase linija (OpenStreetMap, autobusko rutiranje) • ${_srLines(lineCount)}',
      );

  /// Source line above the live map when one line is focused.
  String liveRoadRouteFocused(String lineCode, String distance, String duration) =>
      _pick(
        sl: 'Cestna trasa linije $lineCode (OpenStreetMap, avtobusno usmerjanje) • $distance, ~$duration po voznem redu',
        en: 'Road route of line $lineCode (OpenStreetMap, bus routing) • $distance, ~$duration scheduled',
        de: 'Straßenverlauf der Linie $lineCode (OpenStreetMap, Bus-Routing) • $distance, ~$duration laut Fahrplan',
        sr: 'Putna trasa linije $lineCode (OpenStreetMap, autobusko rutiranje) • $distance, ~$duration po redu vožnje',
      );

  String get liveOccupancyTitle => _pick(
        sl: 'Zasedenost avtobusov v živo',
        en: 'Live bus occupancy',
        de: 'Live-Auslastung der Busse',
        sr: 'Popunjenost autobusa uživo',
      );

  String get liveOccupancyHint => _pick(
        sl: 'Razvrščeno od najbolj polnih. Izberite avtobus za podroben prikaz sedežev in stojišč.',
        en: 'Sorted from fullest. Select a bus to see its seats and standing room in detail.',
        de: 'Nach Auslastung sortiert. Bus wählen, um Sitz- und Stehplätze im Detail zu sehen.',
        sr: 'Poređano od najpunijih. Izaberite autobus za detaljan prikaz sedišta i stajanja.',
      );

  String get simulatedShort => _pick(
        sl: 'simulirano',
        en: 'simulated',
        de: 'simuliert',
        sr: 'simulirano',
      );

  String get simulatedTooltip => _pick(
        sl: 'Položaj in število potnikov izračuna simulator voznega parka (ni APC telemetrije v živo).',
        en: 'Position and passenger count come from the fleet simulator (no live APC telemetry).',
        de: 'Position und Fahrgastzahl stammen aus dem Flottensimulator (keine Live-APC-Daten).',
        sr: 'Položaj i broj putnika računa simulator voznog parka (bez APC telemetrije uživo).',
      );

  String seatedStanding(int seated, int seatedCap, int standing, int standingCap) =>
      _pick(
        sl: 'Sedi $seated/$seatedCap • stoji $standing/$standingCap',
        en: 'Seated $seated/$seatedCap • standing $standing/$standingCap',
        de: 'Sitzend $seated/$seatedCap • stehend $standing/$standingCap',
        sr: 'Sedi $seated/$seatedCap • stoji $standing/$standingCap',
      );

  String get showAllBuses => _pick(
        sl: 'Prikaži vse avtobuse',
        en: 'Show all buses',
        de: 'Alle Busse anzeigen',
        sr: 'Prikaži sve autobuse',
      );

  String get showFewerBuses => _pick(
        sl: 'Prikaži manj',
        en: 'Show fewer',
        de: 'Weniger anzeigen',
        sr: 'Prikaži manje',
      );

  String get selectedBus => _pick(
        sl: 'izbran',
        en: 'selected',
        de: 'ausgewählt',
        sr: 'izabran',
      );

  String get showSeatDetail => _pick(
        sl: 'Prikaži sedeže in stojišča',
        en: 'Show seats and standing room',
        de: 'Sitz- und Stehplätze anzeigen',
        sr: 'Prikaži sedišta i stajanja',
      );
}
