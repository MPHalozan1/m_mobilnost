import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_sl.dart';
import 'app_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('sl'),
    Locale('sr'),
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
  ];

  /// Application title
  ///
  /// In sl, this message translates to:
  /// **'M Mobilnost'**
  String get appTitle;

  /// No description provided for @appBrand.
  ///
  /// In sl, this message translates to:
  /// **'M Mobilnost 2.0 • Marprom'**
  String get appBrand;

  /// No description provided for @languageNameSl.
  ///
  /// In sl, this message translates to:
  /// **'Slovenščina'**
  String get languageNameSl;

  /// No description provided for @languageNameEn.
  ///
  /// In sl, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @languageNameDe.
  ///
  /// In sl, this message translates to:
  /// **'Deutsch'**
  String get languageNameDe;

  /// No description provided for @languageNameSrLatn.
  ///
  /// In sl, this message translates to:
  /// **'Srpski / Hrvatski'**
  String get languageNameSrLatn;

  /// No description provided for @navHome.
  ///
  /// In sl, this message translates to:
  /// **'Domov'**
  String get navHome;

  /// No description provided for @navMap.
  ///
  /// In sl, this message translates to:
  /// **'Zemljevid'**
  String get navMap;

  /// No description provided for @navPlan.
  ///
  /// In sl, this message translates to:
  /// **'Načrtuj'**
  String get navPlan;

  /// No description provided for @navTickets.
  ///
  /// In sl, this message translates to:
  /// **'Vozovnice'**
  String get navTickets;

  /// No description provided for @navLines.
  ///
  /// In sl, this message translates to:
  /// **'Linije'**
  String get navLines;

  /// No description provided for @navNotices.
  ///
  /// In sl, this message translates to:
  /// **'Obvestila'**
  String get navNotices;

  /// No description provided for @navSettings.
  ///
  /// In sl, this message translates to:
  /// **'Nastavitve'**
  String get navSettings;

  /// No description provided for @navAccount.
  ///
  /// In sl, this message translates to:
  /// **'Račun'**
  String get navAccount;

  /// No description provided for @navMore.
  ///
  /// In sl, this message translates to:
  /// **'Več'**
  String get navMore;

  /// No description provided for @commonLoading.
  ///
  /// In sl, this message translates to:
  /// **'Nalaganje ...'**
  String get commonLoading;

  /// No description provided for @commonEmpty.
  ///
  /// In sl, this message translates to:
  /// **'Ni podatkov za prikaz.'**
  String get commonEmpty;

  /// No description provided for @commonErrorTitle.
  ///
  /// In sl, this message translates to:
  /// **'Prišlo je do napake'**
  String get commonErrorTitle;

  /// No description provided for @commonErrorBody.
  ///
  /// In sl, this message translates to:
  /// **'Podatkov trenutno ni bilo mogoče naložiti. Preverite povezavo in poskusite znova.'**
  String get commonErrorBody;

  /// No description provided for @commonRetry.
  ///
  /// In sl, this message translates to:
  /// **'Poskusi znova'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In sl, this message translates to:
  /// **'Prekliči'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Potrdi'**
  String get commonConfirm;

  /// No description provided for @commonContinue.
  ///
  /// In sl, this message translates to:
  /// **'Nadaljuj'**
  String get commonContinue;

  /// No description provided for @commonBack.
  ///
  /// In sl, this message translates to:
  /// **'Nazaj'**
  String get commonBack;

  /// No description provided for @commonClose.
  ///
  /// In sl, this message translates to:
  /// **'Zapri'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In sl, this message translates to:
  /// **'Shrani'**
  String get commonSave;

  /// No description provided for @commonDone.
  ///
  /// In sl, this message translates to:
  /// **'Končano'**
  String get commonDone;

  /// No description provided for @commonSkip.
  ///
  /// In sl, this message translates to:
  /// **'Preskoči'**
  String get commonSkip;

  /// No description provided for @commonNext.
  ///
  /// In sl, this message translates to:
  /// **'Naprej'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In sl, this message translates to:
  /// **'Prejšnji'**
  String get commonPrevious;

  /// No description provided for @commonSearch.
  ///
  /// In sl, this message translates to:
  /// **'Išči'**
  String get commonSearch;

  /// No description provided for @commonClear.
  ///
  /// In sl, this message translates to:
  /// **'Počisti'**
  String get commonClear;

  /// No description provided for @commonRefresh.
  ///
  /// In sl, this message translates to:
  /// **'Osveži'**
  String get commonRefresh;

  /// No description provided for @commonFilter.
  ///
  /// In sl, this message translates to:
  /// **'Filtriraj'**
  String get commonFilter;

  /// No description provided for @commonAll.
  ///
  /// In sl, this message translates to:
  /// **'Vse'**
  String get commonAll;

  /// No description provided for @commonFavorites.
  ///
  /// In sl, this message translates to:
  /// **'Priljubljene'**
  String get commonFavorites;

  /// No description provided for @commonShowMore.
  ///
  /// In sl, this message translates to:
  /// **'Prikaži več'**
  String get commonShowMore;

  /// No description provided for @commonShowLess.
  ///
  /// In sl, this message translates to:
  /// **'Prikaži manj'**
  String get commonShowLess;

  /// No description provided for @commonYes.
  ///
  /// In sl, this message translates to:
  /// **'Da'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In sl, this message translates to:
  /// **'Ne'**
  String get commonNo;

  /// No description provided for @commonOk.
  ///
  /// In sl, this message translates to:
  /// **'V redu'**
  String get commonOk;

  /// No description provided for @commonEdit.
  ///
  /// In sl, this message translates to:
  /// **'Uredi'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani'**
  String get commonRemove;

  /// No description provided for @commonEnable.
  ///
  /// In sl, this message translates to:
  /// **'Omogoči'**
  String get commonEnable;

  /// No description provided for @commonDisable.
  ///
  /// In sl, this message translates to:
  /// **'Onemogoči'**
  String get commonDisable;

  /// No description provided for @commonPlaceholderNotice.
  ///
  /// In sl, this message translates to:
  /// **'Ta zaslon bo dopolnjen v naslednji fazi razvoja.'**
  String get commonPlaceholderNotice;

  /// No description provided for @commonMinutesShort.
  ///
  /// In sl, this message translates to:
  /// **'{minutes} min'**
  String commonMinutesShort(int minutes);

  /// No description provided for @commonHoursShort.
  ///
  /// In sl, this message translates to:
  /// **'{hours} h'**
  String commonHoursShort(int hours);

  /// No description provided for @commonSecondsShort.
  ///
  /// In sl, this message translates to:
  /// **'{seconds} s'**
  String commonSecondsShort(int seconds);

  /// No description provided for @commonMetersShort.
  ///
  /// In sl, this message translates to:
  /// **'{meters} m'**
  String commonMetersShort(int meters);

  /// No description provided for @commonKilometersShort.
  ///
  /// In sl, this message translates to:
  /// **'{km} km'**
  String commonKilometersShort(String km);

  /// No description provided for @commonMinutesPlural.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, =0{manj kot minuto} one{{count} minuta} two{{count} minuti} few{{count} minute} other{{count} minut}}'**
  String commonMinutesPlural(int count);

  /// No description provided for @commonStopsPlural.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, =0{0 postajališč} one{{count} postajališče} two{{count} postajališči} few{{count} postajališča} other{{count} postajališč}}'**
  String commonStopsPlural(int count);

  /// No description provided for @commonTransfersPlural.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, =0{brez prestopanja} one{{count} prestop} two{{count} prestopa} few{{count} prestopi} other{{count} prestopov}}'**
  String commonTransfersPlural(int count);

  /// No description provided for @commonBusesPlural.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, =0{ni avtobusov} one{{count} avtobus} two{{count} avtobusa} few{{count} avtobusi} other{{count} avtobusov}}'**
  String commonBusesPlural(int count);

  /// No description provided for @commonUpdatedAgo.
  ///
  /// In sl, this message translates to:
  /// **'Posodobljeno pred {time}'**
  String commonUpdatedAgo(String time);

  /// No description provided for @commonLastUpdatedAt.
  ///
  /// In sl, this message translates to:
  /// **'Nazadnje posodobljeno: {time}'**
  String commonLastUpdatedAt(String time);

  /// No description provided for @commonJustNow.
  ///
  /// In sl, this message translates to:
  /// **'pravkar'**
  String get commonJustNow;

  /// No description provided for @statusEarly.
  ///
  /// In sl, this message translates to:
  /// **'Zgodaj'**
  String get statusEarly;

  /// No description provided for @statusOnTime.
  ///
  /// In sl, this message translates to:
  /// **'Točno'**
  String get statusOnTime;

  /// No description provided for @statusLate.
  ///
  /// In sl, this message translates to:
  /// **'Zamuda'**
  String get statusLate;

  /// No description provided for @statusInfo.
  ///
  /// In sl, this message translates to:
  /// **'Info'**
  String get statusInfo;

  /// No description provided for @statusWarning.
  ///
  /// In sl, this message translates to:
  /// **'Opozorilo'**
  String get statusWarning;

  /// No description provided for @statusDisruption.
  ///
  /// In sl, this message translates to:
  /// **'Motnja'**
  String get statusDisruption;

  /// No description provided for @statusCancelled.
  ///
  /// In sl, this message translates to:
  /// **'Odpovedano'**
  String get statusCancelled;

  /// No description provided for @statusDetour.
  ///
  /// In sl, this message translates to:
  /// **'Obvoz'**
  String get statusDetour;

  /// No description provided for @statusOffline.
  ///
  /// In sl, this message translates to:
  /// **'Brez povezave'**
  String get statusOffline;

  /// No description provided for @statusOnline.
  ///
  /// In sl, this message translates to:
  /// **'Povezano'**
  String get statusOnline;

  /// No description provided for @statusEarlyByMinutes.
  ///
  /// In sl, this message translates to:
  /// **'{minutes} min zgodaj'**
  String statusEarlyByMinutes(int minutes);

  /// No description provided for @statusLateByMinutes.
  ///
  /// In sl, this message translates to:
  /// **'+{minutes} min zamude'**
  String statusLateByMinutes(int minutes);

  /// No description provided for @statusArrivingNow.
  ///
  /// In sl, this message translates to:
  /// **'Prihaja zdaj'**
  String get statusArrivingNow;

  /// No description provided for @statusDepartingIn.
  ///
  /// In sl, this message translates to:
  /// **'Odhod čez {minutes} min'**
  String statusDepartingIn(int minutes);

  /// No description provided for @badgeOfflineTitle.
  ///
  /// In sl, this message translates to:
  /// **'Delovanje brez povezave'**
  String get badgeOfflineTitle;

  /// No description provided for @badgeOfflineBody.
  ///
  /// In sl, this message translates to:
  /// **'Prikazani so predpomnjeni vozni redi in shranjene vozovnice.'**
  String get badgeOfflineBody;

  /// No description provided for @badgeOfflineLastSync.
  ///
  /// In sl, this message translates to:
  /// **'Zadnja sinhronizacija: {time}'**
  String badgeOfflineLastSync(String time);

  /// No description provided for @badgeSimulatedLabel.
  ///
  /// In sl, this message translates to:
  /// **'Simulirani podatki'**
  String get badgeSimulatedLabel;

  /// No description provided for @badgeSimulatedTooltip.
  ///
  /// In sl, this message translates to:
  /// **'Prikazani so simulirani podatki v živo za namene predstavitve in testiranja.'**
  String get badgeSimulatedTooltip;

  /// No description provided for @badgeSimulatedDisclaimer.
  ///
  /// In sl, this message translates to:
  /// **'Viri v živo so v načinu simulacije. Časi so informativni.'**
  String get badgeSimulatedDisclaimer;

  /// No description provided for @freshnessLive.
  ///
  /// In sl, this message translates to:
  /// **'Podatki v živo'**
  String get freshnessLive;

  /// No description provided for @freshnessSimulated.
  ///
  /// In sl, this message translates to:
  /// **'Simulirano v živo'**
  String get freshnessSimulated;

  /// No description provided for @freshnessCached.
  ///
  /// In sl, this message translates to:
  /// **'Predpomnjeno'**
  String get freshnessCached;

  /// No description provided for @freshnessStale.
  ///
  /// In sl, this message translates to:
  /// **'Morda zastareli podatki'**
  String get freshnessStale;

  /// No description provided for @freshnessLiveDisabledFallback.
  ///
  /// In sl, this message translates to:
  /// **'Podatki v živo niso na voljo, prikazan je vozni red'**
  String get freshnessLiveDisabledFallback;

  /// No description provided for @occupancyLabel.
  ///
  /// In sl, this message translates to:
  /// **'Zasedenost'**
  String get occupancyLabel;

  /// No description provided for @occupancyLow.
  ///
  /// In sl, this message translates to:
  /// **'Veliko prostih mest'**
  String get occupancyLow;

  /// No description provided for @occupancyMedium.
  ///
  /// In sl, this message translates to:
  /// **'Zmerno zasedeno'**
  String get occupancyMedium;

  /// No description provided for @occupancyHigh.
  ///
  /// In sl, this message translates to:
  /// **'Zelo zasedeno'**
  String get occupancyHigh;

  /// No description provided for @occupancyFull.
  ///
  /// In sl, this message translates to:
  /// **'Avtobus je poln'**
  String get occupancyFull;

  /// No description provided for @occupancyUnknown.
  ///
  /// In sl, this message translates to:
  /// **'Zasedenost ni znana'**
  String get occupancyUnknown;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dobrodošli v M Mobilnost 2.0'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In sl, this message translates to:
  /// **'Vaš dostopen in zanesljiv vodnik za mestne avtobuse Marprom v Mariboru.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingChooseLanguage.
  ///
  /// In sl, this message translates to:
  /// **'Izberite jezik aplikacije'**
  String get onboardingChooseLanguage;

  /// No description provided for @onboardingAccessibilityTitle.
  ///
  /// In sl, this message translates to:
  /// **'Prilagoditve dostopnosti'**
  String get onboardingAccessibilityTitle;

  /// No description provided for @onboardingAccessibilitySubtitle.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacijo lahko prilagodite zdaj ali kadarkoli v nastavitvah.'**
  String get onboardingAccessibilitySubtitle;

  /// No description provided for @onboardingLocationTitle.
  ///
  /// In sl, this message translates to:
  /// **'Lokacija in zasebnost'**
  String get onboardingLocationTitle;

  /// No description provided for @onboardingLocationSubtitle.
  ///
  /// In sl, this message translates to:
  /// **'Dovoli lokacijo za najbližja postajališča ali izberi ročni mariborski način brez GPS.'**
  String get onboardingLocationSubtitle;

  /// No description provided for @onboardingUseGps.
  ///
  /// In sl, this message translates to:
  /// **'Uporabi GPS lokacijo'**
  String get onboardingUseGps;

  /// No description provided for @onboardingUseManualLocation.
  ///
  /// In sl, this message translates to:
  /// **'Ročna izbira postajališča (brez GPS)'**
  String get onboardingUseManualLocation;

  /// No description provided for @onboardingStartRiding.
  ///
  /// In sl, this message translates to:
  /// **'Začni z vožnjo'**
  String get onboardingStartRiding;

  /// No description provided for @onboardingOpenGuide.
  ///
  /// In sl, this message translates to:
  /// **'Prvič z avtobusom? Odpri vodič'**
  String get onboardingOpenGuide;

  /// No description provided for @guideTitle.
  ///
  /// In sl, this message translates to:
  /// **'Prvič z avtobusom'**
  String get guideTitle;

  /// No description provided for @guideSubtitle.
  ///
  /// In sl, this message translates to:
  /// **'Kratek vodnik v 5 korakih za brezskrbno vožnjo po Mariboru.'**
  String get guideSubtitle;

  /// No description provided for @guideCardProgress.
  ///
  /// In sl, this message translates to:
  /// **'Korak {current} od {total}'**
  String guideCardProgress(int current, int total);

  /// No description provided for @guideCard1Title.
  ///
  /// In sl, this message translates to:
  /// **'1. Poiščite postajališče in linijo'**
  String get guideCard1Title;

  /// No description provided for @guideCard1Body.
  ///
  /// In sl, this message translates to:
  /// **'Preverite najbližje postajališče na zemljevidu ali na seznamu linij. Vsi odhodi kažejo smer vožnje in številko linije.'**
  String get guideCard1Body;

  /// No description provided for @guideCard2Title.
  ///
  /// In sl, this message translates to:
  /// **'2. Kupite ali pripravite vozovnico'**
  String get guideCard2Title;

  /// No description provided for @guideCard2Body.
  ///
  /// In sl, this message translates to:
  /// **'Vozovnico lahko kupite v zavihku Vozovnice. Ob vstopu jo pripravite na zaslonu s povečano svetlostjo za hitro odčitavanje QR kode.'**
  String get guideCard2Body;

  /// No description provided for @guideCard3Title.
  ///
  /// In sl, this message translates to:
  /// **'3. Vstopite pri prvih vratih'**
  String get guideCard3Title;

  /// No description provided for @guideCard3Body.
  ///
  /// In sl, this message translates to:
  /// **'Ko avtobus prihaja, vozniku jasno nakažite željo po vstopu. Vstopite pri sprednjih vratih in potrdite vozovnico.'**
  String get guideCard3Body;

  /// No description provided for @guideCard4Title.
  ///
  /// In sl, this message translates to:
  /// **'4. Spremljajte vožnjo v živo'**
  String get guideCard4Title;

  /// No description provided for @guideCard4Body.
  ///
  /// In sl, this message translates to:
  /// **'V sledilniku v živo vidite naslednja postajališča, predviden prihod in opozorilo pred izstopom.'**
  String get guideCard4Body;

  /// No description provided for @guideCard5Title.
  ///
  /// In sl, this message translates to:
  /// **'5. Izstop in prestopanje'**
  String get guideCard5Title;

  /// No description provided for @guideCard5Body.
  ///
  /// In sl, this message translates to:
  /// **'Pred želenim postajališčem pritisnite gumb STOP. Pri prestopanju preverite opozorilo za kratek čas prestopa.'**
  String get guideCard5Body;

  /// No description provided for @guideFinishCta.
  ///
  /// In sl, this message translates to:
  /// **'Razumem, začnimo'**
  String get guideFinishCta;

  /// No description provided for @homeGreeting.
  ///
  /// In sl, this message translates to:
  /// **'Kam gremo danes?'**
  String get homeGreeting;

  /// No description provided for @homeSearchHint.
  ///
  /// In sl, this message translates to:
  /// **'Kam želite potovati ali katero linijo iščete?'**
  String get homeSearchHint;

  /// No description provided for @homeFavoriteStops.
  ///
  /// In sl, this message translates to:
  /// **'Priljubljena postajališča'**
  String get homeFavoriteStops;

  /// No description provided for @homeNearbyStops.
  ///
  /// In sl, this message translates to:
  /// **'Najbližja postajališča'**
  String get homeNearbyStops;

  /// No description provided for @homeQuickActions.
  ///
  /// In sl, this message translates to:
  /// **'Hitre možnosti'**
  String get homeQuickActions;

  /// No description provided for @homeActiveTicket.
  ///
  /// In sl, this message translates to:
  /// **'Aktivna vozovnica'**
  String get homeActiveTicket;

  /// No description provided for @homeNoActiveTicket.
  ///
  /// In sl, this message translates to:
  /// **'Trenutno nimate aktivne vozovnice'**
  String get homeNoActiveTicket;

  /// No description provided for @homeNearestStopAction.
  ///
  /// In sl, this message translates to:
  /// **'Najbližja postaja'**
  String get homeNearestStopAction;

  /// No description provided for @homePlanTripAction.
  ///
  /// In sl, this message translates to:
  /// **'Načrtuj pot'**
  String get homePlanTripAction;

  /// No description provided for @homeBuyTicketAction.
  ///
  /// In sl, this message translates to:
  /// **'Kupi vozovnico'**
  String get homeBuyTicketAction;

  /// No description provided for @homeLinesAction.
  ///
  /// In sl, this message translates to:
  /// **'Linije in vozni redi'**
  String get homeLinesAction;

  /// No description provided for @homeGuideAction.
  ///
  /// In sl, this message translates to:
  /// **'Prvič z avtobusom'**
  String get homeGuideAction;

  /// No description provided for @homeAskMarpromAction.
  ///
  /// In sl, this message translates to:
  /// **'Vprašaj Marprom'**
  String get homeAskMarpromAction;

  /// No description provided for @askTitle.
  ///
  /// In sl, this message translates to:
  /// **'Vprašaj Marprom'**
  String get askTitle;

  /// No description provided for @askSubtitle.
  ///
  /// In sl, this message translates to:
  /// **'Hiter pomočnik za linije, odhode in vozovnice'**
  String get askSubtitle;

  /// No description provided for @askInputHint.
  ///
  /// In sl, this message translates to:
  /// **'Vprašajte npr. Kdaj gre naslednji avtobus 6?'**
  String get askInputHint;

  /// No description provided for @askSend.
  ///
  /// In sl, this message translates to:
  /// **'Pošlji'**
  String get askSend;

  /// No description provided for @askVoicePrompt.
  ///
  /// In sl, this message translates to:
  /// **'Govori zdaj ...'**
  String get askVoicePrompt;

  /// No description provided for @askSample1.
  ///
  /// In sl, this message translates to:
  /// **'Kdaj pelje naslednji avtobus z Glavnega trga?'**
  String get askSample1;

  /// No description provided for @askSample2.
  ///
  /// In sl, this message translates to:
  /// **'Katera vozovnica je najugodnejša za danes?'**
  String get askSample2;

  /// No description provided for @askSample3.
  ///
  /// In sl, this message translates to:
  /// **'Ali so danes kakšne motnje ali obvozi?'**
  String get askSample3;

  /// No description provided for @askSample4.
  ///
  /// In sl, this message translates to:
  /// **'Kje je najbližje postajališče?'**
  String get askSample4;

  /// No description provided for @askClearChat.
  ///
  /// In sl, this message translates to:
  /// **'Počisti pogovor'**
  String get askClearChat;

  /// No description provided for @askDisclaimer.
  ///
  /// In sl, this message translates to:
  /// **'Odgovori temeljijo na lokalnih podatkih Marprom in simulaciji v živo.'**
  String get askDisclaimer;

  /// No description provided for @askNoMatch.
  ///
  /// In sl, this message translates to:
  /// **'Na to vprašanje nimam točnega odgovora. Poskusite vprašati o liniji, postajališču, vozovnici ali motnjah.'**
  String get askNoMatch;

  /// No description provided for @linesTitle.
  ///
  /// In sl, this message translates to:
  /// **'Linije in vozni redi'**
  String get linesTitle;

  /// No description provided for @linesSearchHint.
  ///
  /// In sl, this message translates to:
  /// **'Išči linijo ali končno postajo ...'**
  String get linesSearchHint;

  /// No description provided for @linesBadge.
  ///
  /// In sl, this message translates to:
  /// **'Linija {code}'**
  String linesBadge(String code);

  /// No description provided for @linesDirectionLabel.
  ///
  /// In sl, this message translates to:
  /// **'Smer'**
  String get linesDirectionLabel;

  /// No description provided for @linesSwapDirection.
  ///
  /// In sl, this message translates to:
  /// **'Obrni smer'**
  String get linesSwapDirection;

  /// No description provided for @linesScheduleWeekday.
  ///
  /// In sl, this message translates to:
  /// **'Delavnik'**
  String get linesScheduleWeekday;

  /// No description provided for @linesScheduleSaturday.
  ///
  /// In sl, this message translates to:
  /// **'Sobota'**
  String get linesScheduleSaturday;

  /// No description provided for @linesScheduleSunday.
  ///
  /// In sl, this message translates to:
  /// **'Nedelja / praznik'**
  String get linesScheduleSunday;

  /// No description provided for @linesFirstBus.
  ///
  /// In sl, this message translates to:
  /// **'Prvi odhod'**
  String get linesFirstBus;

  /// No description provided for @linesLastBus.
  ///
  /// In sl, this message translates to:
  /// **'Zadnji odhod'**
  String get linesLastBus;

  /// No description provided for @linesLowFloor.
  ///
  /// In sl, this message translates to:
  /// **'Nizkopodni avtobus'**
  String get linesLowFloor;

  /// No description provided for @linesFavoriteAdd.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj med priljubljene'**
  String get linesFavoriteAdd;

  /// No description provided for @linesFavoriteRemove.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani iz priljubljenih'**
  String get linesFavoriteRemove;

  /// No description provided for @linesNoDepartures.
  ///
  /// In sl, this message translates to:
  /// **'Za izbrani dan ni več odhodov.'**
  String get linesNoDepartures;

  /// No description provided for @mapTitle.
  ///
  /// In sl, this message translates to:
  /// **'Zemljevid postajališč'**
  String get mapTitle;

  /// No description provided for @mapSwitchToList.
  ///
  /// In sl, this message translates to:
  /// **'Seznam'**
  String get mapSwitchToList;

  /// No description provided for @mapSwitchToMap.
  ///
  /// In sl, this message translates to:
  /// **'Zemljevid'**
  String get mapSwitchToMap;

  /// No description provided for @mapSearchHint.
  ///
  /// In sl, this message translates to:
  /// **'Išči postajališče ali ulico ...'**
  String get mapSearchHint;

  /// No description provided for @mapCenterOnMe.
  ///
  /// In sl, this message translates to:
  /// **'Moja lokacija'**
  String get mapCenterOnMe;

  /// No description provided for @mapManualCenter.
  ///
  /// In sl, this message translates to:
  /// **'Center Maribora'**
  String get mapManualCenter;

  /// No description provided for @mapFilterAccessible.
  ///
  /// In sl, this message translates to:
  /// **'Dostopno za invalide'**
  String get mapFilterAccessible;

  /// No description provided for @mapFilterActiveBuses.
  ///
  /// In sl, this message translates to:
  /// **'Avtobusi v živo'**
  String get mapFilterActiveBuses;

  /// No description provided for @mapStopDetailsOpen.
  ///
  /// In sl, this message translates to:
  /// **'Odpri odhode postajališča'**
  String get mapStopDetailsOpen;

  /// No description provided for @stopTitle.
  ///
  /// In sl, this message translates to:
  /// **'Postajališče'**
  String get stopTitle;

  /// No description provided for @stopPlatform.
  ///
  /// In sl, this message translates to:
  /// **'Peron {platform}'**
  String stopPlatform(String platform);

  /// No description provided for @stopUpcomingDepartures.
  ///
  /// In sl, this message translates to:
  /// **'Prihajajoči odhodi'**
  String get stopUpcomingDepartures;

  /// No description provided for @stopAmenitiesTitle.
  ///
  /// In sl, this message translates to:
  /// **'Oprema postajališča'**
  String get stopAmenitiesTitle;

  /// No description provided for @stopAmenityShelter.
  ///
  /// In sl, this message translates to:
  /// **'Nadstrešnica'**
  String get stopAmenityShelter;

  /// No description provided for @stopAmenityBench.
  ///
  /// In sl, this message translates to:
  /// **'Klop'**
  String get stopAmenityBench;

  /// No description provided for @stopAmenityTactile.
  ///
  /// In sl, this message translates to:
  /// **'Taktilne oznake'**
  String get stopAmenityTactile;

  /// No description provided for @stopAmenityStepFree.
  ///
  /// In sl, this message translates to:
  /// **'Dostop brez stopnic'**
  String get stopAmenityStepFree;

  /// No description provided for @stopAmenityDisplay.
  ///
  /// In sl, this message translates to:
  /// **'Digitalni prikazovalnik'**
  String get stopAmenityDisplay;

  /// No description provided for @stopNoDepartures.
  ///
  /// In sl, this message translates to:
  /// **'V naslednjih urah ni načrtovanih odhodov.'**
  String get stopNoDepartures;

  /// No description provided for @trackerTitle.
  ///
  /// In sl, this message translates to:
  /// **'Sledenje v živo'**
  String get trackerTitle;

  /// No description provided for @trackerFollowBus.
  ///
  /// In sl, this message translates to:
  /// **'Sledi avtobusu'**
  String get trackerFollowBus;

  /// No description provided for @trackerNextStop.
  ///
  /// In sl, this message translates to:
  /// **'Naslednje postajališče'**
  String get trackerNextStop;

  /// No description provided for @trackerStopsRemaining.
  ///
  /// In sl, this message translates to:
  /// **'Preostala postajališča'**
  String get trackerStopsRemaining;

  /// No description provided for @trackerEta.
  ///
  /// In sl, this message translates to:
  /// **'Predviden prihod'**
  String get trackerEta;

  /// No description provided for @trackerScheduledTime.
  ///
  /// In sl, this message translates to:
  /// **'Po voznem redu: {time}'**
  String trackerScheduledTime(String time);

  /// No description provided for @trackerNotifyMe.
  ///
  /// In sl, this message translates to:
  /// **'Obvesti me'**
  String get trackerNotifyMe;

  /// No description provided for @trackerNotifyCancel.
  ///
  /// In sl, this message translates to:
  /// **'Prekliči opomnik'**
  String get trackerNotifyCancel;

  /// No description provided for @trackerNotifyActive.
  ///
  /// In sl, this message translates to:
  /// **'Opomnik nastavljen: obvestilo pred prihodom.'**
  String get trackerNotifyActive;

  /// No description provided for @trackerNotifyPrompt.
  ///
  /// In sl, this message translates to:
  /// **'Izberite kdaj želite opozorilo pred prihodom avtobusa.'**
  String get trackerNotifyPrompt;

  /// No description provided for @trackerAdviceEarlyTitle.
  ///
  /// In sl, this message translates to:
  /// **'Avtobus vozi pred voznim redom'**
  String get trackerAdviceEarlyTitle;

  /// No description provided for @trackerAdviceEarlyBody.
  ///
  /// In sl, this message translates to:
  /// **'Avtobus je {minutes} min zgodaj. Če ste še na poti, preverite naslednji odhod ali se takoj odpravite na postajališče.'**
  String trackerAdviceEarlyBody(int minutes);

  /// No description provided for @trackerAdviceOnTimeTitle.
  ///
  /// In sl, this message translates to:
  /// **'Avtobus vozi po voznem redu'**
  String get trackerAdviceOnTimeTitle;

  /// No description provided for @trackerAdviceOnTimeBody.
  ///
  /// In sl, this message translates to:
  /// **'Pričakujte prihod ob načrtovanem času.'**
  String get trackerAdviceOnTimeBody;

  /// No description provided for @trackerAdviceLateTitle.
  ///
  /// In sl, this message translates to:
  /// **'Avtobus ima zamudo'**
  String get trackerAdviceLateTitle;

  /// No description provided for @trackerAdviceLateBody.
  ///
  /// In sl, this message translates to:
  /// **'Avtobus zamuja {minutes} min. Lahko počakate na postajališču ali spodaj preverite nadomestno povezavo.'**
  String trackerAdviceLateBody(int minutes);

  /// No description provided for @trackerAdviceReviewAlternatives.
  ///
  /// In sl, this message translates to:
  /// **'Preveri druge možnosti'**
  String get trackerAdviceReviewAlternatives;

  /// No description provided for @planTitle.
  ///
  /// In sl, this message translates to:
  /// **'Načrtovalnik poti'**
  String get planTitle;

  /// No description provided for @planOriginLabel.
  ///
  /// In sl, this message translates to:
  /// **'Začetna točka'**
  String get planOriginLabel;

  /// No description provided for @planDestinationLabel.
  ///
  /// In sl, this message translates to:
  /// **'Cilj'**
  String get planDestinationLabel;

  /// No description provided for @planCurrentLocation.
  ///
  /// In sl, this message translates to:
  /// **'Trenutna lokacija'**
  String get planCurrentLocation;

  /// No description provided for @planSwap.
  ///
  /// In sl, this message translates to:
  /// **'Zamenjaj začetek in cilj'**
  String get planSwap;

  /// No description provided for @planLeaveNow.
  ///
  /// In sl, this message translates to:
  /// **'Odhod zdaj'**
  String get planLeaveNow;

  /// No description provided for @planDepartAt.
  ///
  /// In sl, this message translates to:
  /// **'Odhod ob'**
  String get planDepartAt;

  /// No description provided for @planArriveBy.
  ///
  /// In sl, this message translates to:
  /// **'Prihod do'**
  String get planArriveBy;

  /// No description provided for @planAccessibleOnly.
  ///
  /// In sl, this message translates to:
  /// **'Samo dostopne poti brez stopnic'**
  String get planAccessibleOnly;

  /// No description provided for @planFewerTransfers.
  ///
  /// In sl, this message translates to:
  /// **'Manj prestopanj'**
  String get planFewerTransfers;

  /// No description provided for @planFindRoutes.
  ///
  /// In sl, this message translates to:
  /// **'Poišči povezave'**
  String get planFindRoutes;

  /// No description provided for @planTightTransferTitle.
  ///
  /// In sl, this message translates to:
  /// **'Tesno prestopanje'**
  String get planTightTransferTitle;

  /// No description provided for @planTightTransferBody.
  ///
  /// In sl, this message translates to:
  /// **'Za prestop imate le {minutes} min. Ob manjši zamudi prvega avtobusa lahko povezavo zamudite.'**
  String planTightTransferBody(int minutes);

  /// No description provided for @planWhatDoINextTitle.
  ///
  /// In sl, this message translates to:
  /// **'Kaj naj naredim zdaj?'**
  String get planWhatDoINextTitle;

  /// No description provided for @planStepWalkTo.
  ///
  /// In sl, this message translates to:
  /// **'Peš do postajališča {stop} ({distance})'**
  String planStepWalkTo(String stop, String distance);

  /// No description provided for @planStepBoardLine.
  ///
  /// In sl, this message translates to:
  /// **'Vstopite na linijo {line} v smeri {direction}'**
  String planStepBoardLine(String line, String direction);

  /// No description provided for @planStepRideStops.
  ///
  /// In sl, this message translates to:
  /// **'Peljite se {stops} do postajališča {stop}'**
  String planStepRideStops(String stops, String stop);

  /// No description provided for @planStepTransferAt.
  ///
  /// In sl, this message translates to:
  /// **'Prestopite na postajališču {stop}'**
  String planStepTransferAt(String stop);

  /// No description provided for @planStepGetOffAt.
  ///
  /// In sl, this message translates to:
  /// **'Izstopite na postajališču {stop}'**
  String planStepGetOffAt(String stop);

  /// No description provided for @planStepArrived.
  ///
  /// In sl, this message translates to:
  /// **'Prispeli ste na cilj.'**
  String get planStepArrived;

  /// No description provided for @nearestStopTitle.
  ///
  /// In sl, this message translates to:
  /// **'Najbližje postajališče'**
  String get nearestStopTitle;

  /// No description provided for @nearestStopDistance.
  ///
  /// In sl, this message translates to:
  /// **'Oddaljenost: {distance}'**
  String nearestStopDistance(String distance);

  /// No description provided for @nearestStopWalkTime.
  ///
  /// In sl, this message translates to:
  /// **'Približno {minutes} min hoje'**
  String nearestStopWalkTime(int minutes);

  /// No description provided for @nearestStopNextBus.
  ///
  /// In sl, this message translates to:
  /// **'Naslednji odhod'**
  String get nearestStopNextBus;

  /// No description provided for @nearestStopUseManual.
  ///
  /// In sl, this message translates to:
  /// **'Izberi postajališče ročno'**
  String get nearestStopUseManual;

  /// No description provided for @ticketsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Moje vozovnice'**
  String get ticketsTitle;

  /// No description provided for @ticketsActiveTab.
  ///
  /// In sl, this message translates to:
  /// **'Aktivne'**
  String get ticketsActiveTab;

  /// No description provided for @ticketsHistoryTab.
  ///
  /// In sl, this message translates to:
  /// **'Pretekle'**
  String get ticketsHistoryTab;

  /// No description provided for @ticketsBuyButton.
  ///
  /// In sl, this message translates to:
  /// **'Kupi vozovnico'**
  String get ticketsBuyButton;

  /// No description provided for @ticketsShopTitle.
  ///
  /// In sl, this message translates to:
  /// **'Nakup vozovnic'**
  String get ticketsShopTitle;

  /// No description provided for @ticketsCheckoutTitle.
  ///
  /// In sl, this message translates to:
  /// **'Zaključek nakupa'**
  String get ticketsCheckoutTitle;

  /// No description provided for @ticketsViewTitle.
  ///
  /// In sl, this message translates to:
  /// **'Veljavna vozovnica'**
  String get ticketsViewTitle;

  /// No description provided for @ticketsZoneMaribor.
  ///
  /// In sl, this message translates to:
  /// **'Cona Maribor'**
  String get ticketsZoneMaribor;

  /// No description provided for @ticketsValidUntil.
  ///
  /// In sl, this message translates to:
  /// **'Velja do {time}'**
  String ticketsValidUntil(String time);

  /// No description provided for @ticketsQrHint.
  ///
  /// In sl, this message translates to:
  /// **'Prislonite QR kodo k validatorju na avtobusu.'**
  String get ticketsQrHint;

  /// No description provided for @ticketsBrightnessBoosted.
  ///
  /// In sl, this message translates to:
  /// **'Svetlost zaslona je začasno povečana za lažje branje kode.'**
  String get ticketsBrightnessBoosted;

  /// No description provided for @ticketsNfcStubTitle.
  ///
  /// In sl, this message translates to:
  /// **'Brezstično potrjevanje (NFC)'**
  String get ticketsNfcStubTitle;

  /// No description provided for @ticketsNfcStubBody.
  ///
  /// In sl, this message translates to:
  /// **'Simulacija NFC potrditve ob vstopu. Prislonite telefon k čitalcu.'**
  String get ticketsNfcStubBody;

  /// No description provided for @ticketsNfcTapToSimulate.
  ///
  /// In sl, this message translates to:
  /// **'Simuliraj NFC dotik'**
  String get ticketsNfcTapToSimulate;

  /// No description provided for @ticketsNfcValidated.
  ///
  /// In sl, this message translates to:
  /// **'Vozovnica je uspešno potrjena.'**
  String get ticketsNfcValidated;

  /// No description provided for @ticketsQuantity.
  ///
  /// In sl, this message translates to:
  /// **'Količina'**
  String get ticketsQuantity;

  /// No description provided for @ticketsTotalPrice.
  ///
  /// In sl, this message translates to:
  /// **'Skupaj za plačilo'**
  String get ticketsTotalPrice;

  /// No description provided for @ticketsPayNow.
  ///
  /// In sl, this message translates to:
  /// **'Plačaj zdaj'**
  String get ticketsPayNow;

  /// No description provided for @ticketsPurchaseSuccess.
  ///
  /// In sl, this message translates to:
  /// **'Vozovnica je kupljena in pripravljena za uporabo.'**
  String get ticketsPurchaseSuccess;

  /// No description provided for @ticketsMinorTitle.
  ///
  /// In sl, this message translates to:
  /// **'Potrditev staršev ali skrbnika'**
  String get ticketsMinorTitle;

  /// No description provided for @ticketsMinorUnder16Warning.
  ///
  /// In sl, this message translates to:
  /// **'Osebe mlajše od 16 let potrebujejo potrditev starša ali zakonitega skrbnika za spletno plačilo.'**
  String get ticketsMinorUnder16Warning;

  /// No description provided for @ticketsMinorUnder18Notice.
  ///
  /// In sl, this message translates to:
  /// **'Mladoletne osebe med 16. in 18. letom morajo potrditi soglasje za digitalne nakupe.'**
  String get ticketsMinorUnder18Notice;

  /// No description provided for @ticketsMinorGuardianConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Potrjujem, da imam soglasje starša ali skrbnika.'**
  String get ticketsMinorGuardianConfirm;

  /// No description provided for @ticketsMinorGuardianEmail.
  ///
  /// In sl, this message translates to:
  /// **'E-pošta starša ali skrbnika'**
  String get ticketsMinorGuardianEmail;

  /// No description provided for @paymentsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Načini plačila'**
  String get paymentsTitle;

  /// No description provided for @paymentsAddMethod.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj način plačila'**
  String get paymentsAddMethod;

  /// No description provided for @paymentsDefaultBadge.
  ///
  /// In sl, this message translates to:
  /// **'Privzeto'**
  String get paymentsDefaultBadge;

  /// No description provided for @paymentsSimulatedNotice.
  ///
  /// In sl, this message translates to:
  /// **'Vsi plačilni tokovi so v tem prototipu lokalno simulirani.'**
  String get paymentsSimulatedNotice;

  /// No description provided for @accountTitle.
  ///
  /// In sl, this message translates to:
  /// **'Uporabniški račun'**
  String get accountTitle;

  /// No description provided for @accountGuestMode.
  ///
  /// In sl, this message translates to:
  /// **'Način gosta'**
  String get accountGuestMode;

  /// No description provided for @accountSignIn.
  ///
  /// In sl, this message translates to:
  /// **'Prijava'**
  String get accountSignIn;

  /// No description provided for @accountSignOut.
  ///
  /// In sl, this message translates to:
  /// **'Odjava'**
  String get accountSignOut;

  /// No description provided for @accountManagePayments.
  ///
  /// In sl, this message translates to:
  /// **'Upravljaj plačila'**
  String get accountManagePayments;

  /// No description provided for @accountGdprTitle.
  ///
  /// In sl, this message translates to:
  /// **'Zasebnost in soglasja (GDPR)'**
  String get accountGdprTitle;

  /// No description provided for @accountGdprDescription.
  ///
  /// In sl, this message translates to:
  /// **'Upravljajte svoja soglasja za analitiko, obvestila in obdelavo podatkov.'**
  String get accountGdprDescription;

  /// No description provided for @accountGdprAnalytics.
  ///
  /// In sl, this message translates to:
  /// **'Anonimna analitika uporabe'**
  String get accountGdprAnalytics;

  /// No description provided for @accountGdprNotifications.
  ///
  /// In sl, this message translates to:
  /// **'Potisna obvestila o zamudah'**
  String get accountGdprNotifications;

  /// No description provided for @accountGdprExport.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi moje podatke'**
  String get accountGdprExport;

  /// No description provided for @accountGdprDelete.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši lokalne podatke'**
  String get accountGdprDelete;

  /// No description provided for @accountGdprPrivacyLink.
  ///
  /// In sl, this message translates to:
  /// **'Politika zasebnosti'**
  String get accountGdprPrivacyLink;

  /// No description provided for @noticesTitle.
  ///
  /// In sl, this message translates to:
  /// **'Obvestila in pametni opomniki'**
  String get noticesTitle;

  /// No description provided for @noticesAllTab.
  ///
  /// In sl, this message translates to:
  /// **'Vsa obvestila'**
  String get noticesAllTab;

  /// No description provided for @noticesDisruptionsTab.
  ///
  /// In sl, this message translates to:
  /// **'Motnje'**
  String get noticesDisruptionsTab;

  /// No description provided for @noticesSmartAlertsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Pametni opomniki'**
  String get noticesSmartAlertsTitle;

  /// No description provided for @noticesSmartAlertsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Prejmite opozorilo pred prihodom vašega avtobusa, ob motnjah na priljubljeni liniji in pred iztekom vozovnice.'**
  String get noticesSmartAlertsDesc;

  /// No description provided for @noticesMarkAllRead.
  ///
  /// In sl, this message translates to:
  /// **'Označi vse kot prebrano'**
  String get noticesMarkAllRead;

  /// No description provided for @noticesEmpty.
  ///
  /// In sl, this message translates to:
  /// **'Trenutno ni novih obvestil.'**
  String get noticesEmpty;

  /// No description provided for @noticesAffectedLines.
  ///
  /// In sl, this message translates to:
  /// **'Prizadete linije: {lines}'**
  String noticesAffectedLines(String lines);

  /// No description provided for @settingsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Nastavitve'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In sl, this message translates to:
  /// **'Videz'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In sl, this message translates to:
  /// **'Jezik'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsSectionAccessibility.
  ///
  /// In sl, this message translates to:
  /// **'Dostopnost in glas'**
  String get settingsSectionAccessibility;

  /// No description provided for @settingsSectionData.
  ///
  /// In sl, this message translates to:
  /// **'Podatki in lokacija'**
  String get settingsSectionData;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In sl, this message translates to:
  /// **'Zasebnost'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionUsability.
  ///
  /// In sl, this message translates to:
  /// **'Testiranje uporabnosti in demo'**
  String get settingsSectionUsability;

  /// No description provided for @settingsThemeMode.
  ///
  /// In sl, this message translates to:
  /// **'Barvna tema'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In sl, this message translates to:
  /// **'Sistemska'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In sl, this message translates to:
  /// **'Svetla'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In sl, this message translates to:
  /// **'Temna'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeHighContrast.
  ///
  /// In sl, this message translates to:
  /// **'Visok kontrast (AAA)'**
  String get settingsThemeHighContrast;

  /// No description provided for @settingsLanguage.
  ///
  /// In sl, this message translates to:
  /// **'Jezik vmesnika'**
  String get settingsLanguage;

  /// No description provided for @settingsExtraLargeText.
  ///
  /// In sl, this message translates to:
  /// **'Zelo veliko besedilo (do 200 %)'**
  String get settingsExtraLargeText;

  /// No description provided for @settingsExtraLargeTextDesc.
  ///
  /// In sl, this message translates to:
  /// **'Poveča pisavo v celotni aplikaciji za boljšo berljivost.'**
  String get settingsExtraLargeTextDesc;

  /// No description provided for @settingsReducedMotion.
  ///
  /// In sl, this message translates to:
  /// **'Zmanjšano gibanje'**
  String get settingsReducedMotion;

  /// No description provided for @settingsReducedMotionDesc.
  ///
  /// In sl, this message translates to:
  /// **'Onemogoči animacije in prehode zaslonov.'**
  String get settingsReducedMotionDesc;

  /// No description provided for @settingsReadAloud.
  ///
  /// In sl, this message translates to:
  /// **'Glasno branje (TTS)'**
  String get settingsReadAloud;

  /// No description provided for @settingsReadAloudDesc.
  ///
  /// In sl, this message translates to:
  /// **'Prebere ključna navodila, odhode in opozorila.'**
  String get settingsReadAloudDesc;

  /// No description provided for @settingsVoiceInput.
  ///
  /// In sl, this message translates to:
  /// **'Glasovni vnos'**
  String get settingsVoiceInput;

  /// No description provided for @settingsVoiceInputDesc.
  ///
  /// In sl, this message translates to:
  /// **'Omogoči iskanje postajališč in vprašanj z glasom.'**
  String get settingsVoiceInputDesc;

  /// No description provided for @settingsHapticAlerts.
  ///
  /// In sl, this message translates to:
  /// **'Haptična opozorila'**
  String get settingsHapticAlerts;

  /// No description provided for @settingsHapticAlertsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Različni vzorci tresljajev za prihod, zamudo, iztek vozovnice in motnje.'**
  String get settingsHapticAlertsDesc;

  /// No description provided for @settingsSoundAlerts.
  ///
  /// In sl, this message translates to:
  /// **'Zvočna opozorila (izbirno)'**
  String get settingsSoundAlerts;

  /// No description provided for @settingsSoundAlertsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Predvaja kratek zvočni signal ob pomembnih obvestilih.'**
  String get settingsSoundAlertsDesc;

  /// No description provided for @settingsShowDataSource.
  ///
  /// In sl, this message translates to:
  /// **'Prikaži vir podatkov'**
  String get settingsShowDataSource;

  /// No description provided for @settingsShowDataSourceDesc.
  ///
  /// In sl, this message translates to:
  /// **'Označi, ali so podatki v živo, simulirani ali predpomnjeni.'**
  String get settingsShowDataSourceDesc;

  /// No description provided for @settingsUseSimulatedLive.
  ///
  /// In sl, this message translates to:
  /// **'Simulirani podatki v živo'**
  String get settingsUseSimulatedLive;

  /// No description provided for @settingsUseSimulatedLiveDesc.
  ///
  /// In sl, this message translates to:
  /// **'Uporabi deterministični lokalni simulator vozil Marprom.'**
  String get settingsUseSimulatedLiveDesc;

  /// No description provided for @settingsSimulationSeed.
  ///
  /// In sl, this message translates to:
  /// **'Seme simulacije'**
  String get settingsSimulationSeed;

  /// No description provided for @settingsLocationManual.
  ///
  /// In sl, this message translates to:
  /// **'Ročni način lokacije'**
  String get settingsLocationManual;

  /// No description provided for @settingsLocationManualDesc.
  ///
  /// In sl, this message translates to:
  /// **'Uporabi izbrano postajališče namesto senzorja GPS.'**
  String get settingsLocationManualDesc;

  /// No description provided for @settingsUsabilityTestMode.
  ///
  /// In sl, this message translates to:
  /// **'Način testiranja uporabnosti'**
  String get settingsUsabilityTestMode;

  /// No description provided for @settingsUsabilityTestModeDesc.
  ///
  /// In sl, this message translates to:
  /// **'Prikaže hitra orodja za preizkušanje scenarijev, ponastavitev uvoda in preklop stanja.'**
  String get settingsUsabilityTestModeDesc;

  /// No description provided for @settingsResetOnboarding.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi uvodni zaslon'**
  String get settingsResetOnboarding;

  /// No description provided for @settingsOpenGuide.
  ///
  /// In sl, this message translates to:
  /// **'Odpri vodnik Prvič z avtobusom'**
  String get settingsOpenGuide;

  /// No description provided for @a11yBackButton.
  ///
  /// In sl, this message translates to:
  /// **'Nazaj na prejšnji zaslon'**
  String get a11yBackButton;

  /// No description provided for @a11yCloseButton.
  ///
  /// In sl, this message translates to:
  /// **'Zapri'**
  String get a11yCloseButton;

  /// No description provided for @a11ySearchField.
  ///
  /// In sl, this message translates to:
  /// **'Polje za iskanje'**
  String get a11ySearchField;

  /// No description provided for @a11yVoiceSearchButton.
  ///
  /// In sl, this message translates to:
  /// **'Glasovno iskanje'**
  String get a11yVoiceSearchButton;

  /// No description provided for @a11yReadAloudButton.
  ///
  /// In sl, this message translates to:
  /// **'Preberi na glas'**
  String get a11yReadAloudButton;

  /// No description provided for @a11yFavoriteToggle.
  ///
  /// In sl, this message translates to:
  /// **'Preklopi priljubljeno'**
  String get a11yFavoriteToggle;

  /// No description provided for @a11yQrCode.
  ///
  /// In sl, this message translates to:
  /// **'QR koda vozovnice za odčitavanje na validatorju'**
  String get a11yQrCode;

  /// No description provided for @a11yLineBadge.
  ///
  /// In sl, this message translates to:
  /// **'Avtobusna linija {code}'**
  String a11yLineBadge(String code);

  /// No description provided for @a11yOccupancyBar.
  ///
  /// In sl, this message translates to:
  /// **'Zasedenost avtobusa: {level}'**
  String a11yOccupancyBar(String level);

  /// No description provided for @a11yStatusChip.
  ///
  /// In sl, this message translates to:
  /// **'Status: {label}'**
  String a11yStatusChip(String label);

  /// No description provided for @a11yOfflineBanner.
  ///
  /// In sl, this message translates to:
  /// **'Opozorilo o delovanju brez povezave'**
  String get a11yOfflineBanner;

  /// No description provided for @a11ySimulatedBadge.
  ///
  /// In sl, this message translates to:
  /// **'Oznaka simuliranih podatkov'**
  String get a11ySimulatedBadge;

  /// No description provided for @a11yProfileButton.
  ///
  /// In sl, this message translates to:
  /// **'Odpri uporabniški račun'**
  String get a11yProfileButton;

  /// No description provided for @a11yNoticesButton.
  ///
  /// In sl, this message translates to:
  /// **'Odpri obvestila'**
  String get a11yNoticesButton;

  /// No description provided for @a11ySettingsButton.
  ///
  /// In sl, this message translates to:
  /// **'Odpri nastavitve'**
  String get a11ySettingsButton;

  /// No description provided for @a11ySwapStations.
  ///
  /// In sl, this message translates to:
  /// **'Zamenjaj začetno in ciljno postajališče'**
  String get a11ySwapStations;

  /// No description provided for @homeNextBusSummary.
  ///
  /// In sl, this message translates to:
  /// **'Naslednji avtobus proti {destination}: linija {line} čez {minutes} min, {meters} m stran'**
  String homeNextBusSummary(
    String destination,
    String line,
    int minutes,
    int meters,
  );

  /// No description provided for @homeNoFavoriteStops.
  ///
  /// In sl, this message translates to:
  /// **'Še nimate priljubljenih postajališč. Dodajte jih na zemljevidu ali voznem redu.'**
  String get homeNoFavoriteStops;

  /// No description provided for @homeNextDepartures.
  ///
  /// In sl, this message translates to:
  /// **'Naslednji odhodi'**
  String get homeNextDepartures;

  /// No description provided for @homeActiveDisruptionAlert.
  ///
  /// In sl, this message translates to:
  /// **'Opozorilo o motnji na vaši priljubljeni liniji'**
  String get homeActiveDisruptionAlert;

  /// No description provided for @linesFollowBusLive.
  ///
  /// In sl, this message translates to:
  /// **'Sledi avtobusu v živo'**
  String get linesFollowBusLive;

  /// No description provided for @linesOccupancyBySegment.
  ///
  /// In sl, this message translates to:
  /// **'Zasedenost po odsekih poti'**
  String get linesOccupancyBySegment;

  /// No description provided for @linesDirectionTo.
  ///
  /// In sl, this message translates to:
  /// **'Smer: {destination}'**
  String linesDirectionTo(String destination);

  /// No description provided for @stopAddToFavorites.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj med priljubljene'**
  String get stopAddToFavorites;

  /// No description provided for @stopRemoveFromFavorites.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani iz priljubljenih'**
  String get stopRemoveFromFavorites;

  /// No description provided for @stopPlanFromHere.
  ///
  /// In sl, this message translates to:
  /// **'Načrtuj pot od tukaj'**
  String get stopPlanFromHere;

  /// No description provided for @stopSelectDay.
  ///
  /// In sl, this message translates to:
  /// **'Izberi dan'**
  String get stopSelectDay;

  /// No description provided for @stopAllLines.
  ///
  /// In sl, this message translates to:
  /// **'Vse linije'**
  String get stopAllLines;

  /// No description provided for @stopLiveAndScheduledNote.
  ///
  /// In sl, this message translates to:
  /// **'Časi združujejo zamude v živo s stalnim voznim redom.'**
  String get stopLiveAndScheduledNote;

  /// No description provided for @mapLocationDeniedTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dostop do lokacije ni na voljo'**
  String get mapLocationDeniedTitle;

  /// No description provided for @mapLocationDeniedBody.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacijo lahko še vedno uporabljate v celoti z ročno izbiro začetnega postajališča.'**
  String get mapLocationDeniedBody;

  /// No description provided for @mapSelectManualStop.
  ///
  /// In sl, this message translates to:
  /// **'Izberi začetno postajališče'**
  String get mapSelectManualStop;

  /// No description provided for @mapFollowingLine.
  ///
  /// In sl, this message translates to:
  /// **'Prikaz poti za linijo {code}'**
  String mapFollowingLine(String code);

  /// No description provided for @mapTapStopHint.
  ///
  /// In sl, this message translates to:
  /// **'Dotaknite se postajališča za odhode ali avtobusa za ogled trase.'**
  String get mapTapStopHint;

  /// No description provided for @mapNoNearbyStops.
  ///
  /// In sl, this message translates to:
  /// **'Na tem območju ni najdenih postajališč.'**
  String get mapNoNearbyStops;

  /// No description provided for @mapListDistance.
  ///
  /// In sl, this message translates to:
  /// **'{distance} stran'**
  String mapListDistance(String distance);

  /// No description provided for @trackerSelectLineOrStop.
  ///
  /// In sl, this message translates to:
  /// **'Izberite linijo ali postajališče za sledenje v živo'**
  String get trackerSelectLineOrStop;

  /// No description provided for @trackerDistanceAndEta.
  ///
  /// In sl, this message translates to:
  /// **'{distance} stran • približno {minutes} min'**
  String trackerDistanceAndEta(String distance, int minutes);

  /// No description provided for @trackerNotifyMinutesAway.
  ///
  /// In sl, this message translates to:
  /// **'Obvesti {minutes} min pred prihodom'**
  String trackerNotifyMinutesAway(int minutes);

  /// No description provided for @trackerNoActiveBuses.
  ///
  /// In sl, this message translates to:
  /// **'Na tej liniji trenutno ni aktivnih avtobusov.'**
  String get trackerNoActiveBuses;

  /// No description provided for @trackerEarlyActionTip.
  ///
  /// In sl, this message translates to:
  /// **'Ta avtobus je {minutes} min zgodaj. Lahko odpelje pred voznim redom. Na postajališču bodite {arriveEarlyMin} min prej.'**
  String trackerEarlyActionTip(int minutes, int arriveEarlyMin);

  /// No description provided for @trackerLateActionTip.
  ///
  /// In sl, this message translates to:
  /// **'Ta avtobus zamuja {minutes} min. Predviden prihod ob {time}.'**
  String trackerLateActionTip(int minutes, String time);

  /// No description provided for @trackerNextStepCardTitle.
  ///
  /// In sl, this message translates to:
  /// **'Naslednji korak na vaši poti'**
  String get trackerNextStepCardTitle;

  /// No description provided for @trackerGetOffNextStop.
  ///
  /// In sl, this message translates to:
  /// **'Izstopite na naslednjem postajališču: {stop}'**
  String trackerGetOffNextStop(String stop);

  /// No description provided for @trackerAlertFiredBanner.
  ///
  /// In sl, this message translates to:
  /// **'Avtobus {line} je {minutes} min oddaljen od {stop}!'**
  String trackerAlertFiredBanner(String line, int minutes, String stop);

  /// No description provided for @planNoResultsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Povezava ni najdena'**
  String get planNoResultsTitle;

  /// No description provided for @planNoResultsBody.
  ///
  /// In sl, this message translates to:
  /// **'Za izbrani čas ni ustrezne avtobusne povezave. Poskusite s hojo do vozlišča ali počakajte na naslednji odhod.'**
  String get planNoResultsBody;

  /// No description provided for @planTryWalkFurther.
  ///
  /// In sl, this message translates to:
  /// **'Išči z daljšo hojo'**
  String get planTryWalkFurther;

  /// No description provided for @planTryWaitNext.
  ///
  /// In sl, this message translates to:
  /// **'Preveri poznejše odhode'**
  String get planTryWaitNext;

  /// No description provided for @planWalkTimeAndDistance.
  ///
  /// In sl, this message translates to:
  /// **'Hoja {minutes} min ({distance})'**
  String planWalkTimeAndDistance(int minutes, String distance);

  /// No description provided for @planDataReliability.
  ///
  /// In sl, this message translates to:
  /// **'Zanesljivost podatkov: {source}'**
  String planDataReliability(String source);

  /// No description provided for @planTransferWaitMinutes.
  ///
  /// In sl, this message translates to:
  /// **'Čakanje na prestop: {minutes} min na {stop}'**
  String planTransferWaitMinutes(int minutes, String stop);

  /// No description provided for @planOptionSummary.
  ///
  /// In sl, this message translates to:
  /// **'{totalMin} min • {transfers} • {walkDistance} hoje'**
  String planOptionSummary(int totalMin, String transfers, String walkDistance);

  /// No description provided for @planSelectOrigin.
  ///
  /// In sl, this message translates to:
  /// **'Izberi začetek'**
  String get planSelectOrigin;

  /// No description provided for @planSelectDestination.
  ///
  /// In sl, this message translates to:
  /// **'Izberi cilj'**
  String get planSelectDestination;

  /// No description provided for @nearestStopGoalHint.
  ///
  /// In sl, this message translates to:
  /// **'Poiščite najbližje postajališče z avtobusom do vašega cilja'**
  String get nearestStopGoalHint;

  /// No description provided for @nearestStopSortedByArrival.
  ///
  /// In sl, this message translates to:
  /// **'Razvrščeno po najzgodnejšem prihodu'**
  String get nearestStopSortedByArrival;

  /// No description provided for @nearestStopArrivesAt.
  ///
  /// In sl, this message translates to:
  /// **'Prihod ob {time}'**
  String nearestStopArrivesAt(String time);

  /// No description provided for @ticketsAuthRequiredTitle.
  ///
  /// In sl, this message translates to:
  /// **'Za nakup je potreben račun'**
  String get ticketsAuthRequiredTitle;

  /// No description provided for @ticketsAuthRequiredBody.
  ///
  /// In sl, this message translates to:
  /// **'Vrste vozovnic si lahko ogledate kot gost. Prijavite se ali ustvarite brezplačen testni račun za nakup in shranjevanje.'**
  String get ticketsAuthRequiredBody;

  /// No description provided for @ticketsStepChoose.
  ///
  /// In sl, this message translates to:
  /// **'1. Vozovnica'**
  String get ticketsStepChoose;

  /// No description provided for @ticketsStepPayment.
  ///
  /// In sl, this message translates to:
  /// **'2. Plačilo'**
  String get ticketsStepPayment;

  /// No description provided for @ticketsStepConfirm.
  ///
  /// In sl, this message translates to:
  /// **'3. Potrditev'**
  String get ticketsStepConfirm;

  /// No description provided for @ticketsValidFromUntil.
  ///
  /// In sl, this message translates to:
  /// **'Velja od {from} do {until}'**
  String ticketsValidFromUntil(String from, String until);

  /// No description provided for @ticketsStartNow.
  ///
  /// In sl, this message translates to:
  /// **'Velja takoj (priporočeno)'**
  String get ticketsStartNow;

  /// No description provided for @ticketsStartLater.
  ///
  /// In sl, this message translates to:
  /// **'Izberi čas začetka'**
  String get ticketsStartLater;

  /// No description provided for @ticketsTabUpcoming.
  ///
  /// In sl, this message translates to:
  /// **'Prihajajoče'**
  String get ticketsTabUpcoming;

  /// No description provided for @ticketsTabExpired.
  ///
  /// In sl, this message translates to:
  /// **'Potekle'**
  String get ticketsTabExpired;

  /// No description provided for @ticketsDriverFallbackCode.
  ///
  /// In sl, this message translates to:
  /// **'Nadomestna koda za voznika: {code}'**
  String ticketsDriverFallbackCode(String code);

  /// No description provided for @ticketsLiveClockNote.
  ///
  /// In sl, this message translates to:
  /// **'Ura v živo preprečuje zlorabo posnetkov zaslona'**
  String get ticketsLiveClockNote;

  /// No description provided for @ticketsNfcComingSoon.
  ///
  /// In sl, this message translates to:
  /// **'Kartica NFC v aplikaciji bo kmalu na voljo'**
  String get ticketsNfcComingSoon;

  /// No description provided for @ticketsDemoPaymentNotice.
  ///
  /// In sl, this message translates to:
  /// **'Demo plačilo — pravi denar se ne bremeni'**
  String get ticketsDemoPaymentNotice;

  /// No description provided for @ticketsNoActiveTickets.
  ///
  /// In sl, this message translates to:
  /// **'Trenutno nimate aktivnih vozovnic.'**
  String get ticketsNoActiveTickets;

  /// No description provided for @ticketsNoUpcomingTickets.
  ///
  /// In sl, this message translates to:
  /// **'Ni prihajajočih vozovnic.'**
  String get ticketsNoUpcomingTickets;

  /// No description provided for @ticketsNoExpiredTickets.
  ///
  /// In sl, this message translates to:
  /// **'Ni poteklih vozovnic.'**
  String get ticketsNoExpiredTickets;

  /// No description provided for @ticketsRemainingTime.
  ///
  /// In sl, this message translates to:
  /// **'Preostane: {time}'**
  String ticketsRemainingTime(String time);

  /// No description provided for @paymentsCard.
  ///
  /// In sl, this message translates to:
  /// **'Plačilna kartica'**
  String get paymentsCard;

  /// No description provided for @paymentsGooglePay.
  ///
  /// In sl, this message translates to:
  /// **'Google Pay'**
  String get paymentsGooglePay;

  /// No description provided for @paymentsApplePay.
  ///
  /// In sl, this message translates to:
  /// **'Apple Pay'**
  String get paymentsApplePay;

  /// No description provided for @paymentsBankTransfer.
  ///
  /// In sl, this message translates to:
  /// **'Bančno nakazilo / spletna banka'**
  String get paymentsBankTransfer;

  /// No description provided for @paymentsMobilePay.
  ///
  /// In sl, this message translates to:
  /// **'Mobilno plačilo'**
  String get paymentsMobilePay;

  /// No description provided for @paymentsCardBrandLabel.
  ///
  /// In sl, this message translates to:
  /// **'Znamka kartice (npr. Visa)'**
  String get paymentsCardBrandLabel;

  /// No description provided for @paymentsLast4Label.
  ///
  /// In sl, this message translates to:
  /// **'Samo zadnje 4 številke (demo)'**
  String get paymentsLast4Label;

  /// No description provided for @paymentsLast4Validation.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite natančno 4 številke'**
  String get paymentsLast4Validation;

  /// No description provided for @paymentsSetDefault.
  ///
  /// In sl, this message translates to:
  /// **'Nastavi kot privzeto'**
  String get paymentsSetDefault;

  /// No description provided for @accountSignUp.
  ///
  /// In sl, this message translates to:
  /// **'Ustvari račun'**
  String get accountSignUp;

  /// No description provided for @accountPasswordReset.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi geslo'**
  String get accountPasswordReset;

  /// No description provided for @accountDeleteAccount.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši moj račun in podatke'**
  String get accountDeleteAccount;

  /// No description provided for @accountDeleteConfirmTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izbrisati račun in vse lokalne podatke?'**
  String get accountDeleteConfirmTitle;

  /// No description provided for @accountDeleteConfirmBody.
  ///
  /// In sl, this message translates to:
  /// **'To izbriše vaš testni profil, shranjene vozovnice, plačilne kartice in nastavitve s te naprave.'**
  String get accountDeleteConfirmBody;

  /// No description provided for @accountNameLabel.
  ///
  /// In sl, this message translates to:
  /// **'Ime in priimek'**
  String get accountNameLabel;

  /// No description provided for @accountEmailLabel.
  ///
  /// In sl, this message translates to:
  /// **'E-poštni naslov'**
  String get accountEmailLabel;

  /// No description provided for @accountPasswordLabel.
  ///
  /// In sl, this message translates to:
  /// **'Geslo'**
  String get accountPasswordLabel;

  /// No description provided for @accountDobLabel.
  ///
  /// In sl, this message translates to:
  /// **'Datum rojstva'**
  String get accountDobLabel;

  /// No description provided for @accountDemoAccountHint.
  ///
  /// In sl, this message translates to:
  /// **'Demo uporabnik: demo@marprom.si / demo1234'**
  String get accountDemoAccountHint;

  /// No description provided for @accountYouthEligible.
  ///
  /// In sl, this message translates to:
  /// **'Upravičeni do mladinske / študentske cene'**
  String get accountYouthEligible;

  /// No description provided for @accountSeniorEligible.
  ///
  /// In sl, this message translates to:
  /// **'Upravičeni do upokojenske cene'**
  String get accountSeniorEligible;

  /// No description provided for @accountResetSent.
  ///
  /// In sl, this message translates to:
  /// **'Testna povezava za ponastavitev gesla pripravljena za {email}.'**
  String accountResetSent(String email);

  /// No description provided for @accountSaveProfile.
  ///
  /// In sl, this message translates to:
  /// **'Shrani profil'**
  String get accountSaveProfile;

  /// No description provided for @onboardingConsentLocation.
  ///
  /// In sl, this message translates to:
  /// **'Dovoli lokacijo med uporabo aplikacije za najbližja postajališča (v testnem načinu ne zapusti naprave)'**
  String get onboardingConsentLocation;

  /// No description provided for @onboardingConsentNotifications.
  ///
  /// In sl, this message translates to:
  /// **'Dovoli opozorila za prihod, zamudo in iztek vozovnice'**
  String get onboardingConsentNotifications;

  /// No description provided for @onboardingConsentAnalytics.
  ///
  /// In sl, this message translates to:
  /// **'Izbirna anonimna statistika uporabe (privzeto izklopljeno)'**
  String get onboardingConsentAnalytics;

  /// No description provided for @onboardingAccountOptionalNote.
  ///
  /// In sl, this message translates to:
  /// **'Račun je zdaj neobvezen in potreben šele pozneje ob nakupu vozovnice.'**
  String get onboardingAccountOptionalNote;

  /// No description provided for @noticesTriggerAlternative.
  ///
  /// In sl, this message translates to:
  /// **'Poišči drugo pot'**
  String get noticesTriggerAlternative;

  /// No description provided for @noticesSmartBusArriving.
  ///
  /// In sl, this message translates to:
  /// **'Opozorilo ob skorajšnjem prihodu avtobusa'**
  String get noticesSmartBusArriving;

  /// No description provided for @noticesSmartLineDelayed.
  ///
  /// In sl, this message translates to:
  /// **'Opozorilo ob zamudi priljubljene linije'**
  String get noticesSmartLineDelayed;

  /// No description provided for @noticesSmartTicketExpiring.
  ///
  /// In sl, this message translates to:
  /// **'Opozorilo pred iztekom vozovnice'**
  String get noticesSmartTicketExpiring;

  /// No description provided for @noticesPreviewVibration.
  ///
  /// In sl, this message translates to:
  /// **'Preizkusi vizualno in vibracijsko opozorilo'**
  String get noticesPreviewVibration;

  /// No description provided for @settingsClearLocalData.
  ///
  /// In sl, this message translates to:
  /// **'Počisti lokalni predpomnilnik'**
  String get settingsClearLocalData;

  /// No description provided for @settingsClearLocalDataDone.
  ///
  /// In sl, this message translates to:
  /// **'Lokalni predpomnilnik je počiščen.'**
  String get settingsClearLocalDataDone;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In sl, this message translates to:
  /// **'O aplikaciji M Mobilnost 2.0'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutBody.
  ///
  /// In sl, this message translates to:
  /// **'Dostopen enotni prototip javnega prevoza in vozovnic Marprom za Maribor. Simulirani podatki v živo so jasno označeni.'**
  String get settingsAboutBody;

  /// No description provided for @settingsUsabilityStart.
  ///
  /// In sl, this message translates to:
  /// **'Začni merjeni scenarij'**
  String get settingsUsabilityStart;

  /// No description provided for @settingsUsabilityFinish.
  ///
  /// In sl, this message translates to:
  /// **'Zaključi scenarij'**
  String get settingsUsabilityFinish;

  /// No description provided for @settingsUsabilityRecordError.
  ///
  /// In sl, this message translates to:
  /// **'Zabeleži napako (+1)'**
  String get settingsUsabilityRecordError;

  /// No description provided for @settingsUsabilityExportCsv.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi CSV'**
  String get settingsUsabilityExportCsv;

  /// No description provided for @settingsUsabilityExportJson.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi JSON'**
  String get settingsUsabilityExportJson;

  /// No description provided for @settingsUsabilitySummary.
  ///
  /// In sl, this message translates to:
  /// **'Čas: {seconds} s • Dotiki: {taps} • Napake: {errors}'**
  String settingsUsabilitySummary(int seconds, int taps, int errors);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'sl', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'sr':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsSrLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'sl':
      return AppLocalizationsSl();
    case 'sr':
      return AppLocalizationsSr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
