// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class AppLocalizationsSl extends AppLocalizations {
  AppLocalizationsSl([String locale = 'sl']) : super(locale);

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
  String get navHome => 'Domov';

  @override
  String get navMap => 'Zemljevid';

  @override
  String get navPlan => 'Načrtuj';

  @override
  String get navTickets => 'Vozovnice';

  @override
  String get navLines => 'Linije';

  @override
  String get navNotices => 'Obvestila';

  @override
  String get navSettings => 'Nastavitve';

  @override
  String get navAccount => 'Račun';

  @override
  String get navMore => 'Več';

  @override
  String get commonLoading => 'Nalaganje ...';

  @override
  String get commonEmpty => 'Ni podatkov za prikaz.';

  @override
  String get commonErrorTitle => 'Prišlo je do napake';

  @override
  String get commonErrorBody =>
      'Podatkov trenutno ni bilo mogoče naložiti. Preverite povezavo in poskusite znova.';

  @override
  String get commonRetry => 'Poskusi znova';

  @override
  String get commonCancel => 'Prekliči';

  @override
  String get commonConfirm => 'Potrdi';

  @override
  String get commonContinue => 'Nadaljuj';

  @override
  String get commonBack => 'Nazaj';

  @override
  String get commonClose => 'Zapri';

  @override
  String get commonSave => 'Shrani';

  @override
  String get commonDone => 'Končano';

  @override
  String get commonSkip => 'Preskoči';

  @override
  String get commonNext => 'Naprej';

  @override
  String get commonPrevious => 'Prejšnji';

  @override
  String get commonSearch => 'Išči';

  @override
  String get commonClear => 'Počisti';

  @override
  String get commonRefresh => 'Osveži';

  @override
  String get commonFilter => 'Filtriraj';

  @override
  String get commonAll => 'Vse';

  @override
  String get commonFavorites => 'Priljubljene';

  @override
  String get commonShowMore => 'Prikaži več';

  @override
  String get commonShowLess => 'Prikaži manj';

  @override
  String get commonYes => 'Da';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonOk => 'V redu';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get commonDelete => 'Izbriši';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get commonRemove => 'Odstrani';

  @override
  String get commonEnable => 'Omogoči';

  @override
  String get commonDisable => 'Onemogoči';

  @override
  String get commonPlaceholderNotice =>
      'Ta zaslon bo dopolnjen v naslednji fazi razvoja.';

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
      other: '$count minut',
      few: '$count minute',
      two: '$count minuti',
      one: '$count minuta',
      zero: 'manj kot minuto',
    );
    return '$_temp0';
  }

  @override
  String commonStopsPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count postajališč',
      few: '$count postajališča',
      two: '$count postajališči',
      one: '$count postajališče',
      zero: '0 postajališč',
    );
    return '$_temp0';
  }

  @override
  String commonTransfersPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prestopov',
      few: '$count prestopi',
      two: '$count prestopa',
      one: '$count prestop',
      zero: 'brez prestopanja',
    );
    return '$_temp0';
  }

  @override
  String commonBusesPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avtobusov',
      few: '$count avtobusi',
      two: '$count avtobusa',
      one: '$count avtobus',
      zero: 'ni avtobusov',
    );
    return '$_temp0';
  }

  @override
  String commonUpdatedAgo(String time) {
    return 'Posodobljeno pred $time';
  }

  @override
  String commonLastUpdatedAt(String time) {
    return 'Nazadnje posodobljeno: $time';
  }

  @override
  String get commonJustNow => 'pravkar';

  @override
  String get statusEarly => 'Zgodaj';

  @override
  String get statusOnTime => 'Točno';

  @override
  String get statusLate => 'Zamuda';

  @override
  String get statusInfo => 'Info';

  @override
  String get statusWarning => 'Opozorilo';

  @override
  String get statusDisruption => 'Motnja';

  @override
  String get statusCancelled => 'Odpovedano';

  @override
  String get statusDetour => 'Obvoz';

  @override
  String get statusOffline => 'Brez povezave';

  @override
  String get statusOnline => 'Povezano';

  @override
  String statusEarlyByMinutes(int minutes) {
    return '$minutes min zgodaj';
  }

  @override
  String statusLateByMinutes(int minutes) {
    return '+$minutes min zamude';
  }

  @override
  String get statusArrivingNow => 'Prihaja zdaj';

  @override
  String statusDepartingIn(int minutes) {
    return 'Odhod čez $minutes min';
  }

  @override
  String get badgeOfflineTitle => 'Delovanje brez povezave';

  @override
  String get badgeOfflineBody =>
      'Prikazani so predpomnjeni vozni redi in shranjene vozovnice.';

  @override
  String badgeOfflineLastSync(String time) {
    return 'Zadnja sinhronizacija: $time';
  }

  @override
  String get badgeSimulatedLabel => 'Simulirani podatki';

  @override
  String get badgeSimulatedTooltip =>
      'Prikazani so simulirani podatki v živo za namene predstavitve in testiranja.';

  @override
  String get badgeSimulatedDisclaimer =>
      'Viri v živo so v načinu simulacije. Časi so informativni.';

  @override
  String get freshnessLive => 'Podatki v živo';

  @override
  String get freshnessSimulated => 'Simulirano v živo';

  @override
  String get freshnessCached => 'Predpomnjeno';

  @override
  String get freshnessStale => 'Morda zastareli podatki';

  @override
  String get freshnessLiveDisabledFallback =>
      'Podatki v živo niso na voljo, prikazan je vozni red';

  @override
  String get occupancyLabel => 'Zasedenost';

  @override
  String get occupancyLow => 'Veliko prostih mest';

  @override
  String get occupancyMedium => 'Zmerno zasedeno';

  @override
  String get occupancyHigh => 'Zelo zasedeno';

  @override
  String get occupancyFull => 'Avtobus je poln';

  @override
  String get occupancyUnknown => 'Zasedenost ni znana';

  @override
  String get onboardingWelcomeTitle => 'Dobrodošli v M Mobilnost 2.0';

  @override
  String get onboardingWelcomeSubtitle =>
      'Vaš dostopen in zanesljiv vodnik za mestne avtobuse Marprom v Mariboru.';

  @override
  String get onboardingChooseLanguage => 'Izberite jezik aplikacije';

  @override
  String get onboardingAccessibilityTitle => 'Prilagoditve dostopnosti';

  @override
  String get onboardingAccessibilitySubtitle =>
      'Aplikacijo lahko prilagodite zdaj ali kadarkoli v nastavitvah.';

  @override
  String get onboardingLocationTitle => 'Lokacija in zasebnost';

  @override
  String get onboardingLocationSubtitle =>
      'Dovoli lokacijo za najbližja postajališča ali izberi ročni mariborski način brez GPS.';

  @override
  String get onboardingUseGps => 'Uporabi GPS lokacijo';

  @override
  String get onboardingUseManualLocation =>
      'Ročna izbira postajališča (brez GPS)';

  @override
  String get onboardingStartRiding => 'Začni z vožnjo';

  @override
  String get onboardingOpenGuide => 'Prvič z avtobusom? Odpri vodič';

  @override
  String get guideTitle => 'Prvič z avtobusom';

  @override
  String get guideSubtitle =>
      'Kratek vodnik v 5 korakih za brezskrbno vožnjo po Mariboru.';

  @override
  String guideCardProgress(int current, int total) {
    return 'Korak $current od $total';
  }

  @override
  String get guideCard1Title => '1. Poiščite postajališče in linijo';

  @override
  String get guideCard1Body =>
      'Preverite najbližje postajališče na zemljevidu ali na seznamu linij. Vsi odhodi kažejo smer vožnje in številko linije.';

  @override
  String get guideCard2Title => '2. Kupite ali pripravite vozovnico';

  @override
  String get guideCard2Body =>
      'Vozovnico lahko kupite v zavihku Vozovnice. Ob vstopu jo pripravite na zaslonu s povečano svetlostjo za hitro odčitavanje QR kode.';

  @override
  String get guideCard3Title => '3. Vstopite pri prvih vratih';

  @override
  String get guideCard3Body =>
      'Ko avtobus prihaja, vozniku jasno nakažite željo po vstopu. Vstopite pri sprednjih vratih in potrdite vozovnico.';

  @override
  String get guideCard4Title => '4. Spremljajte vožnjo v živo';

  @override
  String get guideCard4Body =>
      'V sledilniku v živo vidite naslednja postajališča, predviden prihod in opozorilo pred izstopom.';

  @override
  String get guideCard5Title => '5. Izstop in prestopanje';

  @override
  String get guideCard5Body =>
      'Pred želenim postajališčem pritisnite gumb STOP. Pri prestopanju preverite opozorilo za kratek čas prestopa.';

  @override
  String get guideFinishCta => 'Razumem, začnimo';

  @override
  String get homeGreeting => 'Kam gremo danes?';

  @override
  String get homeSearchHint => 'Kam želite potovati ali katero linijo iščete?';

  @override
  String get homeFavoriteStops => 'Priljubljena postajališča';

  @override
  String get homeNearbyStops => 'Najbližja postajališča';

  @override
  String get homeQuickActions => 'Hitre možnosti';

  @override
  String get homeActiveTicket => 'Aktivna vozovnica';

  @override
  String get homeNoActiveTicket => 'Trenutno nimate aktivne vozovnice';

  @override
  String get homeNearestStopAction => 'Najbližja postaja';

  @override
  String get homePlanTripAction => 'Načrtuj pot';

  @override
  String get homeBuyTicketAction => 'Kupi vozovnico';

  @override
  String get homeLinesAction => 'Linije in vozni redi';

  @override
  String get homeGuideAction => 'Prvič z avtobusom';

  @override
  String get homeAskMarpromAction => 'Vprašaj Marprom';

  @override
  String get askTitle => 'Vprašaj Marprom';

  @override
  String get askSubtitle => 'Hiter pomočnik za linije, odhode in vozovnice';

  @override
  String get askInputHint => 'Vprašajte npr. Kdaj gre naslednji avtobus 6?';

  @override
  String get askSend => 'Pošlji';

  @override
  String get askVoicePrompt => 'Govori zdaj ...';

  @override
  String get askSample1 => 'Kdaj pelje naslednji avtobus z Glavnega trga?';

  @override
  String get askSample2 => 'Katera vozovnica je najugodnejša za danes?';

  @override
  String get askSample3 => 'Ali so danes kakšne motnje ali obvozi?';

  @override
  String get askSample4 => 'Kje je najbližje postajališče?';

  @override
  String get askClearChat => 'Počisti pogovor';

  @override
  String get askDisclaimer =>
      'Odgovori temeljijo na lokalnih podatkih Marprom in simulaciji v živo.';

  @override
  String get askNoMatch =>
      'Na to vprašanje nimam točnega odgovora. Poskusite vprašati o liniji, postajališču, vozovnici ali motnjah.';

  @override
  String get linesTitle => 'Linije in vozni redi';

  @override
  String get linesSearchHint => 'Išči linijo ali končno postajo ...';

  @override
  String linesBadge(String code) {
    return 'Linija $code';
  }

  @override
  String get linesDirectionLabel => 'Smer';

  @override
  String get linesSwapDirection => 'Obrni smer';

  @override
  String get linesScheduleWeekday => 'Delavnik';

  @override
  String get linesScheduleSaturday => 'Sobota';

  @override
  String get linesScheduleSunday => 'Nedelja / praznik';

  @override
  String get linesFirstBus => 'Prvi odhod';

  @override
  String get linesLastBus => 'Zadnji odhod';

  @override
  String get linesLowFloor => 'Nizkopodni avtobus';

  @override
  String get linesFavoriteAdd => 'Dodaj med priljubljene';

  @override
  String get linesFavoriteRemove => 'Odstrani iz priljubljenih';

  @override
  String get linesNoDepartures => 'Za izbrani dan ni več odhodov.';

  @override
  String get mapTitle => 'Zemljevid postajališč';

  @override
  String get mapSwitchToList => 'Seznam';

  @override
  String get mapSwitchToMap => 'Zemljevid';

  @override
  String get mapSearchHint => 'Išči postajališče ali ulico ...';

  @override
  String get mapCenterOnMe => 'Moja lokacija';

  @override
  String get mapManualCenter => 'Center Maribora';

  @override
  String get mapFilterAccessible => 'Dostopno za invalide';

  @override
  String get mapFilterActiveBuses => 'Avtobusi v živo';

  @override
  String get mapStopDetailsOpen => 'Odpri odhode postajališča';

  @override
  String get stopTitle => 'Postajališče';

  @override
  String stopPlatform(String platform) {
    return 'Peron $platform';
  }

  @override
  String get stopUpcomingDepartures => 'Prihajajoči odhodi';

  @override
  String get stopAmenitiesTitle => 'Oprema postajališča';

  @override
  String get stopAmenityShelter => 'Nadstrešnica';

  @override
  String get stopAmenityBench => 'Klop';

  @override
  String get stopAmenityTactile => 'Taktilne oznake';

  @override
  String get stopAmenityStepFree => 'Dostop brez stopnic';

  @override
  String get stopAmenityDisplay => 'Digitalni prikazovalnik';

  @override
  String get stopNoDepartures => 'V naslednjih urah ni načrtovanih odhodov.';

  @override
  String get trackerTitle => 'Sledenje v živo';

  @override
  String get trackerFollowBus => 'Sledi avtobusu';

  @override
  String get trackerNextStop => 'Naslednje postajališče';

  @override
  String get trackerStopsRemaining => 'Preostala postajališča';

  @override
  String get trackerEta => 'Predviden prihod';

  @override
  String trackerScheduledTime(String time) {
    return 'Po voznem redu: $time';
  }

  @override
  String get trackerNotifyMe => 'Obvesti me';

  @override
  String get trackerNotifyCancel => 'Prekliči opomnik';

  @override
  String get trackerNotifyActive =>
      'Opomnik nastavljen: obvestilo pred prihodom.';

  @override
  String get trackerNotifyPrompt =>
      'Izberite kdaj želite opozorilo pred prihodom avtobusa.';

  @override
  String get trackerAdviceEarlyTitle => 'Avtobus vozi pred voznim redom';

  @override
  String trackerAdviceEarlyBody(int minutes) {
    return 'Avtobus je $minutes min zgodaj. Če ste še na poti, preverite naslednji odhod ali se takoj odpravite na postajališče.';
  }

  @override
  String get trackerAdviceOnTimeTitle => 'Avtobus vozi po voznem redu';

  @override
  String get trackerAdviceOnTimeBody =>
      'Pričakujte prihod ob načrtovanem času.';

  @override
  String get trackerAdviceLateTitle => 'Avtobus ima zamudo';

  @override
  String trackerAdviceLateBody(int minutes) {
    return 'Avtobus zamuja $minutes min. Lahko počakate na postajališču ali spodaj preverite nadomestno povezavo.';
  }

  @override
  String get trackerAdviceReviewAlternatives => 'Preveri druge možnosti';

  @override
  String get planTitle => 'Načrtovalnik poti';

  @override
  String get planOriginLabel => 'Začetna točka';

  @override
  String get planDestinationLabel => 'Cilj';

  @override
  String get planCurrentLocation => 'Trenutna lokacija';

  @override
  String get planSwap => 'Zamenjaj začetek in cilj';

  @override
  String get planLeaveNow => 'Odhod zdaj';

  @override
  String get planDepartAt => 'Odhod ob';

  @override
  String get planArriveBy => 'Prihod do';

  @override
  String get planAccessibleOnly => 'Samo dostopne poti brez stopnic';

  @override
  String get planFewerTransfers => 'Manj prestopanj';

  @override
  String get planFindRoutes => 'Poišči povezave';

  @override
  String get planTightTransferTitle => 'Tesno prestopanje';

  @override
  String planTightTransferBody(int minutes) {
    return 'Za prestop imate le $minutes min. Ob manjši zamudi prvega avtobusa lahko povezavo zamudite.';
  }

  @override
  String get planWhatDoINextTitle => 'Kaj naj naredim zdaj?';

  @override
  String planStepWalkTo(String stop, String distance) {
    return 'Peš do postajališča $stop ($distance)';
  }

  @override
  String planStepBoardLine(String line, String direction) {
    return 'Vstopite na linijo $line v smeri $direction';
  }

  @override
  String planStepRideStops(String stops, String stop) {
    return 'Peljite se $stops do postajališča $stop';
  }

  @override
  String planStepTransferAt(String stop) {
    return 'Prestopite na postajališču $stop';
  }

  @override
  String planStepGetOffAt(String stop) {
    return 'Izstopite na postajališču $stop';
  }

  @override
  String get planStepArrived => 'Prispeli ste na cilj.';

  @override
  String get nearestStopTitle => 'Najbližje postajališče';

  @override
  String nearestStopDistance(String distance) {
    return 'Oddaljenost: $distance';
  }

  @override
  String nearestStopWalkTime(int minutes) {
    return 'Približno $minutes min hoje';
  }

  @override
  String get nearestStopNextBus => 'Naslednji odhod';

  @override
  String get nearestStopUseManual => 'Izberi postajališče ročno';

  @override
  String get ticketsTitle => 'Moje vozovnice';

  @override
  String get ticketsActiveTab => 'Aktivne';

  @override
  String get ticketsHistoryTab => 'Pretekle';

  @override
  String get ticketsBuyButton => 'Kupi vozovnico';

  @override
  String get ticketsShopTitle => 'Nakup vozovnic';

  @override
  String get ticketsCheckoutTitle => 'Zaključek nakupa';

  @override
  String get ticketsViewTitle => 'Veljavna vozovnica';

  @override
  String get ticketsZoneMaribor => 'Cona Maribor';

  @override
  String ticketsValidUntil(String time) {
    return 'Velja do $time';
  }

  @override
  String get ticketsQrHint => 'Prislonite QR kodo k validatorju na avtobusu.';

  @override
  String get ticketsBrightnessBoosted =>
      'Svetlost zaslona je začasno povečana za lažje branje kode.';

  @override
  String get ticketsNfcStubTitle => 'Brezstično potrjevanje (NFC)';

  @override
  String get ticketsNfcStubBody =>
      'Simulacija NFC potrditve ob vstopu. Prislonite telefon k čitalcu.';

  @override
  String get ticketsNfcTapToSimulate => 'Simuliraj NFC dotik';

  @override
  String get ticketsNfcValidated => 'Vozovnica je uspešno potrjena.';

  @override
  String get ticketsQuantity => 'Količina';

  @override
  String get ticketsTotalPrice => 'Skupaj za plačilo';

  @override
  String get ticketsPayNow => 'Plačaj zdaj';

  @override
  String get ticketsPurchaseSuccess =>
      'Vozovnica je kupljena in pripravljena za uporabo.';

  @override
  String get ticketsMinorTitle => 'Potrditev staršev ali skrbnika';

  @override
  String get ticketsMinorUnder16Warning =>
      'Osebe mlajše od 16 let potrebujejo potrditev starša ali zakonitega skrbnika za spletno plačilo.';

  @override
  String get ticketsMinorUnder18Notice =>
      'Mladoletne osebe med 16. in 18. letom morajo potrditi soglasje za digitalne nakupe.';

  @override
  String get ticketsMinorGuardianConfirm =>
      'Potrjujem, da imam soglasje starša ali skrbnika.';

  @override
  String get ticketsMinorGuardianEmail => 'E-pošta starša ali skrbnika';

  @override
  String get paymentsTitle => 'Načini plačila';

  @override
  String get paymentsAddMethod => 'Dodaj način plačila';

  @override
  String get paymentsDefaultBadge => 'Privzeto';

  @override
  String get paymentsSimulatedNotice =>
      'Vsi plačilni tokovi so v tem prototipu lokalno simulirani.';

  @override
  String get accountTitle => 'Uporabniški račun';

  @override
  String get accountGuestMode => 'Način gosta';

  @override
  String get accountSignIn => 'Prijava';

  @override
  String get accountSignOut => 'Odjava';

  @override
  String get accountManagePayments => 'Upravljaj plačila';

  @override
  String get accountGdprTitle => 'Zasebnost in soglasja (GDPR)';

  @override
  String get accountGdprDescription =>
      'Upravljajte svoja soglasja za analitiko, obvestila in obdelavo podatkov.';

  @override
  String get accountGdprAnalytics => 'Anonimna analitika uporabe';

  @override
  String get accountGdprNotifications => 'Potisna obvestila o zamudah';

  @override
  String get accountGdprExport => 'Izvozi moje podatke';

  @override
  String get accountGdprDelete => 'Izbriši lokalne podatke';

  @override
  String get accountGdprPrivacyLink => 'Politika zasebnosti';

  @override
  String get noticesTitle => 'Obvestila in pametni opomniki';

  @override
  String get noticesAllTab => 'Vsa obvestila';

  @override
  String get noticesDisruptionsTab => 'Motnje';

  @override
  String get noticesSmartAlertsTitle => 'Pametni opomniki';

  @override
  String get noticesSmartAlertsDesc =>
      'Prejmite opozorilo pred prihodom vašega avtobusa, ob motnjah na priljubljeni liniji in pred iztekom vozovnice.';

  @override
  String get noticesMarkAllRead => 'Označi vse kot prebrano';

  @override
  String get noticesEmpty => 'Trenutno ni novih obvestil.';

  @override
  String noticesAffectedLines(String lines) {
    return 'Prizadete linije: $lines';
  }

  @override
  String get settingsTitle => 'Nastavitve';

  @override
  String get settingsSectionAppearance => 'Videz';

  @override
  String get settingsSectionLanguage => 'Jezik';

  @override
  String get settingsSectionAccessibility => 'Dostopnost in glas';

  @override
  String get settingsSectionData => 'Podatki in lokacija';

  @override
  String get settingsSectionPrivacy => 'Zasebnost';

  @override
  String get settingsSectionUsability => 'Testiranje uporabnosti in demo';

  @override
  String get settingsThemeMode => 'Barvna tema';

  @override
  String get settingsThemeSystem => 'Sistemska';

  @override
  String get settingsThemeLight => 'Svetla';

  @override
  String get settingsThemeDark => 'Temna';

  @override
  String get settingsThemeHighContrast => 'Visok kontrast (AAA)';

  @override
  String get settingsLanguage => 'Jezik vmesnika';

  @override
  String get settingsExtraLargeText => 'Zelo veliko besedilo (do 200 %)';

  @override
  String get settingsExtraLargeTextDesc =>
      'Poveča pisavo v celotni aplikaciji za boljšo berljivost.';

  @override
  String get settingsReducedMotion => 'Zmanjšano gibanje';

  @override
  String get settingsReducedMotionDesc =>
      'Onemogoči animacije in prehode zaslonov.';

  @override
  String get settingsReadAloud => 'Glasno branje (TTS)';

  @override
  String get settingsReadAloudDesc =>
      'Prebere ključna navodila, odhode in opozorila.';

  @override
  String get settingsVoiceInput => 'Glasovni vnos';

  @override
  String get settingsVoiceInputDesc =>
      'Omogoči iskanje postajališč in vprašanj z glasom.';

  @override
  String get settingsHapticAlerts => 'Haptična opozorila';

  @override
  String get settingsHapticAlertsDesc =>
      'Različni vzorci tresljajev za prihod, zamudo, iztek vozovnice in motnje.';

  @override
  String get settingsSoundAlerts => 'Zvočna opozorila (izbirno)';

  @override
  String get settingsSoundAlertsDesc =>
      'Predvaja kratek zvočni signal ob pomembnih obvestilih.';

  @override
  String get settingsShowDataSource => 'Prikaži vir podatkov';

  @override
  String get settingsShowDataSourceDesc =>
      'Označi, ali so podatki v živo, simulirani ali predpomnjeni.';

  @override
  String get settingsUseSimulatedLive => 'Simulirani podatki v živo';

  @override
  String get settingsUseSimulatedLiveDesc =>
      'Uporabi deterministični lokalni simulator vozil Marprom.';

  @override
  String get settingsSimulationSeed => 'Seme simulacije';

  @override
  String get settingsLocationManual => 'Ročni način lokacije';

  @override
  String get settingsLocationManualDesc =>
      'Uporabi izbrano postajališče namesto senzorja GPS.';

  @override
  String get settingsUsabilityTestMode => 'Način testiranja uporabnosti';

  @override
  String get settingsUsabilityTestModeDesc =>
      'Prikaže hitra orodja za preizkušanje scenarijev, ponastavitev uvoda in preklop stanja.';

  @override
  String get settingsResetOnboarding => 'Ponastavi uvodni zaslon';

  @override
  String get settingsOpenGuide => 'Odpri vodnik Prvič z avtobusom';

  @override
  String get a11yBackButton => 'Nazaj na prejšnji zaslon';

  @override
  String get a11yCloseButton => 'Zapri';

  @override
  String get a11ySearchField => 'Polje za iskanje';

  @override
  String get a11yVoiceSearchButton => 'Glasovno iskanje';

  @override
  String get a11yReadAloudButton => 'Preberi na glas';

  @override
  String get a11yFavoriteToggle => 'Preklopi priljubljeno';

  @override
  String get a11yQrCode => 'QR koda vozovnice za odčitavanje na validatorju';

  @override
  String a11yLineBadge(String code) {
    return 'Avtobusna linija $code';
  }

  @override
  String a11yOccupancyBar(String level) {
    return 'Zasedenost avtobusa: $level';
  }

  @override
  String a11yStatusChip(String label) {
    return 'Status: $label';
  }

  @override
  String get a11yOfflineBanner => 'Opozorilo o delovanju brez povezave';

  @override
  String get a11ySimulatedBadge => 'Oznaka simuliranih podatkov';

  @override
  String get a11yProfileButton => 'Odpri uporabniški račun';

  @override
  String get a11yNoticesButton => 'Odpri obvestila';

  @override
  String get a11ySettingsButton => 'Odpri nastavitve';

  @override
  String get a11ySwapStations => 'Zamenjaj začetno in ciljno postajališče';

  @override
  String homeNextBusSummary(
    String destination,
    String line,
    int minutes,
    int meters,
  ) {
    return 'Naslednji avtobus proti $destination: linija $line čez $minutes min, $meters m stran';
  }

  @override
  String get homeNoFavoriteStops =>
      'Še nimate priljubljenih postajališč. Dodajte jih na zemljevidu ali voznem redu.';

  @override
  String get homeNextDepartures => 'Naslednji odhodi';

  @override
  String get homeActiveDisruptionAlert =>
      'Opozorilo o motnji na vaši priljubljeni liniji';

  @override
  String get linesFollowBusLive => 'Sledi avtobusu v živo';

  @override
  String get linesOccupancyBySegment => 'Zasedenost po odsekih poti';

  @override
  String linesDirectionTo(String destination) {
    return 'Smer: $destination';
  }

  @override
  String get stopAddToFavorites => 'Dodaj med priljubljene';

  @override
  String get stopRemoveFromFavorites => 'Odstrani iz priljubljenih';

  @override
  String get stopPlanFromHere => 'Načrtuj pot od tukaj';

  @override
  String get stopSelectDay => 'Izberi dan';

  @override
  String get stopAllLines => 'Vse linije';

  @override
  String get stopLiveAndScheduledNote =>
      'Časi združujejo zamude v živo s stalnim voznim redom.';

  @override
  String get mapLocationDeniedTitle => 'Dostop do lokacije ni na voljo';

  @override
  String get mapLocationDeniedBody =>
      'Aplikacijo lahko še vedno uporabljate v celoti z ročno izbiro začetnega postajališča.';

  @override
  String get mapSelectManualStop => 'Izberi začetno postajališče';

  @override
  String mapFollowingLine(String code) {
    return 'Prikaz poti za linijo $code';
  }

  @override
  String get mapTapStopHint =>
      'Dotaknite se postajališča za odhode ali avtobusa za ogled trase.';

  @override
  String get mapNoNearbyStops => 'Na tem območju ni najdenih postajališč.';

  @override
  String mapListDistance(String distance) {
    return '$distance stran';
  }

  @override
  String get trackerSelectLineOrStop =>
      'Izberite linijo ali postajališče za sledenje v živo';

  @override
  String trackerDistanceAndEta(String distance, int minutes) {
    return '$distance stran • približno $minutes min';
  }

  @override
  String trackerNotifyMinutesAway(int minutes) {
    return 'Obvesti $minutes min pred prihodom';
  }

  @override
  String get trackerNoActiveBuses =>
      'Na tej liniji trenutno ni aktivnih avtobusov.';

  @override
  String trackerEarlyActionTip(int minutes, int arriveEarlyMin) {
    return 'Ta avtobus je $minutes min zgodaj. Lahko odpelje pred voznim redom. Na postajališču bodite $arriveEarlyMin min prej.';
  }

  @override
  String trackerLateActionTip(int minutes, String time) {
    return 'Ta avtobus zamuja $minutes min. Predviden prihod ob $time.';
  }

  @override
  String get trackerNextStepCardTitle => 'Naslednji korak na vaši poti';

  @override
  String trackerGetOffNextStop(String stop) {
    return 'Izstopite na naslednjem postajališču: $stop';
  }

  @override
  String trackerAlertFiredBanner(String line, int minutes, String stop) {
    return 'Avtobus $line je $minutes min oddaljen od $stop!';
  }

  @override
  String get planNoResultsTitle => 'Povezava ni najdena';

  @override
  String get planNoResultsBody =>
      'Za izbrani čas ni ustrezne avtobusne povezave. Poskusite s hojo do vozlišča ali počakajte na naslednji odhod.';

  @override
  String get planTryWalkFurther => 'Išči z daljšo hojo';

  @override
  String get planTryWaitNext => 'Preveri poznejše odhode';

  @override
  String planWalkTimeAndDistance(int minutes, String distance) {
    return 'Hoja $minutes min ($distance)';
  }

  @override
  String planDataReliability(String source) {
    return 'Zanesljivost podatkov: $source';
  }

  @override
  String planTransferWaitMinutes(int minutes, String stop) {
    return 'Čakanje na prestop: $minutes min na $stop';
  }

  @override
  String planOptionSummary(
    int totalMin,
    String transfers,
    String walkDistance,
  ) {
    return '$totalMin min • $transfers • $walkDistance hoje';
  }

  @override
  String get planSelectOrigin => 'Izberi začetek';

  @override
  String get planSelectDestination => 'Izberi cilj';

  @override
  String get nearestStopGoalHint =>
      'Poiščite najbližje postajališče z avtobusom do vašega cilja';

  @override
  String get nearestStopSortedByArrival =>
      'Razvrščeno po najzgodnejšem prihodu';

  @override
  String nearestStopArrivesAt(String time) {
    return 'Prihod ob $time';
  }

  @override
  String get ticketsAuthRequiredTitle => 'Za nakup je potreben račun';

  @override
  String get ticketsAuthRequiredBody =>
      'Vrste vozovnic si lahko ogledate kot gost. Prijavite se ali ustvarite brezplačen testni račun za nakup in shranjevanje.';

  @override
  String get ticketsStepChoose => '1. Vozovnica';

  @override
  String get ticketsStepPayment => '2. Plačilo';

  @override
  String get ticketsStepConfirm => '3. Potrditev';

  @override
  String ticketsValidFromUntil(String from, String until) {
    return 'Velja od $from do $until';
  }

  @override
  String get ticketsStartNow => 'Velja takoj (priporočeno)';

  @override
  String get ticketsStartLater => 'Izberi čas začetka';

  @override
  String get ticketsTabUpcoming => 'Prihajajoče';

  @override
  String get ticketsTabExpired => 'Potekle';

  @override
  String ticketsDriverFallbackCode(String code) {
    return 'Nadomestna koda za voznika: $code';
  }

  @override
  String get ticketsLiveClockNote =>
      'Ura v živo preprečuje zlorabo posnetkov zaslona';

  @override
  String get ticketsNfcComingSoon =>
      'Kartica NFC v aplikaciji bo kmalu na voljo';

  @override
  String get ticketsDemoPaymentNotice =>
      'Demo plačilo — pravi denar se ne bremeni';

  @override
  String get ticketsNoActiveTickets => 'Trenutno nimate aktivnih vozovnic.';

  @override
  String get ticketsNoUpcomingTickets => 'Ni prihajajočih vozovnic.';

  @override
  String get ticketsNoExpiredTickets => 'Ni poteklih vozovnic.';

  @override
  String ticketsRemainingTime(String time) {
    return 'Preostane: $time';
  }

  @override
  String get paymentsCard => 'Plačilna kartica';

  @override
  String get paymentsGooglePay => 'Google Pay';

  @override
  String get paymentsApplePay => 'Apple Pay';

  @override
  String get paymentsBankTransfer => 'Bančno nakazilo / spletna banka';

  @override
  String get paymentsMobilePay => 'Mobilno plačilo';

  @override
  String get paymentsCardBrandLabel => 'Znamka kartice (npr. Visa)';

  @override
  String get paymentsLast4Label => 'Samo zadnje 4 številke (demo)';

  @override
  String get paymentsLast4Validation => 'Vnesite natančno 4 številke';

  @override
  String get paymentsSetDefault => 'Nastavi kot privzeto';

  @override
  String get accountSignUp => 'Ustvari račun';

  @override
  String get accountPasswordReset => 'Ponastavi geslo';

  @override
  String get accountDeleteAccount => 'Izbriši moj račun in podatke';

  @override
  String get accountDeleteConfirmTitle =>
      'Izbrisati račun in vse lokalne podatke?';

  @override
  String get accountDeleteConfirmBody =>
      'To izbriše vaš testni profil, shranjene vozovnice, plačilne kartice in nastavitve s te naprave.';

  @override
  String get accountNameLabel => 'Ime in priimek';

  @override
  String get accountEmailLabel => 'E-poštni naslov';

  @override
  String get accountPasswordLabel => 'Geslo';

  @override
  String get accountDobLabel => 'Datum rojstva';

  @override
  String get accountDemoAccountHint =>
      'Demo uporabnik: demo@marprom.si / demo1234';

  @override
  String get accountYouthEligible =>
      'Upravičeni do mladinske / študentske cene';

  @override
  String get accountSeniorEligible => 'Upravičeni do upokojenske cene';

  @override
  String accountResetSent(String email) {
    return 'Testna povezava za ponastavitev gesla pripravljena za $email.';
  }

  @override
  String get accountSaveProfile => 'Shrani profil';

  @override
  String get onboardingConsentLocation =>
      'Dovoli lokacijo med uporabo aplikacije za najbližja postajališča (v testnem načinu ne zapusti naprave)';

  @override
  String get onboardingConsentNotifications =>
      'Dovoli opozorila za prihod, zamudo in iztek vozovnice';

  @override
  String get onboardingConsentAnalytics =>
      'Izbirna anonimna statistika uporabe (privzeto izklopljeno)';

  @override
  String get onboardingAccountOptionalNote =>
      'Račun je zdaj neobvezen in potreben šele pozneje ob nakupu vozovnice.';

  @override
  String get noticesTriggerAlternative => 'Poišči drugo pot';

  @override
  String get noticesSmartBusArriving =>
      'Opozorilo ob skorajšnjem prihodu avtobusa';

  @override
  String get noticesSmartLineDelayed =>
      'Opozorilo ob zamudi priljubljene linije';

  @override
  String get noticesSmartTicketExpiring => 'Opozorilo pred iztekom vozovnice';

  @override
  String get noticesPreviewVibration =>
      'Preizkusi vizualno in vibracijsko opozorilo';

  @override
  String get settingsClearLocalData => 'Počisti lokalni predpomnilnik';

  @override
  String get settingsClearLocalDataDone => 'Lokalni predpomnilnik je počiščen.';

  @override
  String get settingsAboutTitle => 'O aplikaciji M Mobilnost 2.0';

  @override
  String get settingsAboutBody =>
      'Dostopen enotni prototip javnega prevoza in vozovnic Marprom za Maribor. Simulirani podatki v živo so jasno označeni.';

  @override
  String get settingsUsabilityStart => 'Začni merjeni scenarij';

  @override
  String get settingsUsabilityFinish => 'Zaključi scenarij';

  @override
  String get settingsUsabilityRecordError => 'Zabeleži napako (+1)';

  @override
  String get settingsUsabilityExportCsv => 'Izvozi CSV';

  @override
  String get settingsUsabilityExportJson => 'Izvozi JSON';

  @override
  String settingsUsabilitySummary(int seconds, int taps, int errors) {
    return 'Čas: $seconds s • Dotiki: $taps • Napake: $errors';
  }
}
