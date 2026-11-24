// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class AppLocalizationsSr extends AppLocalizations {
  AppLocalizationsSr([String locale = 'sr']) : super(locale);

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
  String get navHome => 'Početna';

  @override
  String get navMap => 'Karta';

  @override
  String get navPlan => 'Planiraj';

  @override
  String get navTickets => 'Karte';

  @override
  String get navLines => 'Linije';

  @override
  String get navNotices => 'Obavijesti';

  @override
  String get navSettings => 'Postavke';

  @override
  String get navAccount => 'Nalog';

  @override
  String get navMore => 'Više';

  @override
  String get commonLoading => 'Učitavanje...';

  @override
  String get commonEmpty => 'Nema podataka za prikaz.';

  @override
  String get commonErrorTitle => 'Došlo je do greške';

  @override
  String get commonErrorBody =>
      'Podaci trenutno nisu dostupni. Provjerite vezu i pokušajte ponovo.';

  @override
  String get commonRetry => 'Pokušaj ponovo';

  @override
  String get commonCancel => 'Otkaži';

  @override
  String get commonConfirm => 'Potvrdi';

  @override
  String get commonContinue => 'Nastavi';

  @override
  String get commonBack => 'Nazad';

  @override
  String get commonClose => 'Zatvori';

  @override
  String get commonSave => 'Sačuvaj';

  @override
  String get commonDone => 'Gotovo';

  @override
  String get commonSkip => 'Preskoči';

  @override
  String get commonNext => 'Dalje';

  @override
  String get commonPrevious => 'Prethodni';

  @override
  String get commonSearch => 'Pretraži';

  @override
  String get commonClear => 'Očisti';

  @override
  String get commonRefresh => 'Osvježi';

  @override
  String get commonFilter => 'Filtriraj';

  @override
  String get commonAll => 'Sve';

  @override
  String get commonFavorites => 'Omiljene';

  @override
  String get commonShowMore => 'Prikaži više';

  @override
  String get commonShowLess => 'Prikaži manje';

  @override
  String get commonYes => 'Da';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonOk => 'U redu';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get commonDelete => 'Obriši';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get commonRemove => 'Ukloni';

  @override
  String get commonEnable => 'Uključi';

  @override
  String get commonDisable => 'Isključi';

  @override
  String get commonPlaceholderNotice =>
      'Ovaj ekran će biti dopunjen u sljedećoj fazi razvoja.';

  @override
  String commonMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String commonHoursShort(int hours) {
    return '$hours h';
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
      other: '$count minuta',
      few: '$count minute',
      one: '$count minuta',
      zero: 'manje od minute',
    );
    return '$_temp0';
  }

  @override
  String commonStopsPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stanica',
      few: '$count stanice',
      one: '$count stanica',
      zero: '0 stanica',
    );
    return '$_temp0';
  }

  @override
  String commonTransfersPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presjedanja',
      few: '$count presjedanja',
      one: '$count presjedanje',
      zero: 'bez presjedanja',
    );
    return '$_temp0';
  }

  @override
  String commonBusesPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autobusa',
      few: '$count autobusa',
      one: '$count autobus',
      zero: 'nema autobusa',
    );
    return '$_temp0';
  }

  @override
  String commonUpdatedAgo(String time) {
    return 'Ažurirano prije $time';
  }

  @override
  String commonLastUpdatedAt(String time) {
    return 'Posljednje ažuriranje: $time';
  }

  @override
  String get commonJustNow => 'upravo sada';

  @override
  String get statusEarly => 'Ranije';

  @override
  String get statusOnTime => 'Na vrijeme';

  @override
  String get statusLate => 'Kasni';

  @override
  String get statusInfo => 'Info';

  @override
  String get statusWarning => 'Upozorenje';

  @override
  String get statusDisruption => 'Poremećaj';

  @override
  String get statusCancelled => 'Otkazano';

  @override
  String get statusDetour => 'Obilazak';

  @override
  String get statusOffline => 'Bez interneta';

  @override
  String get statusOnline => 'Povezano';

  @override
  String statusEarlyByMinutes(int minutes) {
    return '$minutes min ranije';
  }

  @override
  String statusLateByMinutes(int minutes) {
    return '+$minutes min kašnjenja';
  }

  @override
  String get statusArrivingNow => 'Stiže sada';

  @override
  String statusDepartingIn(int minutes) {
    return 'Polazak za $minutes min';
  }

  @override
  String get badgeOfflineTitle => 'Rad bez interneta';

  @override
  String get badgeOfflineBody => 'Prikazani su sačuvani redovi vožnje i karte.';

  @override
  String badgeOfflineLastSync(String time) {
    return 'Posljednja sinhronizacija: $time';
  }

  @override
  String get badgeSimulatedLabel => 'Simulirani podaci';

  @override
  String get badgeSimulatedTooltip =>
      'Pozicije i vremena uživo simuliraju se lokalno za testiranje i prikaz.';

  @override
  String get badgeSimulatedDisclaimer =>
      'Podaci uživo su u režimu simulacije. Vremena su informativna.';

  @override
  String get freshnessLive => 'Podaci uživo';

  @override
  String get freshnessSimulated => 'Simulirano uživo';

  @override
  String get freshnessCached => 'Sačuvano lokalno';

  @override
  String get freshnessStale => 'Moguće zastarjeli podaci';

  @override
  String get freshnessLiveDisabledFallback =>
      'Podaci uživo nisu dostupni, prikazan je red vožnje';

  @override
  String get occupancyLabel => 'Popunjenost';

  @override
  String get occupancyLow => 'Mnogo slobodnih mjesta';

  @override
  String get occupancyMedium => 'Umjereno popunjeno';

  @override
  String get occupancyHigh => 'Velika gužva';

  @override
  String get occupancyFull => 'Autobus je pun';

  @override
  String get occupancyUnknown => 'Popunjenost nije poznata';

  @override
  String get onboardingWelcomeTitle => 'Dobrodošli u M Mobilnost 2.0';

  @override
  String get onboardingWelcomeSubtitle =>
      'Vaš pristupačan i pouzdan vodič za gradske autobuse Marprom u Mariboru.';

  @override
  String get onboardingChooseLanguage => 'Odaberite jezik aplikacije';

  @override
  String get onboardingAccessibilityTitle => 'Podešavanja pristupačnosti';

  @override
  String get onboardingAccessibilitySubtitle =>
      'Prilagodite čitljivost i glasovne opcije sada ili bilo kada u Postavkama.';

  @override
  String get onboardingLocationTitle => 'Lokacija i privatnost';

  @override
  String get onboardingLocationSubtitle =>
      'Dozvolite GPS za najbliže stanice ili ručno izaberite stanicu u Mariboru bez GPS-a.';

  @override
  String get onboardingUseGps => 'Koristi GPS lokaciju';

  @override
  String get onboardingUseManualLocation => 'Ručni izbor stanice (bez GPS-a)';

  @override
  String get onboardingStartRiding => 'Započni vožnju';

  @override
  String get onboardingOpenGuide => 'Prvi put autobusom? Otvori vodič';

  @override
  String get guideTitle => 'Prvi put autobusom';

  @override
  String get guideSubtitle =>
      'Kratki vodič u 5 koraka za bezbrižnu vožnju po Mariboru.';

  @override
  String guideCardProgress(int current, int total) {
    return 'Korak $current od $total';
  }

  @override
  String get guideCard1Title => '1. Pronađite stanicu i liniju';

  @override
  String get guideCard1Body =>
      'Provjerite najbližu stanicu na karti ili u listi linija. Svaki polazak prikazuje broj linije i smjer.';

  @override
  String get guideCard2Title => '2. Kupite ili pripremite kartu';

  @override
  String get guideCard2Body =>
      'Kartu možete kupiti u dijelu Karte. Pri ulasku je otvorite kako bi se svjetlina ekrana pojačala za skeniranje QR koda.';

  @override
  String get guideCard3Title => '3. Uđite na prednja vrata';

  @override
  String get guideCard3Body =>
      'Kada autobus prilazi, jasno dajte znak vozaču. Uđite na prednja vrata i potvrdite kartu.';

  @override
  String get guideCard4Title => '4. Pratite vožnju uživo';

  @override
  String get guideCard4Body =>
      'U praćenju uživo vidite sljedeće stanice, procijenjeni dolazak i obavještenje prije izlaska.';

  @override
  String get guideCard5Title => '5. Izlazak i presjedanje';

  @override
  String get guideCard5Body =>
      'Prije svoje stanice pritisnite tipku STOP. Kod presjedanja obratite pažnju na upozorenje o kratkom vremenu.';

  @override
  String get guideFinishCta => 'Razumijem, krenimo';

  @override
  String get homeGreeting => 'Kuda idemo danas?';

  @override
  String get homeSearchHint => 'Unesite odredište, stanicu ili liniju...';

  @override
  String get homeFavoriteStops => 'Omiljene stanice';

  @override
  String get homeNearbyStops => 'Najbliže stanice';

  @override
  String get homeQuickActions => 'Brze opcije';

  @override
  String get homeActiveTicket => 'Aktivna karta';

  @override
  String get homeNoActiveTicket => 'Trenutno nemate aktivnu kartu';

  @override
  String get homeNearestStopAction => 'Najbliža stanica';

  @override
  String get homePlanTripAction => 'Planiraj rutu';

  @override
  String get homeBuyTicketAction => 'Kupi kartu';

  @override
  String get homeLinesAction => 'Linije i red vožnje';

  @override
  String get homeGuideAction => 'Prvi put autobusom';

  @override
  String get homeAskMarpromAction => 'Pitaj Marprom';

  @override
  String get askTitle => 'Pitaj Marprom';

  @override
  String get askSubtitle => 'Brzi pomoćnik za linije, polaske i karte';

  @override
  String get askInputHint => 'Pitajte npr. Kada ide sljedeći autobus 6?';

  @override
  String get askSend => 'Pošalji';

  @override
  String get askVoicePrompt => 'Slušam...';

  @override
  String get askSample1 => 'Kada ide sljedeći autobus sa Glavnog trga?';

  @override
  String get askSample2 => 'Koja je karta najpovoljnija za danas?';

  @override
  String get askSample3 => 'Ima li danas poremećaja ili obilazaka?';

  @override
  String get askSample4 => 'Gdje je najbliža autobuska stanica?';

  @override
  String get askClearChat => 'Očisti razgovor';

  @override
  String get askDisclaimer =>
      'Odgovori koriste lokalni red vožnje Marprom i simulaciju uživo.';

  @override
  String get askNoMatch =>
      'Nemam tačan odgovor na to pitanje. Pokušajte pitati za liniju, stanicu, kartu ili obavještenja.';

  @override
  String get linesTitle => 'Linije i red vožnje';

  @override
  String get linesSearchHint => 'Pretraži liniju ili krajnju stanicu...';

  @override
  String linesBadge(String code) {
    return 'Linija $code';
  }

  @override
  String get linesDirectionLabel => 'Smjer';

  @override
  String get linesSwapDirection => 'Obrni smjer';

  @override
  String get linesScheduleWeekday => 'Radni dan';

  @override
  String get linesScheduleSaturday => 'Subota';

  @override
  String get linesScheduleSunday => 'Nedjelja / praznik';

  @override
  String get linesFirstBus => 'Prvi polazak';

  @override
  String get linesLastBus => 'Posljednji polazak';

  @override
  String get linesLowFloor => 'Niskopodni autobus';

  @override
  String get linesFavoriteAdd => 'Dodaj u omiljene';

  @override
  String get linesFavoriteRemove => 'Ukloni iz omiljenih';

  @override
  String get linesNoDepartures => 'Za odabrani dan više nema polazaka.';

  @override
  String get mapTitle => 'Karta stanica';

  @override
  String get mapSwitchToList => 'Lista';

  @override
  String get mapSwitchToMap => 'Karta';

  @override
  String get mapSearchHint => 'Pretraži stanicu ili ulicu...';

  @override
  String get mapCenterOnMe => 'Moja lokacija';

  @override
  String get mapManualCenter => 'Centar Maribora';

  @override
  String get mapFilterAccessible => 'Pristup bez stepenica';

  @override
  String get mapFilterActiveBuses => 'Autobusi uživo';

  @override
  String get mapStopDetailsOpen => 'Otvori polaske stanice';

  @override
  String get stopTitle => 'Stanica';

  @override
  String stopPlatform(String platform) {
    return 'Peron $platform';
  }

  @override
  String get stopUpcomingDepartures => 'Sljedeći polasci';

  @override
  String get stopAmenitiesTitle => 'Oprema stanice';

  @override
  String get stopAmenityShelter => 'Nadstrešnica';

  @override
  String get stopAmenityBench => 'Klupa';

  @override
  String get stopAmenityTactile => 'Taktilne oznake';

  @override
  String get stopAmenityStepFree => 'Pristup bez stepenica';

  @override
  String get stopAmenityDisplay => 'Digitalni ekran';

  @override
  String get stopNoDepartures => 'Nema planiranih polazaka u narednim satima.';

  @override
  String get trackerTitle => 'Praćenje uživo';

  @override
  String get trackerFollowBus => 'Prati autobus';

  @override
  String get trackerNextStop => 'Sljedeća stanica';

  @override
  String get trackerStopsRemaining => 'Preostale stanice';

  @override
  String get trackerEta => 'Procijenjeni dolazak';

  @override
  String trackerScheduledTime(String time) {
    return 'Po redu vožnje: $time';
  }

  @override
  String get trackerNotifyMe => 'Obavijesti me';

  @override
  String get trackerNotifyCancel => 'Otkaži podsjetnik';

  @override
  String get trackerNotifyActive =>
      'Podsjetnik je aktivan: dobićete obavijest prije dolaska.';

  @override
  String get trackerNotifyPrompt =>
      'Izaberite kada želite obavijest prije dolaska autobusa.';

  @override
  String get trackerAdviceEarlyTitle => 'Autobus ide ispred reda vožnje';

  @override
  String trackerAdviceEarlyBody(int minutes) {
    return 'Autobus je $minutes min ranije. Krenite ranije prema stanici ili provjerite sljedeći polazak.';
  }

  @override
  String get trackerAdviceOnTimeTitle => 'Autobus ide po redu vožnje';

  @override
  String get trackerAdviceOnTimeBody => 'Očekujte dolazak u planirano vrijeme.';

  @override
  String get trackerAdviceLateTitle => 'Autobus kasni';

  @override
  String trackerAdviceLateBody(int minutes) {
    return 'Autobus kasni $minutes min. Možete sačekati na stanici ili ispod provjeriti drugu liniju.';
  }

  @override
  String get trackerAdviceReviewAlternatives => 'Provjeri alternative';

  @override
  String get planTitle => 'Planer puta';

  @override
  String get planOriginLabel => 'Polazište';

  @override
  String get planDestinationLabel => 'Odredište';

  @override
  String get planCurrentLocation => 'Trenutna lokacija';

  @override
  String get planSwap => 'Zamijeni polazište i odredište';

  @override
  String get planLeaveNow => 'Polazak sada';

  @override
  String get planDepartAt => 'Polazak u';

  @override
  String get planArriveBy => 'Dolazak do';

  @override
  String get planAccessibleOnly => 'Samo rute bez stepenica';

  @override
  String get planFewerTransfers => 'Manje presjedanja';

  @override
  String get planFindRoutes => 'Pronađi rute';

  @override
  String get planTightTransferTitle => 'Kratko presjedanje';

  @override
  String planTightTransferBody(int minutes) {
    return 'Za presjedanje imate samo $minutes min. Ako prvi autobus malo zakasni, možete propustiti vezu.';
  }

  @override
  String get planWhatDoINextTitle => 'Šta sada da uradim?';

  @override
  String planStepWalkTo(String stop, String distance) {
    return 'Pješačite do stanice $stop ($distance)';
  }

  @override
  String planStepBoardLine(String line, String direction) {
    return 'Uđite u liniju $line u smjeru $direction';
  }

  @override
  String planStepRideStops(String stops, String stop) {
    return 'Vozite se $stops do stanice $stop';
  }

  @override
  String planStepTransferAt(String stop) {
    return 'Presjednite na stanici $stop';
  }

  @override
  String planStepGetOffAt(String stop) {
    return 'Siđite na stanici $stop';
  }

  @override
  String get planStepArrived => 'Stigli ste na odredište.';

  @override
  String get nearestStopTitle => 'Najbliža stanica';

  @override
  String nearestStopDistance(String distance) {
    return 'Udaljenost: $distance';
  }

  @override
  String nearestStopWalkTime(int minutes) {
    return 'Oko $minutes min hoda';
  }

  @override
  String get nearestStopNextBus => 'Sljedeći polazak';

  @override
  String get nearestStopUseManual => 'Izaberi stanicu ručno';

  @override
  String get ticketsTitle => 'Moje karte';

  @override
  String get ticketsActiveTab => 'Aktivne';

  @override
  String get ticketsHistoryTab => 'Prethodne';

  @override
  String get ticketsBuyButton => 'Kupi kartu';

  @override
  String get ticketsShopTitle => 'Kupovina karata';

  @override
  String get ticketsCheckoutTitle => 'Plaćanje';

  @override
  String get ticketsViewTitle => 'Važeća karta';

  @override
  String get ticketsZoneMaribor => 'Zona Maribor';

  @override
  String ticketsValidUntil(String time) {
    return 'Važi do $time';
  }

  @override
  String get ticketsQrHint => 'Prislonite QR kod validatoru u autobusu.';

  @override
  String get ticketsBrightnessBoosted =>
      'Svjetlina ekrana je privremeno pojačana radi lakšeg skeniranja.';

  @override
  String get ticketsNfcStubTitle => 'Beskontaktna potvrda (NFC)';

  @override
  String get ticketsNfcStubBody =>
      'Simulirana NFC potvrda pri ulasku. Prislonite telefon čitaču.';

  @override
  String get ticketsNfcTapToSimulate => 'Simuliraj NFC dodir';

  @override
  String get ticketsNfcValidated => 'Karta je uspješno potvrđena.';

  @override
  String get ticketsQuantity => 'Količina';

  @override
  String get ticketsTotalPrice => 'Ukupno';

  @override
  String get ticketsPayNow => 'Plati sada';

  @override
  String get ticketsPurchaseSuccess =>
      'Karta je kupljena i spremna za upotrebu.';

  @override
  String get ticketsMinorTitle => 'Potvrda roditelja ili staratelja';

  @override
  String get ticketsMinorUnder16Warning =>
      'Osobe mlađe od 16 godina moraju imati potvrdu roditelja ili staratelja za kupovinu.';

  @override
  String get ticketsMinorUnder18Notice =>
      'Maloljetne osobe od 16 do 18 godina moraju potvrditi saglasnost za digitalnu kupovinu.';

  @override
  String get ticketsMinorGuardianConfirm =>
      'Potvrđujem da imam saglasnost roditelja ili staratelja.';

  @override
  String get ticketsMinorGuardianEmail => 'E-pošta roditelja ili staratelja';

  @override
  String get paymentsTitle => 'Načini plaćanja';

  @override
  String get paymentsAddMethod => 'Dodaj način plaćanja';

  @override
  String get paymentsDefaultBadge => 'Podrazumijevano';

  @override
  String get paymentsSimulatedNotice =>
      'Svi tokovi plaćanja su u ovom prototipu lokalno simulirani.';

  @override
  String get accountTitle => 'Nalog';

  @override
  String get accountGuestMode => 'Režim gosta';

  @override
  String get accountSignIn => 'Prijava';

  @override
  String get accountSignOut => 'Odjava';

  @override
  String get accountManagePayments => 'Upravljaj plaćanjima';

  @override
  String get accountGdprTitle => 'Privatnost i saglasnosti (GDPR)';

  @override
  String get accountGdprDescription =>
      'Upravljajte saglasnostima za analitiku, obavijesti i lokalne podatke.';

  @override
  String get accountGdprAnalytics => 'Anonimna analiza korištenja';

  @override
  String get accountGdprNotifications => 'Obavijesti o kašnjenjima';

  @override
  String get accountGdprExport => 'Izvezi moje podatke';

  @override
  String get accountGdprDelete => 'Obriši lokalne podatke';

  @override
  String get accountGdprPrivacyLink => 'Politika privatnosti';

  @override
  String get noticesTitle => 'Obavijesti i pametni podsjetnici';

  @override
  String get noticesAllTab => 'Sve obavijesti';

  @override
  String get noticesDisruptionsTab => 'Poremećaji';

  @override
  String get noticesSmartAlertsTitle => 'Pametni podsjetnici';

  @override
  String get noticesSmartAlertsDesc =>
      'Primite upozorenje prije dolaska autobusa, kod poremećaja na omiljenoj liniji i prije isteka karte.';

  @override
  String get noticesMarkAllRead => 'Označi sve kao pročitano';

  @override
  String get noticesEmpty => 'Trenutno nema novih obavijesti.';

  @override
  String noticesAffectedLines(String lines) {
    return 'Pogođene linije: $lines';
  }

  @override
  String get settingsTitle => 'Postavke';

  @override
  String get settingsSectionAppearance => 'Izgled';

  @override
  String get settingsSectionLanguage => 'Jezik';

  @override
  String get settingsSectionAccessibility => 'Pristupačnost i govor';

  @override
  String get settingsSectionData => 'Podaci i lokacija';

  @override
  String get settingsSectionPrivacy => 'Privatnost';

  @override
  String get settingsSectionUsability => 'Testiranje upotrebljivosti i demo';

  @override
  String get settingsThemeMode => 'Tema boja';

  @override
  String get settingsThemeSystem => 'Sistemska';

  @override
  String get settingsThemeLight => 'Svijetla';

  @override
  String get settingsThemeDark => 'Tamna';

  @override
  String get settingsThemeHighContrast => 'Visoki kontrast (AAA)';

  @override
  String get settingsLanguage => 'Jezik aplikacije';

  @override
  String get settingsExtraLargeText => 'Veoma veliki tekst (do 200%)';

  @override
  String get settingsExtraLargeTextDesc =>
      'Povećava font u cijeloj aplikaciji radi bolje čitljivosti.';

  @override
  String get settingsReducedMotion => 'Smanjeni pokreti';

  @override
  String get settingsReducedMotionDesc =>
      'Isključuje animacije i prelaze ekrana.';

  @override
  String get settingsReadAloud => 'Čitanje naglas (TTS)';

  @override
  String get settingsReadAloudDesc =>
      'Čita ključna uputstva, polaske i upozorenja.';

  @override
  String get settingsVoiceInput => 'Glasovni unos';

  @override
  String get settingsVoiceInputDesc =>
      'Omogućava glasovnu pretragu stanica i pitanja.';

  @override
  String get settingsHapticAlerts => 'Haptička upozorenja';

  @override
  String get settingsHapticAlertsDesc =>
      'Različiti obrasci vibracije za dolazak, kašnjenje, istek karte i poremećaje.';

  @override
  String get settingsSoundAlerts => 'Opcioni zvučni signali';

  @override
  String get settingsSoundAlertsDesc =>
      'Reprodukuje kratak zvuk kod važnih obavijesti.';

  @override
  String get settingsShowDataSource => 'Prikaži izvor podataka';

  @override
  String get settingsShowDataSourceDesc =>
      'Prikazuje jesu li podaci uživo, simulirani ili lokalno sačuvani.';

  @override
  String get settingsUseSimulatedLive => 'Simulirani podaci uživo';

  @override
  String get settingsUseSimulatedLiveDesc =>
      'Koristi deterministički lokalni simulator vozila Marprom.';

  @override
  String get settingsSimulationSeed => 'Sjeme simulacije';

  @override
  String get settingsLocationManual => 'Ručni režim lokacije';

  @override
  String get settingsLocationManualDesc =>
      'Koristi odabranu stanicu umjesto GPS senzora.';

  @override
  String get settingsUsabilityTestMode => 'Režim testiranja upotrebljivosti';

  @override
  String get settingsUsabilityTestModeDesc =>
      'Prikazuje brze alate za testiranje scenarija, reset uvoda i pregled stanja.';

  @override
  String get settingsResetOnboarding => 'Resetuj uvodni ekran';

  @override
  String get settingsOpenGuide => 'Otvori vodič Prvi put autobusom';

  @override
  String get a11yBackButton => 'Nazad na prethodni ekran';

  @override
  String get a11yCloseButton => 'Zatvori';

  @override
  String get a11ySearchField => 'Polje za pretragu';

  @override
  String get a11yVoiceSearchButton => 'Glasovna pretraga';

  @override
  String get a11yReadAloudButton => 'Pročitaj naglas';

  @override
  String get a11yFavoriteToggle => 'Preklopi omiljeno';

  @override
  String get a11yQrCode => 'QR kod karte za skeniranje na validatoru';

  @override
  String a11yLineBadge(String code) {
    return 'Autobuska linija $code';
  }

  @override
  String a11yOccupancyBar(String level) {
    return 'Popunjenost autobusa: $level';
  }

  @override
  String a11yStatusChip(String label) {
    return 'Status: $label';
  }

  @override
  String get a11yOfflineBanner => 'Obavijest o radu bez interneta';

  @override
  String get a11ySimulatedBadge => 'Oznaka simuliranih podataka';

  @override
  String get a11yProfileButton => 'Otvori nalog';

  @override
  String get a11yNoticesButton => 'Otvori obavijesti';

  @override
  String get a11ySettingsButton => 'Otvori postavke';

  @override
  String get a11ySwapStations => 'Zamijeni početnu i krajnju stanicu';

  @override
  String homeNextBusSummary(
    String destination,
    String line,
    int minutes,
    int meters,
  ) {
    return 'Sljedeći autobus za $destination: linija $line za $minutes min, $meters m od vas';
  }

  @override
  String get homeNoFavoriteStops =>
      'Još nemate omiljenih stanica. Dodajte ih sa karte ili iz reda vožnje.';

  @override
  String get homeNextDepartures => 'Sljedeći polasci';

  @override
  String get homeActiveDisruptionAlert =>
      'Upozorenje o poremećaju na vašoj omiljenoj liniji';

  @override
  String get linesFollowBusLive => 'Prati autobus uživo';

  @override
  String get linesOccupancyBySegment => 'Popunjenost po dionicama rute';

  @override
  String linesDirectionTo(String destination) {
    return 'Smjer: $destination';
  }

  @override
  String get stopAddToFavorites => 'Dodaj u omiljene';

  @override
  String get stopRemoveFromFavorites => 'Ukloni iz omiljenih';

  @override
  String get stopPlanFromHere => 'Planiraj put odavde';

  @override
  String get stopSelectDay => 'Odaberi dan';

  @override
  String get stopAllLines => 'Sve linije';

  @override
  String get stopLiveAndScheduledNote =>
      'Vremena spajaju kašnjenja uživo sa stalnim redom vožnje.';

  @override
  String get mapLocationDeniedTitle => 'Pristup lokaciji nije dostupan';

  @override
  String get mapLocationDeniedBody =>
      'Aplikaciju i dalje možete koristiti u potpunosti ručnim izborom početne stanice.';

  @override
  String get mapSelectManualStop => 'Odaberi početnu stanicu';

  @override
  String mapFollowingLine(String code) {
    return 'Prikaz rute za liniju $code';
  }

  @override
  String get mapTapStopHint =>
      'Dodirnite stanicu za polaske ili autobus za prikaz njegove trase.';

  @override
  String get mapNoNearbyStops => 'U ovom području nisu pronađene stanice.';

  @override
  String mapListDistance(String distance) {
    return '$distance daleko';
  }

  @override
  String get trackerSelectLineOrStop =>
      'Izaberite liniju ili stanicu za praćenje uživo';

  @override
  String trackerDistanceAndEta(String distance, int minutes) {
    return '$distance daleko • oko $minutes min';
  }

  @override
  String trackerNotifyMinutesAway(int minutes) {
    return 'Obavijesti $minutes min prije dolaska';
  }

  @override
  String get trackerNoActiveBuses =>
      'Na ovoj liniji trenutno nema aktivnih autobusa.';

  @override
  String trackerEarlyActionTip(int minutes, int arriveEarlyMin) {
    return 'Ovaj autobus je $minutes min ranije i može krenuti prije reda vožnje. Budite na stanici $arriveEarlyMin min ranije.';
  }

  @override
  String trackerLateActionTip(int minutes, String time) {
    return 'Ovaj autobus kasni $minutes min. Očekuje se u $time.';
  }

  @override
  String get trackerNextStepCardTitle => 'Sljedeći korak na vašem putu';

  @override
  String trackerGetOffNextStop(String stop) {
    return 'Siđite na sljedećoj stanici: $stop';
  }

  @override
  String trackerAlertFiredBanner(String line, int minutes, String stop) {
    return 'Autobus $line je $minutes min udaljen od $stop!';
  }

  @override
  String get planNoResultsTitle => 'Ruta nije pronađena';

  @override
  String get planNoResultsBody =>
      'Za ovo vrijeme nije pronađena odgovarajuća autobuska veza. Pokušajte prošetati do čvorišta ili sačekati sljedeći polazak.';

  @override
  String get planTryWalkFurther => 'Traži s dužim pješačenjem';

  @override
  String get planTryWaitNext => 'Provjeri kasnije polaske';

  @override
  String planWalkTimeAndDistance(int minutes, String distance) {
    return 'Hod $minutes min ($distance)';
  }

  @override
  String planDataReliability(String source) {
    return 'Pouzdanost podataka: $source';
  }

  @override
  String planTransferWaitMinutes(int minutes, String stop) {
    return 'Čekanje presjedanja: $minutes min na $stop';
  }

  @override
  String planOptionSummary(
    int totalMin,
    String transfers,
    String walkDistance,
  ) {
    return '$totalMin min • $transfers • $walkDistance hoda';
  }

  @override
  String get planSelectOrigin => 'Izaberi polazište';

  @override
  String get planSelectDestination => 'Izaberi odredište';

  @override
  String get nearestStopGoalHint =>
      'Pronađite najbližu stanicu s autobusom do vašeg odredišta';

  @override
  String get nearestStopSortedByArrival =>
      'Sortirano po najranijem vremenu dolaska';

  @override
  String nearestStopArrivesAt(String time) {
    return 'Dolazi u $time';
  }

  @override
  String get ticketsAuthRequiredTitle => 'Za kupovinu je potreban nalog';

  @override
  String get ticketsAuthRequiredBody =>
      'Vrste karata možete pregledati kao gost. Prijavite se ili kreirajte besplatan testni nalog za kupovinu i čuvanje.';

  @override
  String get ticketsStepChoose => '1. Karta';

  @override
  String get ticketsStepPayment => '2. Plaćanje';

  @override
  String get ticketsStepConfirm => '3. Potvrda';

  @override
  String ticketsValidFromUntil(String from, String until) {
    return 'Važi od $from do $until';
  }

  @override
  String get ticketsStartNow => 'Važi odmah (preporučeno)';

  @override
  String get ticketsStartLater => 'Izaberi vrijeme početka';

  @override
  String get ticketsTabUpcoming => 'Nadolazeće';

  @override
  String get ticketsTabExpired => 'Istekle';

  @override
  String ticketsDriverFallbackCode(String code) {
    return 'Rezervni kod za vozača: $code';
  }

  @override
  String get ticketsLiveClockNote =>
      'Sat uživo sprečava zloupotrebu snimaka ekrana';

  @override
  String get ticketsNfcComingSoon => 'NFC kartica u aplikaciji uskoro stiže';

  @override
  String get ticketsDemoPaymentNotice =>
      'Demo plaćanje — pravi novac se ne naplaćuje';

  @override
  String get ticketsNoActiveTickets => 'Još nemate aktivnih karata.';

  @override
  String get ticketsNoUpcomingTickets => 'Nema nadolazećih karata.';

  @override
  String get ticketsNoExpiredTickets => 'Nema isteklih karata.';

  @override
  String ticketsRemainingTime(String time) {
    return 'Preostalo: $time';
  }

  @override
  String get paymentsCard => 'Platna kartica';

  @override
  String get paymentsGooglePay => 'Google Pay';

  @override
  String get paymentsApplePay => 'Apple Pay';

  @override
  String get paymentsBankTransfer => 'Bankovni transfer / e-bankarstvo';

  @override
  String get paymentsMobilePay => 'Mobilno plaćanje';

  @override
  String get paymentsCardBrandLabel => 'Brend kartice (npr. Visa)';

  @override
  String get paymentsLast4Label => 'Samo posljednje 4 cifre (demo)';

  @override
  String get paymentsLast4Validation => 'Unesite tačno 4 cifre';

  @override
  String get paymentsSetDefault => 'Postavi kao podrazumijevano';

  @override
  String get accountSignUp => 'Kreiraj nalog';

  @override
  String get accountPasswordReset => 'Resetuj lozinku';

  @override
  String get accountDeleteAccount => 'Obriši moj nalog i podatke';

  @override
  String get accountDeleteConfirmTitle =>
      'Obrisati nalog i sve lokalne podatke?';

  @override
  String get accountDeleteConfirmBody =>
      'Ovo briše vaš testni profil, sačuvane karte, platne kartice i postavke s ovog uređaja.';

  @override
  String get accountNameLabel => 'Ime i prezime';

  @override
  String get accountEmailLabel => 'E-adresa';

  @override
  String get accountPasswordLabel => 'Lozinka';

  @override
  String get accountDobLabel => 'Datum rođenja';

  @override
  String get accountDemoAccountHint =>
      'Demo korisnik: demo@marprom.si / demo1234';

  @override
  String get accountYouthEligible => 'Pravo na omladinsku / studentsku tarifu';

  @override
  String get accountSeniorEligible => 'Pravo na penzionersku tarifu';

  @override
  String accountResetSent(String email) {
    return 'Testni link za reset lozinke pripremljen za $email.';
  }

  @override
  String get accountSaveProfile => 'Sačuvaj profil';

  @override
  String get onboardingConsentLocation =>
      'Dozvoli lokaciju dok je aplikacija otvorena radi pronalaženja najbližih stanica (ne napušta uređaj u testnom režimu)';

  @override
  String get onboardingConsentNotifications =>
      'Dozvoli obavijesti o dolasku, kašnjenju i isteku karte';

  @override
  String get onboardingConsentAnalytics =>
      'Opciona anonimna statistika korištenja (podrazumijevano isključeno)';

  @override
  String get onboardingAccountOptionalNote =>
      'Nalog je sada opcionalan i potreban tek kasnije pri kupovini karata.';

  @override
  String get noticesTriggerAlternative => 'Pronađi drugu rutu';

  @override
  String get noticesSmartBusArriving => 'Upozorenje za skori dolazak autobusa';

  @override
  String get noticesSmartLineDelayed =>
      'Upozorenje za kašnjenje omiljene linije';

  @override
  String get noticesSmartTicketExpiring => 'Upozorenje pred istek karte';

  @override
  String get noticesPreviewVibration =>
      'Testiraj vizuelno i vibracijsko upozorenje';

  @override
  String get settingsClearLocalData => 'Očisti lokalnu predmemoriju';

  @override
  String get settingsClearLocalDataDone => 'Lokalna predmemorija je očišćena.';

  @override
  String get settingsAboutTitle => 'O aplikaciji M Mobilnost 2.0';

  @override
  String get settingsAboutBody =>
      'Pristupačan jedinstveni Marprom prototip za javni prevoz i karte u Mariboru. Simulirani podaci uživo su jasno označeni.';

  @override
  String get settingsUsabilityStart => 'Pokreni mjereni scenario';

  @override
  String get settingsUsabilityFinish => 'Završi scenario';

  @override
  String get settingsUsabilityRecordError => 'Zabilježi grešku (+1)';

  @override
  String get settingsUsabilityExportCsv => 'Izvezi CSV';

  @override
  String get settingsUsabilityExportJson => 'Izvezi JSON';

  @override
  String settingsUsabilitySummary(int seconds, int taps, int errors) {
    return 'Vrijeme: $seconds s • Dodiri: $taps • Greške: $errors';
  }
}

