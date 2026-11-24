// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'M Mobilnost';

  @override
  String get appBrand => 'M Mobilnost 2.0 • Marprom';

  @override
  String get languageNameSl => 'Slovenščina';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameDe => 'Deutsch';

  @override
  String get languageNameSrLatn => 'Srpski / Hrvatski';

  @override
  String get navHome => 'Start';

  @override
  String get navMap => 'Karte';

  @override
  String get navPlan => 'Planen';

  @override
  String get navTickets => 'Tickets';

  @override
  String get navLines => 'Linien';

  @override
  String get navNotices => 'Hinweise';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navAccount => 'Konto';

  @override
  String get navMore => 'Mehr';

  @override
  String get commonLoading => 'Wird geladen...';

  @override
  String get commonEmpty => 'Keine Daten vorhanden.';

  @override
  String get commonErrorTitle => 'Etwas ist schiefgelaufen';

  @override
  String get commonErrorBody =>
      'Daten konnten derzeit nicht geladen werden. Bitte prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonContinue => 'Weiter';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonSkip => 'Überspringen';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonPrevious => 'Zurück';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonClear => 'Löschen';

  @override
  String get commonRefresh => 'Aktualisieren';

  @override
  String get commonFilter => 'Filtern';

  @override
  String get commonAll => 'Alle';

  @override
  String get commonFavorites => 'Favoriten';

  @override
  String get commonShowMore => 'Mehr anzeigen';

  @override
  String get commonShowLess => 'Weniger anzeigen';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonOk => 'OK';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonEnable => 'Aktivieren';

  @override
  String get commonDisable => 'Deaktivieren';

  @override
  String get commonPlaceholderNotice =>
      'Dieser Bereich wird in der nächsten Entwicklungsphase ergänzt.';

  @override
  String commonMinutesShort(int minutes) {
    return '$minutes Min.';
  }

  @override
  String commonHoursShort(int hours) {
    return '$hours Std.';
  }

  @override
  String commonSecondsShort(int seconds) {
    return '$seconds s';
  }

  @override
  String commonMetersShort(int meters) {
    return '$meters m';
  }

  @override
  String commonKilometersShort(String km) {
    return '$km km';
  }

  @override
  String commonMinutesPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '$count Minute',
      zero: 'weniger als eine Minute',
    );
    return '$_temp0';
  }

  @override
  String commonStopsPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Haltestellen',
      one: '$count Haltestelle',
      zero: '0 Haltestellen',
    );
    return '$_temp0';
  }

  @override
  String commonTransfersPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Umstiege',
      one: '$count Umstieg',
      zero: 'ohne Umstieg',
    );
    return '$_temp0';
  }

  @override
  String commonBusesPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Busse',
      one: '$count Bus',
      zero: 'keine Busse',
    );
    return '$_temp0';
  }

  @override
  String commonUpdatedAgo(String time) {
    return 'Aktualisiert vor $time';
  }

  @override
  String commonLastUpdatedAt(String time) {
    return 'Zuletzt aktualisiert: $time';
  }

  @override
  String get commonJustNow => 'gerade eben';

  @override
  String get statusEarly => 'Verfrüht';

  @override
  String get statusOnTime => 'Pünktlich';

  @override
  String get statusLate => 'Verspätet';

  @override
  String get statusInfo => 'Info';

  @override
  String get statusWarning => 'Warnung';

  @override
  String get statusDisruption => 'Störung';

  @override
  String get statusCancelled => 'Ausgefallen';

  @override
  String get statusDetour => 'Umleitung';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String statusEarlyByMinutes(int minutes) {
    return '$minutes Min. früher';
  }

  @override
  String statusLateByMinutes(int minutes) {
    return '+$minutes Min. Verspätung';
  }

  @override
  String get statusArrivingNow => 'Kommt jetzt an';

  @override
  String statusDepartingIn(int minutes) {
    return 'Abfahrt in $minutes Min.';
  }

  @override
  String get badgeOfflineTitle => 'Offline-Modus';

  @override
  String get badgeOfflineBody =>
      'Es werden zwischengespeicherte Fahrpläne und gespeicherte Tickets angezeigt.';

  @override
  String badgeOfflineLastSync(String time) {
    return 'Zuletzt synchronisiert: $time';
  }

  @override
  String get badgeSimulatedLabel => 'Simulierte Daten';

  @override
  String get badgeSimulatedTooltip =>
      'Live-Positionen und Zeiten werden lokal für Demo- und Testzwecke simuliert.';

  @override
  String get badgeSimulatedDisclaimer =>
      'Live-Daten befinden sich im Simulationsmodus. Zeiten dienen zur Orientierung.';

  @override
  String get freshnessLive => 'Live-Daten';

  @override
  String get freshnessSimulated => 'Simuliert live';

  @override
  String get freshnessCached => 'Zwischengespeichert';

  @override
  String get freshnessStale => 'Möglicherweise veraltet';

  @override
  String get freshnessLiveDisabledFallback =>
      'Live-Daten nicht verfügbar, Fahrplan wird angezeigt';

  @override
  String get occupancyLabel => 'Auslastung';

  @override
  String get occupancyLow => 'Viele freie Plätze';

  @override
  String get occupancyMedium => 'Mäßig besetzt';

  @override
  String get occupancyHigh => 'Stark besetzt';

  @override
  String get occupancyFull => 'Bus ist voll';

  @override
  String get occupancyUnknown => 'Auslastung unbekannt';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei M Mobilnost 2.0';

  @override
  String get onboardingWelcomeSubtitle =>
      'Ihr barrierefreier, zuverlässiger Begleiter für die Stadtbusse von Marprom in Maribor.';

  @override
  String get onboardingChooseLanguage => 'App-Sprache wählen';

  @override
  String get onboardingAccessibilityTitle => 'Barrierefreiheit anpassen';

  @override
  String get onboardingAccessibilitySubtitle =>
      'Passen Sie Lesbarkeit und Sprachfunktionen jetzt oder jederzeit in den Einstellungen an.';

  @override
  String get onboardingLocationTitle => 'Standort & Datenschutz';

  @override
  String get onboardingLocationSubtitle =>
      'GPS für nahegelegene Haltestellen erlauben oder manuell ohne GPS eine Haltestelle wählen.';

  @override
  String get onboardingUseGps => 'GPS-Standort verwenden';

  @override
  String get onboardingUseManualLocation =>
      'Haltestelle manuell wählen (ohne GPS)';

  @override
  String get onboardingStartRiding => 'Fahrt starten';

  @override
  String get onboardingOpenGuide => 'Neu im Bus? Anleitung öffnen';

  @override
  String get guideTitle => 'Neu im Bus';

  @override
  String get guideSubtitle =>
      'Eine 5-Schritte-Anleitung für entspanntes Busfahren in Maribor.';

  @override
  String guideCardProgress(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get guideCard1Title => '1. Haltestelle & Linie finden';

  @override
  String get guideCard1Body =>
      'Prüfen Sie die nächste Haltestelle auf der Karte oder in der Linienliste. Jede Abfahrt zeigt Liniennummer und Ziel.';

  @override
  String get guideCard2Title => '2. Ticket kaufen oder bereithalten';

  @override
  String get guideCard2Body =>
      'Kaufen Sie ein Ticket im Bereich Tickets. Beim Öffnen wird die Bildschirmhelligkeit für den QR-Scanner erhöht.';

  @override
  String get guideCard3Title => '3. Vorne einsteigen';

  @override
  String get guideCard3Body =>
      'Geben Sie dem Fahrer bei Ankunft des Busses ein klares Zeichen. Steigen Sie vorne ein und entwerten Sie Ihr Ticket.';

  @override
  String get guideCard4Title => '4. Fahrt live verfolgen';

  @override
  String get guideCard4Body =>
      'Im Live-Tracker sehen Sie kommende Haltestellen, die geschätzte Ankunft und erhalten rechtzeitig eine Erinnerung.';

  @override
  String get guideCard5Title => '5. Aussteigen & Umsteigen';

  @override
  String get guideCard5Body =>
      'Drücken Sie vor Ihrer Zielhaltestelle auf STOP. Achten Sie beim Umsteigen auf Warnungen bei knapper Umsteigezeit.';

  @override
  String get guideFinishCta => 'Verstanden, los geht\'s';

  @override
  String get homeGreeting => 'Wohin fahren wir heute?';

  @override
  String get homeSearchHint => 'Ziel, Haltestelle oder Linie suchen...';

  @override
  String get homeFavoriteStops => 'Favoriten-Haltestellen';

  @override
  String get homeNearbyStops => 'Haltestellen in der Nähe';

  @override
  String get homeQuickActions => 'Schnellzugriff';

  @override
  String get homeActiveTicket => 'Aktives Ticket';

  @override
  String get homeNoActiveTicket => 'Derzeit kein aktives Ticket';

  @override
  String get homeNearestStopAction => 'Nächste Haltestelle';

  @override
  String get homePlanTripAction => 'Route planen';

  @override
  String get homeBuyTicketAction => 'Ticket kaufen';

  @override
  String get homeLinesAction => 'Linien & Fahrpläne';

  @override
  String get homeGuideAction => 'Neu im Bus';

  @override
  String get homeAskMarpromAction => 'Marprom fragen';

  @override
  String get askTitle => 'Marprom fragen';

  @override
  String get askSubtitle => 'Schnellhilfe für Linien, Abfahrten und Tickets';

  @override
  String get askInputHint => 'Fragen Sie z. B.: Wann fährt der nächste Bus 6?';

  @override
  String get askSend => 'Senden';

  @override
  String get askVoicePrompt => 'Ich höre zu...';

  @override
  String get askSample1 => 'Wann fährt der nächste Bus ab Glavni trg?';

  @override
  String get askSample2 => 'Welches Ticket eignet sich heute am besten?';

  @override
  String get askSample3 => 'Gibt es heute Störungen oder Umleitungen?';

  @override
  String get askSample4 => 'Wo ist die nächste Bushaltestelle?';

  @override
  String get askClearChat => 'Chat leeren';

  @override
  String get askDisclaimer =>
      'Antworten basieren auf lokalen Marprom-Fahrplänen und simulierten Live-Daten.';

  @override
  String get askNoMatch =>
      'Darauf habe ich keine genaue Antwort. Fragen Sie nach einer Linie, Haltestelle, einem Ticket oder Störungen.';

  @override
  String get linesTitle => 'Linien & Fahrpläne';

  @override
  String get linesSearchHint => 'Linie oder Endhaltestelle suchen...';

  @override
  String linesBadge(String code) {
    return 'Linie $code';
  }

  @override
  String get linesDirectionLabel => 'Richtung';

  @override
  String get linesSwapDirection => 'Richtung wechseln';

  @override
  String get linesScheduleWeekday => 'Werktag';

  @override
  String get linesScheduleSaturday => 'Samstag';

  @override
  String get linesScheduleSunday => 'Sonntag / Feiertag';

  @override
  String get linesFirstBus => 'Erster Bus';

  @override
  String get linesLastBus => 'Letzter Bus';

  @override
  String get linesLowFloor => 'Niederflurbus barrierefrei';

  @override
  String get linesFavoriteAdd => 'Zu Favoriten hinzufügen';

  @override
  String get linesFavoriteRemove => 'Aus Favoriten entfernen';

  @override
  String get linesNoDepartures =>
      'Für den gewählten Tag gibt es keine weiteren Abfahrten.';

  @override
  String get mapTitle => 'Haltestellenkarte';

  @override
  String get mapSwitchToList => 'Liste';

  @override
  String get mapSwitchToMap => 'Karte';

  @override
  String get mapSearchHint => 'Haltestelle oder Straße suchen...';

  @override
  String get mapCenterOnMe => 'Mein Standort';

  @override
  String get mapManualCenter => 'Zentrum Maribor';

  @override
  String get mapFilterAccessible => 'Stufenfrei zugänglich';

  @override
  String get mapFilterActiveBuses => 'Live-Busse';

  @override
  String get mapStopDetailsOpen => 'Abfahrten anzeigen';

  @override
  String get stopTitle => 'Haltestelle';

  @override
  String stopPlatform(String platform) {
    return 'Steig $platform';
  }

  @override
  String get stopUpcomingDepartures => 'Nächste Abfahrten';

  @override
  String get stopAmenitiesTitle => 'Ausstattung';

  @override
  String get stopAmenityShelter => 'Wartehäuschen';

  @override
  String get stopAmenityBench => 'Sitzbank';

  @override
  String get stopAmenityTactile => 'Taktile Leitstreifen';

  @override
  String get stopAmenityStepFree => 'Stufenfreier Zugang';

  @override
  String get stopAmenityDisplay => 'Digitale Anzeige';

  @override
  String get stopNoDepartures =>
      'In den nächsten Stunden sind keine Abfahrten geplant.';

  @override
  String get trackerTitle => 'Live-Tracker';

  @override
  String get trackerFollowBus => 'Bus verfolgen';

  @override
  String get trackerNextStop => 'Nächste Haltestelle';

  @override
  String get trackerStopsRemaining => 'Verbleibende Haltestellen';

  @override
  String get trackerEta => 'Voraussichtliche Ankunft';

  @override
  String trackerScheduledTime(String time) {
    return 'Planmäßig: $time';
  }

  @override
  String get trackerNotifyMe => 'Benachrichtigen';

  @override
  String get trackerNotifyCancel => 'Erinnerung löschen';

  @override
  String get trackerNotifyActive =>
      'Erinnerung aktiv: Sie werden vor Ankunft benachrichtigt.';

  @override
  String get trackerNotifyPrompt =>
      'Wählen Sie, wann Sie erinnert werden möchten.';

  @override
  String get trackerAdviceEarlyTitle => 'Bus fährt verfrüht';

  @override
  String trackerAdviceEarlyBody(int minutes) {
    return 'Dieser Bus ist $minutes Min. zu früh. Gehen Sie früher zur Haltestelle oder prüfen Sie die nächste Abfahrt.';
  }

  @override
  String get trackerAdviceOnTimeTitle => 'Bus ist pünktlich';

  @override
  String get trackerAdviceOnTimeBody =>
      'Erwarten Sie die Ankunft zur geplanten Zeit.';

  @override
  String get trackerAdviceLateTitle => 'Bus hat Verspätung';

  @override
  String trackerAdviceLateBody(int minutes) {
    return 'Dieser Bus hat $minutes Min. Verspätung. Sie können warten oder unten alternative Verbindungen prüfen.';
  }

  @override
  String get trackerAdviceReviewAlternatives => 'Alternativen prüfen';

  @override
  String get planTitle => 'Routenplaner';

  @override
  String get planOriginLabel => 'Start';

  @override
  String get planDestinationLabel => 'Ziel';

  @override
  String get planCurrentLocation => 'Aktueller Standort';

  @override
  String get planSwap => 'Start und Ziel tauschen';

  @override
  String get planLeaveNow => 'Jetzt abfahren';

  @override
  String get planDepartAt => 'Abfahrt um';

  @override
  String get planArriveBy => 'Ankunft bis';

  @override
  String get planAccessibleOnly => 'Nur stufenfreie Verbindungen';

  @override
  String get planFewerTransfers => 'Weniger Umstiege';

  @override
  String get planFindRoutes => 'Verbindungen suchen';

  @override
  String get planTightTransferTitle => 'Knapper Umstieg';

  @override
  String planTightTransferBody(int minutes) {
    return 'Sie haben nur $minutes Min. zum Umsteigen. Bei leichter Verspätung des ersten Busses könnten Sie den Anschluss verpassen.';
  }

  @override
  String get planWhatDoINextTitle => 'Was mache ich jetzt?';

  @override
  String planStepWalkTo(String stop, String distance) {
    return 'Zu Fuß zur Haltestelle $stop ($distance)';
  }

  @override
  String planStepBoardLine(String line, String direction) {
    return 'Einsteigen in Linie $line Richtung $direction';
  }

  @override
  String planStepRideStops(String stops, String stop) {
    return '$stops fahren bis $stop';
  }

  @override
  String planStepTransferAt(String stop) {
    return 'Umsteigen an der Haltestelle $stop';
  }

  @override
  String planStepGetOffAt(String stop) {
    return 'Aussteigen an der Haltestelle $stop';
  }

  @override
  String get planStepArrived => 'Sie haben Ihr Ziel erreicht.';

  @override
  String get nearestStopTitle => 'Nächste Haltestelle';

  @override
  String nearestStopDistance(String distance) {
    return 'Entfernung: $distance';
  }

  @override
  String nearestStopWalkTime(int minutes) {
    return 'Ca. $minutes Min. zu Fuß';
  }

  @override
  String get nearestStopNextBus => 'Nächste Abfahrt';

  @override
  String get nearestStopUseManual => 'Haltestelle manuell wählen';

  @override
  String get ticketsTitle => 'Meine Tickets';

  @override
  String get ticketsActiveTab => 'Aktiv';

  @override
  String get ticketsHistoryTab => 'Vergangen';

  @override
  String get ticketsBuyButton => 'Ticket kaufen';

  @override
  String get ticketsShopTitle => 'Ticket-Shop';

  @override
  String get ticketsCheckoutTitle => 'Bezahlung';

  @override
  String get ticketsViewTitle => 'Aktives Ticket';

  @override
  String get ticketsZoneMaribor => 'Zone Maribor';

  @override
  String ticketsValidUntil(String time) {
    return 'Gültig bis $time';
  }

  @override
  String get ticketsQrHint => 'Halten Sie den QR-Code an das Lesegerät im Bus.';

  @override
  String get ticketsBrightnessBoosted =>
      'Bildschirmhelligkeit für leichteres Scannen vorübergehend erhöht.';

  @override
  String get ticketsNfcStubTitle => 'Kontaktlose Entwertung (NFC)';

  @override
  String get ticketsNfcStubBody =>
      'Simulierte NFC-Bestätigung beim Einstieg. Halten Sie Ihr Telefon an das Lesegerät.';

  @override
  String get ticketsNfcTapToSimulate => 'NFC-Kontakt simulieren';

  @override
  String get ticketsNfcValidated => 'Ticket erfolgreich entwertet.';

  @override
  String get ticketsQuantity => 'Anzahl';

  @override
  String get ticketsTotalPrice => 'Gesamtbetrag';

  @override
  String get ticketsPayNow => 'Jetzt bezahlen';

  @override
  String get ticketsPurchaseSuccess => 'Ticket gekauft und einsatzbereit.';

  @override
  String get ticketsMinorTitle =>
      'Bestätigung durch Eltern oder Erziehungsberechtigte';

  @override
  String get ticketsMinorUnder16Warning =>
      'Personen unter 16 Jahren benötigen für Online-Käufe die Bestätigung eines Elternteils oder Erziehungsberechtigten.';

  @override
  String get ticketsMinorUnder18Notice =>
      'Minderjährige zwischen 16 und 18 Jahren müssen die Zustimmung für digitale Käufe bestätigen.';

  @override
  String get ticketsMinorGuardianConfirm =>
      'Ich bestätige, dass ich die Zustimmung meiner Eltern oder Erziehungsberechtigten habe.';

  @override
  String get ticketsMinorGuardianEmail =>
      'E-Mail der Eltern oder Erziehungsberechtigten';

  @override
  String get paymentsTitle => 'Zahlungsmethoden';

  @override
  String get paymentsAddMethod => 'Zahlungsmethode hinzufügen';

  @override
  String get paymentsDefaultBadge => 'Standard';

  @override
  String get paymentsSimulatedNotice =>
      'Alle Zahlungsabläufe werden in diesem Prototyp lokal simuliert.';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountGuestMode => 'Gastmodus';

  @override
  String get accountSignIn => 'Anmelden';

  @override
  String get accountSignOut => 'Abmelden';

  @override
  String get accountManagePayments => 'Zahlungen verwalten';

  @override
  String get accountGdprTitle => 'Datenschutz & Einwilligungen (DSGVO)';

  @override
  String get accountGdprDescription =>
      'Verwalten Sie Ihre Einwilligungen für Analysen, Benachrichtigungen und lokale Speicherung.';

  @override
  String get accountGdprAnalytics => 'Anonyme Nutzungsanalyse';

  @override
  String get accountGdprNotifications =>
      'Push-Benachrichtigungen bei Verspätungen';

  @override
  String get accountGdprExport => 'Meine Daten exportieren';

  @override
  String get accountGdprDelete => 'Lokale Daten löschen';

  @override
  String get accountGdprPrivacyLink => 'Datenschutzerklärung';

  @override
  String get noticesTitle => 'Hinweise & smarte Erinnerungen';

  @override
  String get noticesAllTab => 'Alle Hinweise';

  @override
  String get noticesDisruptionsTab => 'Störungen';

  @override
  String get noticesSmartAlertsTitle => 'Smarte Erinnerungen';

  @override
  String get noticesSmartAlertsDesc =>
      'Erhalten Sie Benachrichtigungen vor Ankunft Ihres Busses, bei Störungen auf Favoritenlinien und vor Ticketablauf.';

  @override
  String get noticesMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get noticesEmpty => 'Aktuell gibt es keine neuen Hinweise.';

  @override
  String noticesAffectedLines(String lines) {
    return 'Betroffene Linien: $lines';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionAppearance => 'Erscheinungsbild';

  @override
  String get settingsSectionLanguage => 'Sprache';

  @override
  String get settingsSectionAccessibility => 'Barrierefreiheit & Sprache';

  @override
  String get settingsSectionData => 'Daten & Standort';

  @override
  String get settingsSectionPrivacy => 'Datenschutz';

  @override
  String get settingsSectionUsability => 'Usability-Tests & Demo';

  @override
  String get settingsThemeMode => 'Farbthema';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsThemeHighContrast => 'Hoher Kontrast (AAA)';

  @override
  String get settingsLanguage => 'App-Sprache';

  @override
  String get settingsExtraLargeText => 'Extra großer Text (bis 200 %)';

  @override
  String get settingsExtraLargeTextDesc =>
      'Vergrößert die Schrift in der gesamten App für optimale Lesbarkeit.';

  @override
  String get settingsReducedMotion => 'Reduzierte Bewegung';

  @override
  String get settingsReducedMotionDesc =>
      'Deaktiviert Bildschirmübergänge und Animationen.';

  @override
  String get settingsReadAloud => 'Vorlesen (TTS)';

  @override
  String get settingsReadAloudDesc =>
      'Liest wichtige Hinweise, Abfahrten und Warnungen laut vor.';

  @override
  String get settingsVoiceInput => 'Spracheingabe';

  @override
  String get settingsVoiceInputDesc =>
      'Ermöglicht Sprachsuche für Haltestellen und Marprom fragen.';

  @override
  String get settingsHapticAlerts => 'Haptische Hinweise';

  @override
  String get settingsHapticAlertsDesc =>
      'Unterschiedliche Vibrationsmuster für Ankunft, Verspätung, Ticketablauf und Störungen.';

  @override
  String get settingsSoundAlerts => 'Optionale Töne';

  @override
  String get settingsSoundAlertsDesc =>
      'Spielt bei wichtigen Benachrichtigungen einen kurzen Signalton ab.';

  @override
  String get settingsShowDataSource => 'Datenquelle anzeigen';

  @override
  String get settingsShowDataSourceDesc =>
      'Zeigt an, ob Daten live, simuliert oder zwischengespeichert sind.';

  @override
  String get settingsUseSimulatedLive => 'Simulierte Live-Daten';

  @override
  String get settingsUseSimulatedLiveDesc =>
      'Verwendet den deterministischen lokalen Marprom-Simulator.';

  @override
  String get settingsSimulationSeed => 'Simulations-Seed';

  @override
  String get settingsLocationManual => 'Manueller Standortmodus';

  @override
  String get settingsLocationManualDesc =>
      'Verwendet eine gewählte Haltestelle statt des GPS-Sensors.';

  @override
  String get settingsUsabilityTestMode => 'Usability-Testmodus';

  @override
  String get settingsUsabilityTestModeDesc =>
      'Zeigt Schnellwerkzeuge für Testszenarien, Onboarding-Reset und Statusprüfung.';

  @override
  String get settingsResetOnboarding => 'Onboarding zurücksetzen';

  @override
  String get settingsOpenGuide => 'Anleitung Neu im Bus öffnen';

  @override
  String get a11yBackButton => 'Zurück zum vorherigen Bildschirm';

  @override
  String get a11yCloseButton => 'Schließen';

  @override
  String get a11ySearchField => 'Suchfeld';

  @override
  String get a11yVoiceSearchButton => 'Sprachsuche';

  @override
  String get a11yReadAloudButton => 'Vorlesen';

  @override
  String get a11yFavoriteToggle => 'Favorit umschalten';

  @override
  String get a11yQrCode => 'Ticket-QR-Code zum Scannen im Bus';

  @override
  String a11yLineBadge(String code) {
    return 'Buslinie $code';
  }

  @override
  String a11yOccupancyBar(String level) {
    return 'Busauslastung: $level';
  }

  @override
  String a11yStatusChip(String label) {
    return 'Status: $label';
  }

  @override
  String get a11yOfflineBanner => 'Hinweis auf Offline-Betrieb';

  @override
  String get a11ySimulatedBadge => 'Hinweis auf simulierte Daten';

  @override
  String get a11yProfileButton => 'Konto öffnen';

  @override
  String get a11yNoticesButton => 'Hinweise öffnen';

  @override
  String get a11ySettingsButton => 'Einstellungen öffnen';

  @override
  String get a11ySwapStations => 'Start- und Zielhaltestelle tauschen';

  @override
  String homeNextBusSummary(
    String destination,
    String line,
    int minutes,
    int meters,
  ) {
    return 'Nächster Bus nach $destination: Linie $line in $minutes Min., $meters m entfernt';
  }

  @override
  String get homeNoFavoriteStops =>
      'Noch keine Favoriten-Haltestellen. Fügen Sie welche über Karte oder Fahrplan hinzu.';

  @override
  String get homeNextDepartures => 'Nächste Abfahrten';

  @override
  String get homeActiveDisruptionAlert =>
      'Betriebshinweis auf Ihrer Favoritenlinie';

  @override
  String get linesFollowBusLive => 'Bus live verfolgen';

  @override
  String get linesOccupancyBySegment => 'Auslastung nach Streckenabschnitt';

  @override
  String linesDirectionTo(String destination) {
    return 'Richtung: $destination';
  }

  @override
  String get stopAddToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get stopRemoveFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get stopPlanFromHere => 'Route ab hier planen';

  @override
  String get stopSelectDay => 'Tag auswählen';

  @override
  String get stopAllLines => 'Alle Linien';

  @override
  String get stopLiveAndScheduledNote =>
      'Die Zeiten kombinieren Live-Verspätungen mit dem festen Fahrplan.';

  @override
  String get mapLocationDeniedTitle => 'Standortzugriff nicht verfügbar';

  @override
  String get mapLocationDeniedBody =>
      'Sie können die App weiterhin vollständig nutzen, indem Sie Ihre Starthaltestelle manuell wählen.';

  @override
  String get mapSelectManualStop => 'Starthaltestelle wählen';

  @override
  String mapFollowingLine(String code) {
    return 'Route der Linie $code wird angezeigt';
  }

  @override
  String get mapTapStopHint =>
      'Tippen Sie auf eine Haltestelle für Abfahrten oder auf einen Bus für seine Route.';

  @override
  String get mapNoNearbyStops =>
      'In diesem Bereich wurden keine Haltestellen gefunden.';

  @override
  String mapListDistance(String distance) {
    return '$distance entfernt';
  }

  @override
  String get trackerSelectLineOrStop =>
      'Linie oder Haltestelle wählen, um einen Bus live zu verfolgen';

  @override
  String trackerDistanceAndEta(String distance, int minutes) {
    return '$distance entfernt • ca. $minutes Min.';
  }

  @override
  String trackerNotifyMinutesAway(int minutes) {
    return '$minutes Min. vor Ankunft benachrichtigen';
  }

  @override
  String get trackerNoActiveBuses =>
      'Auf dieser Linie sind derzeit keine Busse aktiv.';

  @override
  String trackerEarlyActionTip(int minutes, int arriveEarlyMin) {
    return 'Dieser Bus ist $minutes Min. zu früh und könnte vor Plan abfahren. Seien Sie $arriveEarlyMin Min. früher an der Haltestelle.';
  }

  @override
  String trackerLateActionTip(int minutes, String time) {
    return 'Dieser Bus hat $minutes Min. Verspätung. Erwartet um $time.';
  }

  @override
  String get trackerNextStepCardTitle => 'Nächster Schritt Ihrer Fahrt';

  @override
  String trackerGetOffNextStop(String stop) {
    return 'An der nächsten Haltestelle aussteigen: $stop';
  }

  @override
  String trackerAlertFiredBanner(String line, int minutes, String stop) {
    return 'Bus $line ist $minutes Min. von $stop entfernt!';
  }

  @override
  String get planNoResultsTitle => 'Keine Verbindung gefunden';

  @override
  String get planNoResultsBody =>
      'Für diese Uhrzeit wurde keine passende Busverbindung gefunden. Gehen Sie zu einem Knotenpunkt oder warten Sie auf die nächste Abfahrt.';

  @override
  String get planTryWalkFurther => 'Mit längerem Fußweg suchen';

  @override
  String get planTryWaitNext => 'Spätere Abfahrten prüfen';

  @override
  String planWalkTimeAndDistance(int minutes, String distance) {
    return 'Zu Fuß $minutes Min. ($distance)';
  }

  @override
  String planDataReliability(String source) {
    return 'Datenzuverlässigkeit: $source';
  }

  @override
  String planTransferWaitMinutes(int minutes, String stop) {
    return 'Umsteigezeit: $minutes Min. an $stop';
  }

  @override
  String planOptionSummary(
    int totalMin,
    String transfers,
    String walkDistance,
  ) {
    return '$totalMin Min. • $transfers • $walkDistance Fußweg';
  }

  @override
  String get planSelectOrigin => 'Start wählen';

  @override
  String get planSelectDestination => 'Ziel wählen';

  @override
  String get nearestStopGoalHint =>
      'Nächste Haltestelle mit Bus zu Ihrem Ziel finden';

  @override
  String get nearestStopSortedByArrival =>
      'Nach frühester Ankunftszeit sortiert';

  @override
  String nearestStopArrivesAt(String time) {
    return 'Ankunft $time';
  }

  @override
  String get ticketsAuthRequiredTitle => 'Konto für Ticketkauf erforderlich';

  @override
  String get ticketsAuthRequiredBody =>
      'Sie können alle Ticketarten als Gast ansehen. Melden Sie sich an oder erstellen Sie ein kostenloses Testkonto zum Kaufen und Speichern.';

  @override
  String get ticketsStepChoose => '1. Ticket';

  @override
  String get ticketsStepPayment => '2. Zahlung';

  @override
  String get ticketsStepConfirm => '3. Bestätigen';

  @override
  String ticketsValidFromUntil(String from, String until) {
    return 'Gültig von $from bis $until';
  }

  @override
  String get ticketsStartNow => 'Sofort gültig (empfohlen)';

  @override
  String get ticketsStartLater => 'Startzeit wählen';

  @override
  String get ticketsTabUpcoming => 'Bevorstehend';

  @override
  String get ticketsTabExpired => 'Abgelaufen';

  @override
  String ticketsDriverFallbackCode(String code) {
    return 'Ersatzcode für Fahrer: $code';
  }

  @override
  String get ticketsLiveClockNote =>
      'Live-Uhr verhindert Missbrauch von Screenshots';

  @override
  String get ticketsNfcComingSoon => 'NFC-Karte in der App bald verfügbar';

  @override
  String get ticketsDemoPaymentNotice =>
      'Demo-Zahlung — es wird kein echtes Geld abgebucht';

  @override
  String get ticketsNoActiveTickets => 'Sie haben noch keine aktiven Tickets.';

  @override
  String get ticketsNoUpcomingTickets => 'Keine bevorstehenden Tickets.';

  @override
  String get ticketsNoExpiredTickets => 'Keine abgelaufenen Tickets.';

  @override
  String ticketsRemainingTime(String time) {
    return 'Verbleibend: $time';
  }

  @override
  String get paymentsCard => 'Zahlungskarte';

  @override
  String get paymentsGooglePay => 'Google Pay';

  @override
  String get paymentsApplePay => 'Apple Pay';

  @override
  String get paymentsBankTransfer => 'Überweisung / E-Banking';

  @override
  String get paymentsMobilePay => 'Mobiles Bezahlen';

  @override
  String get paymentsCardBrandLabel => 'Kartenmarke (z. B. Visa)';

  @override
  String get paymentsLast4Label => 'Nur letzte 4 Ziffern (Demo)';

  @override
  String get paymentsLast4Validation => 'Genau 4 Ziffern eingeben';

  @override
  String get paymentsSetDefault => 'Als Standard festlegen';

  @override
  String get accountSignUp => 'Konto erstellen';

  @override
  String get accountPasswordReset => 'Passwort zurücksetzen';

  @override
  String get accountDeleteAccount => 'Mein Konto und Daten löschen';

  @override
  String get accountDeleteConfirmTitle =>
      'Konto und alle lokalen Daten löschen?';

  @override
  String get accountDeleteConfirmBody =>
      'Dies löscht Ihr Testprofil, gespeicherte Tickets, Zahlungskarten und Einstellungen von diesem Gerät.';

  @override
  String get accountNameLabel => 'Vollständiger Name';

  @override
  String get accountEmailLabel => 'E-Mail-Adresse';

  @override
  String get accountPasswordLabel => 'Passwort';

  @override
  String get accountDobLabel => 'Geburtsdatum';

  @override
  String get accountDemoAccountHint => 'Demo-Konto: demo@marprom.si / demo1234';

  @override
  String get accountYouthEligible =>
      'Berechtigt für Jugend- / Studierendentarif';

  @override
  String get accountSeniorEligible => 'Berechtigt für Seniorentarif';

  @override
  String accountResetSent(String email) {
    return 'Test-Link zum Zurücksetzen des Passworts für $email vorbereitet.';
  }

  @override
  String get accountSaveProfile => 'Profil speichern';

  @override
  String get onboardingConsentLocation =>
      'Standort bei geöffneter App erlauben, um nahe Haltestellen zu finden (verlässt im Testmodus nie das Gerät)';

  @override
  String get onboardingConsentNotifications =>
      'Benachrichtigungen für Ankunft, Verspätung und Ticketablauf erlauben';

  @override
  String get onboardingConsentAnalytics =>
      'Optionale anonyme Nutzungsstatistik (standardmäßig aus)';

  @override
  String get onboardingAccountOptionalNote =>
      'Ein Konto ist jetzt optional und wird erst beim Ticketkauf benötigt.';

  @override
  String get noticesTriggerAlternative => 'Alternative Route finden';

  @override
  String get noticesSmartBusArriving => 'Erinnerung bei baldiger Busankunft';

  @override
  String get noticesSmartLineDelayed =>
      'Hinweis bei Verspätung einer Favoritenlinie';

  @override
  String get noticesSmartTicketExpiring => 'Warnung vor Ticketablauf';

  @override
  String get noticesPreviewVibration => 'Visuellen & Vibrationsalarm testen';

  @override
  String get settingsClearLocalData => 'Lokalen Cache leeren';

  @override
  String get settingsClearLocalDataDone => 'Lokaler Cache geleert.';

  @override
  String get settingsAboutTitle => 'Über M Mobilnost 2.0';

  @override
  String get settingsAboutBody =>
      'Barrierefreier einheitlicher Marprom-Nahverkehrs- und Ticket-Prototyp für Maribor. Simulierte Live-Daten sind klar gekennzeichnet.';

  @override
  String get settingsUsabilityStart => 'Zeitgesteuertes Szenario starten';

  @override
  String get settingsUsabilityFinish => 'Szenario abschließen';

  @override
  String get settingsUsabilityRecordError => 'Fehler protokollieren (+1)';

  @override
  String get settingsUsabilityExportCsv => 'CSV exportieren';

  @override
  String get settingsUsabilityExportJson => 'JSON exportieren';

  @override
  String settingsUsabilitySummary(int seconds, int taps, int errors) {
    return 'Zeit: $seconds s • Tipps: $taps • Fehler: $errors';
  }
}