/// The translations for Serbian, using the Latin script (`sr_Latn`).
class AppLocalizationsSrLatn extends AppLocalizationsSr {
  AppLocalizationsSrLatn() : super('sr_Latn');

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
  String get navHome => 'Početna';

  @override
  String get navMap => 'Karta';

  @override
  String get navPlan => 'Planiraj';

  @override
  String get navTickets => 'Karte';

  @override
  String get navLines => 'Linije';

  @override
  String get navNotices => 'Obavijesti';

  @override
  String get navSettings => 'Postavke';

  @override
  String get navAccount => 'Nalog';

  @override
  String get navMore => 'Više';

  @override
  String get commonLoading => 'Učitavanje...';

  @override
  String get commonEmpty => 'Nema podataka za prikaz.';

  @override
  String get commonErrorTitle => 'Došlo je do greške';

  @override
  String get commonErrorBody =>
      'Podaci trenutno nisu dostupni. Provjerite vezu i pokušajte ponovo.';

  @override
  String get commonRetry => 'Pokušaj ponovo';

  @override
  String get commonCancel => 'Otkaži';

  @override
  String get commonConfirm => 'Potvrdi';

  @override
  String get commonContinue => 'Nastavi';

  @override
  String get commonBack => 'Nazad';

  @override
  String get commonClose => 'Zatvori';

  @override
  String get commonSave => 'Sačuvaj';

  @override
  String get commonDone => 'Gotovo';

  @override
  String get commonSkip => 'Preskoči';

  @override
  String get commonNext => 'Dalje';

  @override
  String get commonPrevious => 'Prethodni';

  @override
  String get commonSearch => 'Pretraži';

  @override
  String get commonClear => 'Očisti';

  @override
  String get commonRefresh => 'Osvježi';

  @override
  String get commonFilter => 'Filtriraj';

  @override
  String get commonAll => 'Sve';

  @override
  String get commonFavorites => 'Omiljene';

  @override
  String get commonShowMore => 'Prikaži više';

  @override
  String get commonShowLess => 'Prikaži manje';

  @override
  String get commonYes => 'Da';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonOk => 'U redu';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get commonDelete => 'Obriši';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get commonRemove => 'Ukloni';

  @override
  String get commonEnable => 'Uključi';

  @override
  String get commonDisable => 'Isključi';

  @override
  String get commonPlaceholderNotice =>
      'Ovaj ekran će biti dopunjen u sljedećoj fazi razvoja.';

  @override
  String commonMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String commonHoursShort(int hours) {
    return '$hours h';
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
      other: '$count minuta',
      few: '$count minute',
      one: '$count minuta',
      zero: 'manje od minute',
    );
    return '$_temp0';
  }

  @override
  String commonStopsPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stanica',
      few: '$count stanice',
      one: '$count stanica',
      zero: '0 stanica',
    );
    return '$_temp0';
  }

  @override
  String commonTransfersPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presjedanja',
      few: '$count presjedanja',
      one: '$count presjedanje',
      zero: 'bez presjedanja',
    );
    return '$_temp0';
  }

  @override
  String commonBusesPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autobusa',
      few: '$count autobusa',
      one: '$count autobus',
      zero: 'nema autobusa',
    );
    return '$_temp0';
  }

  @override
  String commonUpdatedAgo(String time) {
    return 'Ažurirano prije $time';
  }

  @override
  String commonLastUpdatedAt(String time) {
    return 'Posljednje ažuriranje: $time';
  }

  @override
  String get commonJustNow => 'upravo sada';

  @override
  String get statusEarly => 'Ranije';

  @override
  String get statusOnTime => 'Na vrijeme';

  @override
  String get statusLate => 'Kasni';

  @override
  String get statusInfo => 'Info';

  @override
  String get statusWarning => 'Upozorenje';

  @override
  String get statusDisruption => 'Poremećaj';

  @override
  String get statusCancelled => 'Otkazano';

  @override
  String get statusDetour => 'Obilazak';

  @override
  String get statusOffline => 'Bez interneta';

  @override
  String get statusOnline => 'Povezano';

  @override
  String statusEarlyByMinutes(int minutes) {
    return '$minutes min ranije';
  }

  @override
  String statusLateByMinutes(int minutes) {
    return '+$minutes min kašnjenja';
  }

  @override
  String get statusArrivingNow => 'Stiže sada';

  @override
  String statusDepartingIn(int minutes) {
    return 'Polazak za $minutes min';
  }

  @override
  String get badgeOfflineTitle => 'Rad bez interneta';

  @override
  String get badgeOfflineBody => 'Prikazani su sačuvani redovi vožnje i karte.';

  @override
  String badgeOfflineLastSync(String time) {
    return 'Posljednja sinhronizacija: $time';
  }

  @override
  String get badgeSimulatedLabel => 'Simulirani podaci';

  @override
  String get badgeSimulatedTooltip =>
      'Pozicije i vremena uživo simuliraju se lokalno za testiranje i prikaz.';

  @override
  String get badgeSimulatedDisclaimer =>
      'Podaci uživo su u režimu simulacije. Vremena su informativna.';

  @override
  String get freshnessLive => 'Podaci uživo';

  @override
  String get freshnessSimulated => 'Simulirano uživo';

  @override
  String get freshnessCached => 'Sačuvano lokalno';

  @override
  String get freshnessStale => 'Moguće zastarjeli podaci';

  @override
  String get freshnessLiveDisabledFallback =>
      'Podaci uživo nisu dostupni, prikazan je red vožnje';

  @override
  String get occupancyLabel => 'Popunjenost';

  @override
  String get occupancyLow => 'Mnogo slobodnih mjesta';

  @override
  String get occupancyMedium => 'Umjereno popunjeno';

  @override
  String get occupancyHigh => 'Velika gužva';

  @override
  String get occupancyFull => 'Autobus je pun';

  @override
  String get occupancyUnknown => 'Popunjenost nije poznata';

  @override
  String get onboardingWelcomeTitle => 'Dobrodošli u M Mobilnost 2.0';

  @override
  String get onboardingWelcomeSubtitle =>
      'Vaš pristupačan i pouzdan vodič za gradske autobuse Marprom u Mariboru.';

  @override
  String get onboardingChooseLanguage => 'Odaberite jezik aplikacije';

  @override
  String get onboardingAccessibilityTitle => 'Podešavanja pristupačnosti';

  @override
  String get onboardingAccessibilitySubtitle =>
      'Prilagodite čitljivost i glasovne opcije sada ili bilo kada u Postavkama.';

  @override
  String get onboardingLocationTitle => 'Lokacija i privatnost';

  @override
  String get onboardingLocationSubtitle =>
      'Dozvolite GPS za najbliže stanice ili ručno izaberite stanicu u Mariboru bez GPS-a.';

  @override
  String get onboardingUseGps => 'Koristi GPS lokaciju';

  @override
  String get onboardingUseManualLocation => 'Ručni izbor stanice (bez GPS-a)';

  @override
  String get onboardingStartRiding => 'Započni vožnju';

  @override
  String get onboardingOpenGuide => 'Prvi put autobusom? Otvori vodič';

  @override
  String get guideTitle => 'Prvi put autobusom';

  @override
  String get guideSubtitle =>
      'Kratki vodič u 5 koraka za bezbrižnu vožnju po Mariboru.';

  @override
  String guideCardProgress(int current, int total) {
    return 'Korak $current od $total';
  }

  @override
  String get guideCard1Title => '1. Pronađite stanicu i liniju';

  @override
  String get guideCard1Body =>
      'Provjerite najbližu stanicu na karti ili u listi linija. Svaki polazak prikazuje broj linije i smjer.';

  @override
  String get guideCard2Title => '2. Kupite ili pripremite kartu';

  @override
  String get guideCard2Body =>
      'Kartu možete kupiti u dijelu Karte. Pri ulasku je otvorite kako bi se svjetlina ekrana pojačala za skeniranje QR koda.';

  @override
  String get guideCard3Title => '3. Uđite na prednja vrata';

  @override
  String get guideCard3Body =>
      'Kada autobus prilazi, jasno dajte znak vozaču. Uđite na prednja vrata i potvrdite kartu.';

  @override
  String get guideCard4Title => '4. Pratite vožnju uživo';

  @override
  String get guideCard4Body =>
      'U praćenju uživo vidite sljedeće stanice, procijenjeni dolazak i obavještenje prije izlaska.';

  @override
  String get guideCard5Title => '5. Izlazak i presjedanje';

  @override
  String get guideCard5Body =>
      'Prije svoje stanice pritisnite tipku STOP. Kod presjedanja obratite pažnju na upozorenje o kratkom vremenu.';

  @override
  String get guideFinishCta => 'Razumijem, krenimo';

  @override
  String get homeGreeting => 'Kuda idemo danas?';

  @override
  String get homeSearchHint => 'Unesite odredište, stanicu ili liniju...';

  @override
  String get homeFavoriteStops => 'Omiljene stanice';

  @override
  String get homeNearbyStops => 'Najbliže stanice';

  @override
  String get homeQuickActions => 'Brze opcije';

  @override
  String get homeActiveTicket => 'Aktivna karta';

  @override
  String get homeNoActiveTicket => 'Trenutno nemate aktivnu kartu';

  @override
  String get homeNearestStopAction => 'Najbliža stanica';

  @override
  String get homePlanTripAction => 'Planiraj rutu';

  @override
  String get homeBuyTicketAction => 'Kupi kartu';

  @override
  String get homeLinesAction => 'Linije i red vožnje';

  @override
  String get homeGuideAction => 'Prvi put autobusom';

  @override
  String get homeAskMarpromAction => 'Pitaj Marprom';

  @override
  String get askTitle => 'Pitaj Marprom';

  @override
  String get askSubtitle => 'Brzi pomoćnik za linije, polaske i karte';

  @override
  String get askInputHint => 'Pitajte npr. Kada ide sljedeći autobus 6?';

  @override
  String get askSend => 'Pošalji';

  @override
  String get askVoicePrompt => 'Slušam...';

  @override
  String get askSample1 => 'Kada ide sljedeći autobus sa Glavnog trga?';

  @override
  String get askSample2 => 'Koja je karta najpovoljnija za danas?';

  @override
  String get askSample3 => 'Ima li danas poremećaja ili obilazaka?';

  @override
  String get askSample4 => 'Gdje je najbliža autobuska stanica?';

  @override
  String get askClearChat => 'Očisti razgovor';

  @override
  String get askDisclaimer =>
      'Odgovori koriste lokalni red vožnje Marprom i simulaciju uživo.';

  @override
  String get askNoMatch =>
      'Nemam tačan odgovor na to pitanje. Pokušajte pitati za liniju, stanicu, kartu ili obavještenja.';

  @override
  String get linesTitle => 'Linije i red vožnje';

  @override
  String get linesSearchHint => 'Pretraži liniju ili krajnju stanicu...';

  @override
  String linesBadge(String code) {
    return 'Linija $code';
  }

  @override
  String get linesDirectionLabel => 'Smjer';

  @override
  String get linesSwapDirection => 'Obrni smjer';

  @override
  String get linesScheduleWeekday => 'Radni dan';

  @override
  String get linesScheduleSaturday => 'Subota';

  @override
  String get linesScheduleSunday => 'Nedjelja / praznik';

  @override
  String get linesFirstBus => 'Prvi polazak';

  @override
  String get linesLastBus => 'Posljednji polazak';

  @override
  String get linesLowFloor => 'Niskopodni autobus';

  @override
  String get linesFavoriteAdd => 'Dodaj u omiljene';

  @override
  String get linesFavoriteRemove => 'Ukloni iz omiljenih';

  @override
  String get linesNoDepartures => 'Za odabrani dan više nema polazaka.';

  @override
  String get mapTitle => 'Karta stanica';

  @override
  String get mapSwitchToList => 'Lista';

  @override
  String get mapSwitchToMap => 'Karta';

  @override
  String get mapSearchHint => 'Pretraži stanicu ili ulicu...';

  @override
  String get mapCenterOnMe => 'Moja lokacija';

  @override
  String get mapManualCenter => 'Centar Maribora';

  @override
  String get mapFilterAccessible => 'Pristup bez stepenica';

  @override
  String get mapFilterActiveBuses => 'Autobusi uživo';

  @override
  String get mapStopDetailsOpen => 'Otvori polaske stanice';

  @override
  String get stopTitle => 'Stanica';

  @override
  String stopPlatform(String platform) {
    return 'Peron $platform';
  }

  @override
  String get stopUpcomingDepartures => 'Sljedeći polasci';

  @override
  String get stopAmenitiesTitle => 'Oprema stanice';

  @override
  String get stopAmenityShelter => 'Nadstrešnica';

  @override
  String get stopAmenityBench => 'Klupa';

  @override
  String get stopAmenityTactile => 'Taktilne oznake';

  @override
  String get stopAmenityStepFree => 'Pristup bez stepenica';

  @override
  String get stopAmenityDisplay => 'Digitalni ekran';

  @override
  String get stopNoDepartures => 'Nema planiranih polazaka u narednim satima.';

  @override
  String get trackerTitle => 'Praćenje uživo';

  @override
  String get trackerFollowBus => 'Prati autobus';

  @override
  String get trackerNextStop => 'Sljedeća stanica';

  @override
  String get trackerStopsRemaining => 'Preostale stanice';

  @override
  String get trackerEta => 'Procijenjeni dolazak';

  @override
  String trackerScheduledTime(String time) {
    return 'Po redu vožnje: $time';
  }

  @override
  String get trackerNotifyMe => 'Obavijesti me';

  @override
  String get trackerNotifyCancel => 'Otkaži podsjetnik';

  @override
  String get trackerNotifyActive =>
      'Podsjetnik je aktivan: dobićete obavijest prije dolaska.';

  @override
  String get trackerNotifyPrompt =>
      'Izaberite kada želite obavijest prije dolaska autobusa.';

  @override
  String get trackerAdviceEarlyTitle => 'Autobus ide ispred reda vožnje';

  @override
  String trackerAdviceEarlyBody(int minutes) {
    return 'Autobus je $minutes min ranije. Krenite ranije prema stanici ili provjerite sljedeći polazak.';
  }

  @override
  String get trackerAdviceOnTimeTitle => 'Autobus ide po redu vožnje';

  @override
  String get trackerAdviceOnTimeBody => 'Očekujte dolazak u planirano vrijeme.';

  @override
  String get trackerAdviceLateTitle => 'Autobus kasni';

  @override
  String trackerAdviceLateBody(int minutes) {
    return 'Autobus kasni $minutes min. Možete sačekati na stanici ili ispod provjeriti drugu liniju.';
  }

  @override
  String get trackerAdviceReviewAlternatives => 'Provjeri alternative';

  @override
  String get planTitle => 'Planer puta';

  @override
  String get planOriginLabel => 'Polazište';

  @override
  String get planDestinationLabel => 'Odredište';

  @override
  String get planCurrentLocation => 'Trenutna lokacija';

  @override
  String get planSwap => 'Zamijeni polazište i odredište';

  @override
  String get planLeaveNow => 'Polazak sada';

  @override
  String get planDepartAt => 'Polazak u';

  @override
  String get planArriveBy => 'Dolazak do';

  @override
  String get planAccessibleOnly => 'Samo rute bez stepenica';

  @override
  String get planFewerTransfers => 'Manje presjedanja';

  @override
  String get planFindRoutes => 'Pronađi rute';

  @override
  String get planTightTransferTitle => 'Kratko presjedanje';

  @override
  String planTightTransferBody(int minutes) {
    return 'Za presjedanje imate samo $minutes min. Ako prvi autobus malo zakasni, možete propustiti vezu.';
  }

  @override
  String get planWhatDoINextTitle => 'Šta sada da uradim?';

  @override
  String planStepWalkTo(String stop, String distance) {
    return 'Pješačite do stanice $stop ($distance)';
  }

  @override
  String planStepBoardLine(String line, String direction) {
    return 'Uđite u liniju $line u smjeru $direction';
  }

  @override
  String planStepRideStops(String stops, String stop) {
    return 'Vozite se $stops do stanice $stop';
  }

  @override
  String planStepTransferAt(String stop) {
    return 'Presjednite na stanici $stop';
  }

  @override
  String planStepGetOffAt(String stop) {
    return 'Siđite na stanici $stop';
  }

  @override
  String get planStepArrived => 'Stigli ste na odredište.';

  @override
  String get nearestStopTitle => 'Najbliža stanica';

  @override
  String nearestStopDistance(String distance) {
    return 'Udaljenost: $distance';
  }

  @override
  String nearestStopWalkTime(int minutes) {
    return 'Oko $minutes min hoda';
  }

  @override
  String get nearestStopNextBus => 'Sljedeći polazak';

  @override
  String get nearestStopUseManual => 'Izaberi stanicu ručno';

  @override
  String get ticketsTitle => 'Moje karte';

  @override
  String get ticketsActiveTab => 'Aktivne';

  @override
  String get ticketsHistoryTab => 'Prethodne';

  @override
  String get ticketsBuyButton => 'Kupi kartu';

  @override
  String get ticketsShopTitle => 'Kupovina karata';

  @override
  String get ticketsCheckoutTitle => 'Plaćanje';

  @override
  String get ticketsViewTitle => 'Važeća karta';

  @override
  String get ticketsZoneMaribor => 'Zona Maribor';

  @override
  String ticketsValidUntil(String time) {
    return 'Važi do $time';
  }

  @override
  String get ticketsQrHint => 'Prislonite QR kod validatoru u autobusu.';

  @override
  String get ticketsBrightnessBoosted =>
      'Svjetlina ekrana je privremeno pojačana radi lakšeg skeniranja.';

  @override
  String get ticketsNfcStubTitle => 'Beskontaktna potvrda (NFC)';

  @override
  String get ticketsNfcStubBody =>
      'Simulirana NFC potvrda pri ulasku. Prislonite telefon čitaču.';

  @override
  String get ticketsNfcTapToSimulate => 'Simuliraj NFC dodir';

  @override
  String get ticketsNfcValidated => 'Karta je uspješno potvrđena.';

  @override
  String get ticketsQuantity => 'Količina';

  @override
  String get ticketsTotalPrice => 'Ukupno';

  @override
  String get ticketsPayNow => 'Plati sada';

  @override
  String get ticketsPurchaseSuccess =>
      'Karta je kupljena i spremna za upotrebu.';

  @override
  String get ticketsMinorTitle => 'Potvrda roditelja ili staratelja';

  @override
  String get ticketsMinorUnder16Warning =>
      'Osobe mlađe od 16 godina moraju imati potvrdu roditelja ili staratelja za kupovinu.';

  @override
  String get ticketsMinorUnder18Notice =>
      'Maloljetne osobe od 16 do 18 godina moraju potvrditi saglasnost za digitalnu kupovinu.';

  @override
  String get ticketsMinorGuardianConfirm =>
      'Potvrđujem da imam saglasnost roditelja ili staratelja.';

  @override
  String get ticketsMinorGuardianEmail => 'E-pošta roditelja ili staratelja';

  @override
  String get paymentsTitle => 'Načini plaćanja';

  @override
  String get paymentsAddMethod => 'Dodaj način plaćanja';

  @override
  String get paymentsDefaultBadge => 'Podrazumijevano';

  @override
  String get paymentsSimulatedNotice =>
      'Svi tokovi plaćanja su u ovom prototipu lokalno simulirani.';

  @override
  String get accountTitle => 'Nalog';

  @override
  String get accountGuestMode => 'Režim gosta';

  @override
  String get accountSignIn => 'Prijava';

  @override
  String get accountSignOut => 'Odjava';

  @override
  String get accountManagePayments => 'Upravljaj plaćanjima';

  @override
  String get accountGdprTitle => 'Privatnost i saglasnosti (GDPR)';

  @override
  String get accountGdprDescription =>
      'Upravljajte saglasnostima za analitiku, obavijesti i lokalne podatke.';

  @override
  String get accountGdprAnalytics => 'Anonimna analiza korištenja';

  @override
  String get accountGdprNotifications => 'Obavijesti o kašnjenjima';

  @override
  String get accountGdprExport => 'Izvezi moje podatke';

  @override
  String get accountGdprDelete => 'Obriši lokalne podatke';

  @override
  String get accountGdprPrivacyLink => 'Politika privatnosti';

  @override
  String get noticesTitle => 'Obavijesti i pametni podsjetnici';

  @override
  String get noticesAllTab => 'Sve obavijesti';

  @override
  String get noticesDisruptionsTab => 'Poremećaji';

  @override
  String get noticesSmartAlertsTitle => 'Pametni podsjetnici';

  @override
  String get noticesSmartAlertsDesc =>
      'Primite upozorenje prije dolaska autobusa, kod poremećaja na omiljenoj liniji i prije isteka karte.';

  @override
  String get noticesMarkAllRead => 'Označi sve kao pročitano';

  @override
  String get noticesEmpty => 'Trenutno nema novih obavijesti.';

  @override
  String noticesAffectedLines(String lines) {
    return 'Pogođene linije: $lines';
  }

  @override
  String get settingsTitle => 'Postavke';

  @override
  String get settingsSectionAppearance => 'Izgled';

  @override
  String get settingsSectionLanguage => 'Jezik';

  @override
  String get settingsSectionAccessibility => 'Pristupačnost i govor';

  @override
  String get settingsSectionData => 'Podaci i lokacija';

  @override
  String get settingsSectionPrivacy => 'Privatnost';

  @override
  String get settingsSectionUsability => 'Testiranje upotrebljivosti i demo';

  @override
  String get settingsThemeMode => 'Tema boja';

  @override
  String get settingsThemeSystem => 'Sistemska';

  @override
  String get settingsThemeLight => 'Svijetla';

  @override
  String get settingsThemeDark => 'Tamna';

  @override
  String get settingsThemeHighContrast => 'Visoki kontrast (AAA)';

  @override
  String get settingsLanguage => 'Jezik aplikacije';

  @override
  String get settingsExtraLargeText => 'Veoma veliki tekst (do 200%)';

  @override
  String get settingsExtraLargeTextDesc =>
      'Povećava font u cijeloj aplikaciji radi bolje čitljivosti.';

  @override
  String get settingsReducedMotion => 'Smanjeni pokreti';

  @override
  String get settingsReducedMotionDesc =>
      'Isključuje animacije i prelaze ekrana.';

  @override
  String get settingsReadAloud => 'Čitanje naglas (TTS)';

  @override
  String get settingsReadAloudDesc =>
      'Čita ključna uputstva, polaske i upozorenja.';

  @override
  String get settingsVoiceInput => 'Glasovni unos';

  @override
  String get settingsVoiceInputDesc =>
      'Omogućava glasovnu pretragu stanica i pitanja.';

  @override
  String get settingsHapticAlerts => 'Haptička upozorenja';

  @override
  String get settingsHapticAlertsDesc =>
      'Različiti obrasci vibracije za dolazak, kašnjenje, istek karte i poremećaje.';

  @override
  String get settingsSoundAlerts => 'Opcioni zvučni signali';

  @override
  String get settingsSoundAlertsDesc =>
      'Reprodukuje kratak zvuk kod važnih obavijesti.';

  @override
  String get settingsShowDataSource => 'Prikaži izvor podataka';

  @override
  String get settingsShowDataSourceDesc =>
      'Prikazuje jesu li podaci uživo, simulirani ili lokalno sačuvani.';

  @override
  String get settingsUseSimulatedLive => 'Simulirani podaci uživo';

  @override
  String get settingsUseSimulatedLiveDesc =>
      'Koristi deterministički lokalni simulator vozila Marprom.';

  @override
  String get settingsSimulationSeed => 'Sjeme simulacije';

  @override
  String get settingsLocationManual => 'Ručni režim lokacije';

  @override
  String get settingsLocationManualDesc =>
      'Koristi odabranu stanicu umjesto GPS senzora.';

  @override
  String get settingsUsabilityTestMode => 'Režim testiranja upotrebljivosti';

  @override
  String get settingsUsabilityTestModeDesc =>
      'Prikazuje brze alate za testiranje scenarija, reset uvoda i pregled stanja.';

  @override
  String get settingsResetOnboarding => 'Resetuj uvodni ekran';

  @override
  String get settingsOpenGuide => 'Otvori vodič Prvi put autobusom';

  @override
  String get a11yBackButton => 'Nazad na prethodni ekran';

  @override
  String get a11yCloseButton => 'Zatvori';

  @override
  String get a11ySearchField => 'Polje za pretragu';

  @override
  String get a11yVoiceSearchButton => 'Glasovna pretraga';

  @override
  String get a11yReadAloudButton => 'Pročitaj naglas';

  @override
  String get a11yFavoriteToggle => 'Preklopi omiljeno';

  @override
  String get a11yQrCode => 'QR kod karte za skeniranje na validatoru';

  @override
  String a11yLineBadge(String code) {
    return 'Autobuska linija $code';
  }

  @override
  String a11yOccupancyBar(String level) {
    return 'Popunjenost autobusa: $level';
  }

  @override
  String a11yStatusChip(String label) {
    return 'Status: $label';
  }

  @override
  String get a11yOfflineBanner => 'Obavijest o radu bez interneta';

  @override
  String get a11ySimulatedBadge => 'Oznaka simuliranih podataka';

  @override
  String get a11yProfileButton => 'Otvori nalog';

  @override
  String get a11yNoticesButton => 'Otvori obavijesti';

  @override
  String get a11ySettingsButton => 'Otvori postavke';

  @override
  String get a11ySwapStations => 'Zamijeni početnu i krajnju stanicu';

  @override
  String homeNextBusSummary(
    String destination,
    String line,
    int minutes,
    int meters,
  ) {
    return 'Sljedeći autobus za $destination: linija $line za $minutes min, $meters m od vas';
  }

  @override
  String get homeNoFavoriteStops =>
      'Još nemate omiljenih stanica. Dodajte ih sa karte ili iz reda vožnje.';

  @override
  String get homeNextDepartures => 'Sljedeći polasci';

  @override
  String get homeActiveDisruptionAlert =>
      'Upozorenje o poremećaju na vašoj omiljenoj liniji';

  @override
  String get linesFollowBusLive => 'Prati autobus uživo';

  @override
  String get linesOccupancyBySegment => 'Popunjenost po dionicama rute';

  @override
  String linesDirectionTo(String destination) {
    return 'Smjer: $destination';
  }

  @override
  String get stopAddToFavorites => 'Dodaj u omiljene';

  @override
  String get stopRemoveFromFavorites => 'Ukloni iz omiljenih';

  @override
  String get stopPlanFromHere => 'Planiraj put odavde';

  @override
  String get stopSelectDay => 'Odaberi dan';

  @override
  String get stopAllLines => 'Sve linije';

  @override
  String get stopLiveAndScheduledNote =>
      'Vremena spajaju kašnjenja uživo sa stalnim redom vožnje.';

  @override
  String get mapLocationDeniedTitle => 'Pristup lokaciji nije dostupan';

  @override
  String get mapLocationDeniedBody =>
      'Aplikaciju i dalje možete koristiti u potpunosti ručnim izborom početne stanice.';

  @override
  String get mapSelectManualStop => 'Odaberi početnu stanicu';

  @override
  String mapFollowingLine(String code) {
    return 'Prikaz rute za liniju $code';
  }

  @override
  String get mapTapStopHint =>
      'Dodirnite stanicu za polaske ili autobus za prikaz njegove trase.';

  @override
  String get mapNoNearbyStops => 'U ovom području nisu pronađene stanice.';

  @override
  String mapListDistance(String distance) {
    return '$distance daleko';
  }

  @override
  String get trackerSelectLineOrStop =>
      'Izaberite liniju ili stanicu za praćenje uživo';

  @override
  String trackerDistanceAndEta(String distance, int minutes) {
    return '$distance daleko • oko $minutes min';
  }

  @override
  String trackerNotifyMinutesAway(int minutes) {
    return 'Obavijesti $minutes min prije dolaska';
  }

  @override
  String get trackerNoActiveBuses =>
      'Na ovoj liniji trenutno nema aktivnih autobusa.';

  @override
  String trackerEarlyActionTip(int minutes, int arriveEarlyMin) {
    return 'Ovaj autobus je $minutes min ranije i može krenuti prije reda vožnje. Budite na stanici $arriveEarlyMin min ranije.';
  }

  @override
  String trackerLateActionTip(int minutes, String time) {
    return 'Ovaj autobus kasni $minutes min. Očekuje se u $time.';
  }

  @override
  String get trackerNextStepCardTitle => 'Sljedeći korak na vašem putu';

  @override
  String trackerGetOffNextStop(String stop) {
    return 'Siđite na sljedećoj stanici: $stop';
  }

  @override
  String trackerAlertFiredBanner(String line, int minutes, String stop) {
    return 'Autobus $line je $minutes min udaljen od $stop!';
  }

  @override
  String get planNoResultsTitle => 'Ruta nije pronađena';

  @override
  String get planNoResultsBody =>
      'Za ovo vrijeme nije pronađena odgovarajuća autobuska veza. Pokušajte prošetati do čvorišta ili sačekati sljedeći polazak.';

  @override
  String get planTryWalkFurther => 'Traži s dužim pješačenjem';

  @override
  String get planTryWaitNext => 'Provjeri kasnije polaske';

  @override
  String planWalkTimeAndDistance(int minutes, String distance) {
    return 'Hod $minutes min ($distance)';
  }

  @override
  String planDataReliability(String source) {
    return 'Pouzdanost podataka: $source';
  }

  @override
  String planTransferWaitMinutes(int minutes, String stop) {
    return 'Čekanje presjedanja: $minutes min na $stop';
  }

  @override
  String planOptionSummary(
    int totalMin,
    String transfers,
    String walkDistance,
  ) {
    return '$totalMin min • $transfers • $walkDistance hoda';
  }

  @override
  String get planSelectOrigin => 'Izaberi polazište';

  @override
  String get planSelectDestination => 'Izaberi odredište';

  @override
  String get nearestStopGoalHint =>
      'Pronađite najbližu stanicu s autobusom do vašeg odredišta';

  @override
  String get nearestStopSortedByArrival =>
      'Sortirano po najranijem vremenu dolaska';

  @override
  String nearestStopArrivesAt(String time) {
    return 'Dolazi u $time';
  }

  @override
  String get ticketsAuthRequiredTitle => 'Za kupovinu je potreban nalog';

  @override
  String get ticketsAuthRequiredBody =>
      'Vrste karata možete pregledati kao gost. Prijavite se ili kreirajte besplatan testni nalog za kupovinu i čuvanje.';

  @override
  String get ticketsStepChoose => '1. Karta';

  @override
  String get ticketsStepPayment => '2. Plaćanje';

  @override
  String get ticketsStepConfirm => '3. Potvrda';

  @override
  String ticketsValidFromUntil(String from, String until) {
    return 'Važi od $from do $until';
  }

  @override
  String get ticketsStartNow => 'Važi odmah (preporučeno)';

  @override
  String get ticketsStartLater => 'Izaberi vrijeme početka';

  @override
  String get ticketsTabUpcoming => 'Nadolazeće';

  @override
  String get ticketsTabExpired => 'Istekle';

  @override
  String ticketsDriverFallbackCode(String code) {
    return 'Rezervni kod za vozača: $code';
  }

  @override
  String get ticketsLiveClockNote =>
      'Sat uživo sprečava zloupotrebu snimaka ekrana';

  @override
  String get ticketsNfcComingSoon => 'NFC kartica u aplikaciji uskoro stiže';

  @override
  String get ticketsDemoPaymentNotice =>
      'Demo plaćanje — pravi novac se ne naplaćuje';

  @override
  String get ticketsNoActiveTickets => 'Još nemate aktivnih karata.';

  @override
  String get ticketsNoUpcomingTickets => 'Nema nadolazećih karata.';

  @override
  String get ticketsNoExpiredTickets => 'Nema isteklih karata.';

  @override
  String ticketsRemainingTime(String time) {
    return 'Preostalo: $time';
  }

  @override
  String get paymentsCard => 'Platna kartica';

  @override
  String get paymentsGooglePay => 'Google Pay';

  @override
  String get paymentsApplePay => 'Apple Pay';

  @override
  String get paymentsBankTransfer => 'Bankovni transfer / e-bankarstvo';

  @override
  String get paymentsMobilePay => 'Mobilno plaćanje';

  @override
  String get paymentsCardBrandLabel => 'Brend kartice (npr. Visa)';

  @override
  String get paymentsLast4Label => 'Samo posljednje 4 cifre (demo)';

  @override
  String get paymentsLast4Validation => 'Unesite tačno 4 cifre';

  @override
  String get paymentsSetDefault => 'Postavi kao podrazumijevano';

  @override
  String get accountSignUp => 'Kreiraj nalog';

  @override
  String get accountPasswordReset => 'Resetuj lozinku';

  @override
  String get accountDeleteAccount => 'Obriši moj nalog i podatke';

  @override
  String get accountDeleteConfirmTitle =>
      'Obrisati nalog i sve lokalne podatke?';

  @override
  String get accountDeleteConfirmBody =>
      'Ovo briše vaš testni profil, sačuvane karte, platne kartice i postavke s ovog uređaja.';

  @override
  String get accountNameLabel => 'Ime i prezime';

  @override
  String get accountEmailLabel => 'E-adresa';

  @override
  String get accountPasswordLabel => 'Lozinka';

  @override
  String get accountDobLabel => 'Datum rođenja';

  @override
  String get accountDemoAccountHint =>
      'Demo korisnik: demo@marprom.si / demo1234';

  @override
  String get accountYouthEligible => 'Pravo na omladinsku / studentsku tarifu';

  @override
  String get accountSeniorEligible => 'Pravo na penzionersku tarifu';

  @override
  String accountResetSent(String email) {
    return 'Testni link za reset lozinke pripremljen za $email.';
  }

  @override
  String get accountSaveProfile => 'Sačuvaj profil';

  @override
  String get onboardingConsentLocation =>
      'Dozvoli lokaciju dok je aplikacija otvorena radi pronalaženja najbližih stanica (ne napušta uređaj u testnom režimu)';

  @override
  String get onboardingConsentNotifications =>
      'Dozvoli obavijesti o dolasku, kašnjenju i isteku karte';

  @override
  String get onboardingConsentAnalytics =>
      'Opciona anonimna statistika korištenja (podrazumijevano isključeno)';

  @override
  String get onboardingAccountOptionalNote =>
      'Nalog je sada opcionalan i potreban tek kasnije pri kupovini karata.';

  @override
  String get noticesTriggerAlternative => 'Pronađi drugu rutu';

  @override
  String get noticesSmartBusArriving => 'Upozorenje za skori dolazak autobusa';

  @override
  String get noticesSmartLineDelayed =>
      'Upozorenje za kašnjenje omiljene linije';

  @override
  String get noticesSmartTicketExpiring => 'Upozorenje pred istek karte';

  @override
  String get noticesPreviewVibration =>
      'Testiraj vizuelno i vibracijsko upozorenje';

  @override
  String get settingsClearLocalData => 'Očisti lokalnu predmemoriju';

  @override
  String get settingsClearLocalDataDone => 'Lokalna predmemorija je očišćena.';

  @override
  String get settingsAboutTitle => 'O aplikaciji M Mobilnost 2.0';

  @override
  String get settingsAboutBody =>
      'Pristupačan jedinstveni Marprom prototip za javni prevoz i karte u Mariboru. Simulirani podaci uživo su jasno označeni.';

  @override
  String get settingsUsabilityStart => 'Pokreni mjereni scenario';

  @override
  String get settingsUsabilityFinish => 'Završi scenario';

  @override
  String get settingsUsabilityRecordError => 'Zabilježi grešku (+1)';

  @override
  String get settingsUsabilityExportCsv => 'Izvezi CSV';

  @override
  String get settingsUsabilityExportJson => 'Izvezi JSON';

  @override
  String settingsUsabilitySummary(int seconds, int taps, int errors) {
    return 'Vrijeme: $seconds s • Dodiri: $taps • Greške: $errors';
  }
}
