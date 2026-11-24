// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get navHome => 'Home';

  @override
  String get navMap => 'Map';

  @override
  String get navPlan => 'Plan';

  @override
  String get navTickets => 'Tickets';

  @override
  String get navLines => 'Lines';

  @override
  String get navNotices => 'Notices';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAccount => 'Account';

  @override
  String get navMore => 'More';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonEmpty => 'Nothing to display yet.';

  @override
  String get commonErrorTitle => 'Something went wrong';

  @override
  String get commonErrorBody =>
      'Unable to load data right now. Please check your connection and try again.';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonAll => 'All';

  @override
  String get commonFavorites => 'Favorites';

  @override
  String get commonShowMore => 'Show more';

  @override
  String get commonShowLess => 'Show less';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonOk => 'OK';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get commonPlaceholderNotice =>
      'This screen will be completed in the next development phase.';

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
      other: '$count minutes',
      one: '$count minute',
      zero: 'less than a minute',
    );
    return '$_temp0';
  }

  @override
  String commonStopsPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '$count stop',
      zero: '0 stops',
    );
    return '$_temp0';
  }

  @override
  String commonTransfersPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '$count transfer',
      zero: 'no transfers',
    );
    return '$_temp0';
  }

  @override
  String commonBusesPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses',
      one: '$count bus',
      zero: 'no buses',
    );
    return '$_temp0';
  }

  @override
  String commonUpdatedAgo(String time) {
    return 'Updated $time ago';
  }

  @override
  String commonLastUpdatedAt(String time) {
    return 'Last updated: $time';
  }

  @override
  String get commonJustNow => 'just now';

  @override
  String get statusEarly => 'Early';

  @override
  String get statusOnTime => 'On time';

  @override
  String get statusLate => 'Late';

  @override
  String get statusInfo => 'Info';

  @override
  String get statusWarning => 'Warning';

  @override
  String get statusDisruption => 'Disruption';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusDetour => 'Detour';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String statusEarlyByMinutes(int minutes) {
    return '$minutes min early';
  }

  @override
  String statusLateByMinutes(int minutes) {
    return '+$minutes min late';
  }

  @override
  String get statusArrivingNow => 'Arriving now';

  @override
  String statusDepartingIn(int minutes) {
    return 'Departs in $minutes min';
  }

  @override
  String get badgeOfflineTitle => 'Offline mode';

  @override
  String get badgeOfflineBody => 'Showing cached timetables and saved tickets.';

  @override
  String badgeOfflineLastSync(String time) {
    return 'Last synced: $time';
  }

  @override
  String get badgeSimulatedLabel => 'Simulated data';

  @override
  String get badgeSimulatedTooltip =>
      'Live positions and times are simulated locally for demonstration and testing.';

  @override
  String get badgeSimulatedDisclaimer =>
      'Live feeds are in simulation mode. Times are illustrative.';

  @override
  String get freshnessLive => 'Live data';

  @override
  String get freshnessSimulated => 'Simulated live';

  @override
  String get freshnessCached => 'Cached';

  @override
  String get freshnessStale => 'May be outdated';

  @override
  String get freshnessLiveDisabledFallback =>
      'Live data not available, showing timetable';

  @override
  String get occupancyLabel => 'Occupancy';

  @override
  String get occupancyLow => 'Plenty of seats';

  @override
  String get occupancyMedium => 'Moderate';

  @override
  String get occupancyHigh => 'Crowded';

  @override
  String get occupancyFull => 'Bus is full';

  @override
  String get occupancyUnknown => 'Occupancy unknown';

  @override
  String get onboardingWelcomeTitle => 'Welcome to M Mobilnost 2.0';

  @override
  String get onboardingWelcomeSubtitle =>
      'Your accessible, reliable guide to Marprom city buses in Maribor.';

  @override
  String get onboardingChooseLanguage => 'Choose app language';

  @override
  String get onboardingAccessibilityTitle => 'Accessibility preferences';

  @override
  String get onboardingAccessibilitySubtitle =>
      'Customize readability and voice features now or anytime in Settings.';

  @override
  String get onboardingLocationTitle => 'Location & privacy';

  @override
  String get onboardingLocationSubtitle =>
      'Allow GPS for nearby stops or pick a Maribor stop manually without GPS.';

  @override
  String get onboardingUseGps => 'Use GPS location';

  @override
  String get onboardingUseManualLocation => 'Choose stop manually (no GPS)';

  @override
  String get onboardingStartRiding => 'Start riding';

  @override
  String get onboardingOpenGuide => 'New to the bus? Open guide';

  @override
  String get guideTitle => 'New to the bus';

  @override
  String get guideSubtitle =>
      'A 5-step guide to stress-free city bus travel in Maribor.';

  @override
  String guideCardProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get guideCard1Title => '1. Find your stop & line';

  @override
  String get guideCard1Body =>
      'Check the nearest stop on the map or browse the Lines list. Every departure shows the line number and destination.';

  @override
  String get guideCard2Title => '2. Buy or prepare your ticket';

  @override
  String get guideCard2Body =>
      'Purchase a ticket in the Tickets tab. Before boarding, open it so screen brightness boosts automatically for QR scanning.';

  @override
  String get guideCard3Title => '3. Board at the front door';

  @override
  String get guideCard3Body =>
      'Signal clearly to the driver as the bus approaches. Board via the front door and validate your ticket.';

  @override
  String get guideCard4Title => '4. Follow your ride live';

  @override
  String get guideCard4Body =>
      'Use the live tracker to see upcoming stops, estimated arrival, and receive an alert before your stop.';

  @override
  String get guideCard5Title => '5. Getting off & transfers';

  @override
  String get guideCard5Body =>
      'Press STOP before your destination stop. When transferring, watch for tight-connection warnings.';

  @override
  String get guideFinishCta => 'Got it, let\'s ride';

  @override
  String get homeGreeting => 'Where are we going today?';

  @override
  String get homeSearchHint => 'Search destination, stop, or line...';

  @override
  String get homeFavoriteStops => 'Favorite stops';

  @override
  String get homeNearbyStops => 'Nearby stops';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homeActiveTicket => 'Active ticket';

  @override
  String get homeNoActiveTicket => 'No active ticket right now';

  @override
  String get homeNearestStopAction => 'Nearest stop';

  @override
  String get homePlanTripAction => 'Plan trip';

  @override
  String get homeBuyTicketAction => 'Buy ticket';

  @override
  String get homeLinesAction => 'Lines & timetables';

  @override
  String get homeGuideAction => 'New to the bus';

  @override
  String get homeAskMarpromAction => 'Ask Marprom';

  @override
  String get askTitle => 'Ask Marprom';

  @override
  String get askSubtitle =>
      'Quick assistant for lines, departures, and tickets';

  @override
  String get askInputHint => 'Ask e.g. When is the next bus 6?';

  @override
  String get askSend => 'Send';

  @override
  String get askVoicePrompt => 'Listening...';

  @override
  String get askSample1 => 'When is the next bus from Glavni trg?';

  @override
  String get askSample2 => 'Which ticket is best for today?';

  @override
  String get askSample3 => 'Are there any disruptions or detours today?';

  @override
  String get askSample4 => 'Where is the nearest bus stop?';

  @override
  String get askClearChat => 'Clear chat';

  @override
  String get askDisclaimer =>
      'Answers use local Marprom schedules and simulated live data.';

  @override
  String get askNoMatch =>
      'I don\'t have an exact answer for that. Try asking about a line, stop, ticket, or disruption.';

  @override
  String get linesTitle => 'Lines & timetables';

  @override
  String get linesSearchHint => 'Search line or terminus...';

  @override
  String linesBadge(String code) {
    return 'Line $code';
  }

  @override
  String get linesDirectionLabel => 'Direction';

  @override
  String get linesSwapDirection => 'Reverse direction';

  @override
  String get linesScheduleWeekday => 'Weekday';

  @override
  String get linesScheduleSaturday => 'Saturday';

  @override
  String get linesScheduleSunday => 'Sunday / holiday';

  @override
  String get linesFirstBus => 'First bus';

  @override
  String get linesLastBus => 'Last bus';

  @override
  String get linesLowFloor => 'Low-floor accessible bus';

  @override
  String get linesFavoriteAdd => 'Add to favorites';

  @override
  String get linesFavoriteRemove => 'Remove from favorites';

  @override
  String get linesNoDepartures => 'No more departures for the selected day.';

  @override
  String get mapTitle => 'Stop map';

  @override
  String get mapSwitchToList => 'List';

  @override
  String get mapSwitchToMap => 'Map';

  @override
  String get mapSearchHint => 'Search stop or street...';

  @override
  String get mapCenterOnMe => 'My location';

  @override
  String get mapManualCenter => 'Maribor center';

  @override
  String get mapFilterAccessible => 'Step-free accessible';

  @override
  String get mapFilterActiveBuses => 'Live buses';

  @override
  String get mapStopDetailsOpen => 'View stop departures';

  @override
  String get stopTitle => 'Stop';

  @override
  String stopPlatform(String platform) {
    return 'Platform $platform';
  }

  @override
  String get stopUpcomingDepartures => 'Upcoming departures';

  @override
  String get stopAmenitiesTitle => 'Stop facilities';

  @override
  String get stopAmenityShelter => 'Shelter';

  @override
  String get stopAmenityBench => 'Bench';

  @override
  String get stopAmenityTactile => 'Tactile paving';

  @override
  String get stopAmenityStepFree => 'Step-free access';

  @override
  String get stopAmenityDisplay => 'Digital display';

  @override
  String get stopNoDepartures => 'No scheduled departures in the next hours.';

  @override
  String get trackerTitle => 'Live tracker';

  @override
  String get trackerFollowBus => 'Follow bus';

  @override
  String get trackerNextStop => 'Next stop';

  @override
  String get trackerStopsRemaining => 'Stops remaining';

  @override
  String get trackerEta => 'Estimated arrival';

  @override
  String trackerScheduledTime(String time) {
    return 'Scheduled: $time';
  }

  @override
  String get trackerNotifyMe => 'Notify me';

  @override
  String get trackerNotifyCancel => 'Cancel alert';

  @override
  String get trackerNotifyActive =>
      'Alert set: you will be notified before arrival.';

  @override
  String get trackerNotifyPrompt => 'Choose when to receive an arrival alert.';

  @override
  String get trackerAdviceEarlyTitle => 'Bus is running early';

  @override
  String trackerAdviceEarlyBody(int minutes) {
    return 'This bus is $minutes min early. Head to the stop sooner or review the next departure if you are still on your way.';
  }

  @override
  String get trackerAdviceOnTimeTitle => 'Bus is running on time';

  @override
  String get trackerAdviceOnTimeBody => 'Expect arrival at the scheduled time.';

  @override
  String get trackerAdviceLateTitle => 'Bus is delayed';

  @override
  String trackerAdviceLateBody(int minutes) {
    return 'This bus is $minutes min late. You can wait at the stop or check alternative routes below.';
  }

  @override
  String get trackerAdviceReviewAlternatives => 'Review alternatives';

  @override
  String get planTitle => 'Trip planner';

  @override
  String get planOriginLabel => 'Origin';

  @override
  String get planDestinationLabel => 'Destination';

  @override
  String get planCurrentLocation => 'Current location';

  @override
  String get planSwap => 'Swap origin and destination';

  @override
  String get planLeaveNow => 'Leave now';

  @override
  String get planDepartAt => 'Depart at';

  @override
  String get planArriveBy => 'Arrive by';

  @override
  String get planAccessibleOnly => 'Step-free accessible routes only';

  @override
  String get planFewerTransfers => 'Fewer transfers';

  @override
  String get planFindRoutes => 'Find routes';

  @override
  String get planTightTransferTitle => 'Tight transfer';

  @override
  String planTightTransferBody(int minutes) {
    return 'You only have $minutes min to transfer. A slight delay on the first bus may cause a missed connection.';
  }

  @override
  String get planWhatDoINextTitle => 'What do I do next?';

  @override
  String planStepWalkTo(String stop, String distance) {
    return 'Walk to $stop ($distance)';
  }

  @override
  String planStepBoardLine(String line, String direction) {
    return 'Board line $line towards $direction';
  }

  @override
  String planStepRideStops(String stops, String stop) {
    return 'Ride $stops to $stop';
  }

  @override
  String planStepTransferAt(String stop) {
    return 'Transfer at $stop';
  }

  @override
  String planStepGetOffAt(String stop) {
    return 'Get off at $stop';
  }

  @override
  String get planStepArrived => 'You have arrived at your destination.';

  @override
  String get nearestStopTitle => 'Nearest stop';

  @override
  String nearestStopDistance(String distance) {
    return 'Distance: $distance';
  }

  @override
  String nearestStopWalkTime(int minutes) {
    return 'About $minutes min walk';
  }

  @override
  String get nearestStopNextBus => 'Next departure';

  @override
  String get nearestStopUseManual => 'Choose stop manually';

  @override
  String get ticketsTitle => 'My tickets';

  @override
  String get ticketsActiveTab => 'Active';

  @override
  String get ticketsHistoryTab => 'Past';

  @override
  String get ticketsBuyButton => 'Buy ticket';

  @override
  String get ticketsShopTitle => 'Ticket shop';

  @override
  String get ticketsCheckoutTitle => 'Checkout';

  @override
  String get ticketsViewTitle => 'Active ticket';

  @override
  String get ticketsZoneMaribor => 'Maribor Zone';

  @override
  String ticketsValidUntil(String time) {
    return 'Valid until $time';
  }

  @override
  String get ticketsQrHint => 'Hold the QR code to the bus validator.';

  @override
  String get ticketsBrightnessBoosted =>
      'Screen brightness temporarily boosted for easy scanning.';

  @override
  String get ticketsNfcStubTitle => 'Contactless validation (NFC)';

  @override
  String get ticketsNfcStubBody =>
      'Simulated NFC tap validation when boarding. Hold your phone near the reader.';

  @override
  String get ticketsNfcTapToSimulate => 'Simulate NFC tap';

  @override
  String get ticketsNfcValidated => 'Ticket validated successfully.';

  @override
  String get ticketsQuantity => 'Quantity';

  @override
  String get ticketsTotalPrice => 'Total';

  @override
  String get ticketsPayNow => 'Pay now';

  @override
  String get ticketsPurchaseSuccess => 'Ticket purchased and ready to use.';

  @override
  String get ticketsMinorTitle => 'Parent or guardian confirmation';

  @override
  String get ticketsMinorUnder16Warning =>
      'Passengers under 16 require parent or legal guardian confirmation for online purchases.';

  @override
  String get ticketsMinorUnder18Notice =>
      'Passengers aged 16–18 must confirm permission for digital purchases.';

  @override
  String get ticketsMinorGuardianConfirm =>
      'I confirm I have parent or guardian permission.';

  @override
  String get ticketsMinorGuardianEmail => 'Parent or guardian email';

  @override
  String get paymentsTitle => 'Payment methods';

  @override
  String get paymentsAddMethod => 'Add payment method';

  @override
  String get paymentsDefaultBadge => 'Default';

  @override
  String get paymentsSimulatedNotice =>
      'All payment flows are locally simulated in this prototype.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountGuestMode => 'Guest mode';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountManagePayments => 'Manage payments';

  @override
  String get accountGdprTitle => 'Privacy & consent (GDPR)';

  @override
  String get accountGdprDescription =>
      'Manage your consent for analytics, notifications, and local data storage.';

  @override
  String get accountGdprAnalytics => 'Anonymous usage analytics';

  @override
  String get accountGdprNotifications => 'Delay push notifications';

  @override
  String get accountGdprExport => 'Export my data';

  @override
  String get accountGdprDelete => 'Delete local data';

  @override
  String get accountGdprPrivacyLink => 'Privacy policy';

  @override
  String get noticesTitle => 'Notices & smart alerts';

  @override
  String get noticesAllTab => 'All notices';

  @override
  String get noticesDisruptionsTab => 'Disruptions';

  @override
  String get noticesSmartAlertsTitle => 'Smart alerts';

  @override
  String get noticesSmartAlertsDesc =>
      'Get notified before your bus arrives, on favorite line disruptions, and before tickets expire.';

  @override
  String get noticesMarkAllRead => 'Mark all as read';

  @override
  String get noticesEmpty => 'No new notices right now.';

  @override
  String noticesAffectedLines(String lines) {
    return 'Affected lines: $lines';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsSectionAccessibility => 'Accessibility & speech';

  @override
  String get settingsSectionData => 'Data & location';

  @override
  String get settingsSectionPrivacy => 'Privacy';

  @override
  String get settingsSectionUsability => 'Usability testing & demo';

  @override
  String get settingsThemeMode => 'Color theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeHighContrast => 'High contrast (AAA)';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsExtraLargeText => 'Extra-large text (up to 200%)';

  @override
  String get settingsExtraLargeTextDesc =>
      'Scales typography across the app for maximum legibility.';

  @override
  String get settingsReducedMotion => 'Reduced motion';

  @override
  String get settingsReducedMotionDesc =>
      'Disables screen transitions and motion animations.';

  @override
  String get settingsReadAloud => 'Read aloud (TTS)';

  @override
  String get settingsReadAloudDesc =>
      'Speaks key instructions, departures, and alerts.';

  @override
  String get settingsVoiceInput => 'Voice input';

  @override
  String get settingsVoiceInputDesc =>
      'Enables voice search for stops and Ask Marprom.';

  @override
  String get settingsHapticAlerts => 'Haptic alerts';

  @override
  String get settingsHapticAlertsDesc =>
      'Distinct vibration cues for arriving, late, ticket expiring, and disruptions.';

  @override
  String get settingsSoundAlerts => 'Optional sound alerts';

  @override
  String get settingsSoundAlertsDesc =>
      'Plays a short audio cue on important notifications.';

  @override
  String get settingsShowDataSource => 'Show data source badge';

  @override
  String get settingsShowDataSourceDesc =>
      'Indicates whether data is live, simulated, or cached.';

  @override
  String get settingsUseSimulatedLive => 'Simulated live data';

  @override
  String get settingsUseSimulatedLiveDesc =>
      'Uses the deterministic local Marprom fleet simulator.';

  @override
  String get settingsSimulationSeed => 'Simulation seed';

  @override
  String get settingsLocationManual => 'Manual location mode';

  @override
  String get settingsLocationManualDesc =>
      'Use a chosen stop instead of the GPS sensor.';

  @override
  String get settingsUsabilityTestMode => 'Usability test mode';

  @override
  String get settingsUsabilityTestModeDesc =>
      'Shows quick tools for scenario testing, resetting onboarding, and state inspection.';

  @override
  String get settingsResetOnboarding => 'Reset onboarding flow';

  @override
  String get settingsOpenGuide => 'Open New to the bus guide';

  @override
  String get a11yBackButton => 'Back to previous screen';

  @override
  String get a11yCloseButton => 'Close';

  @override
  String get a11ySearchField => 'Search input field';

  @override
  String get a11yVoiceSearchButton => 'Voice search';

  @override
  String get a11yReadAloudButton => 'Read aloud';

  @override
  String get a11yFavoriteToggle => 'Toggle favorite';

  @override
  String get a11yQrCode => 'Ticket QR code for bus validator scanning';

  @override
  String a11yLineBadge(String code) {
    return 'Bus line $code';
  }

  @override
  String a11yOccupancyBar(String level) {
    return 'Bus occupancy: $level';
  }

  @override
  String a11yStatusChip(String label) {
    return 'Status: $label';
  }

  @override
  String get a11yOfflineBanner => 'Offline status notice';

  @override
  String get a11ySimulatedBadge => 'Simulated data indicator';

  @override
  String get a11yProfileButton => 'Open account';

  @override
  String get a11yNoticesButton => 'Open notices';

  @override
  String get a11ySettingsButton => 'Open settings';

  @override
  String get a11ySwapStations => 'Swap origin and destination stops';

  @override
  String homeNextBusSummary(
    String destination,
    String line,
    int minutes,
    int meters,
  ) {
    return 'Next bus to $destination: line $line in $minutes min, $meters m from you';
  }

  @override
  String get homeNoFavoriteStops =>
      'No favourite stops yet. Add stops from the map or timetable.';

  @override
  String get homeNextDepartures => 'Next departures';

  @override
  String get homeActiveDisruptionAlert =>
      'Service alert on your favourite line';

  @override
  String get linesFollowBusLive => 'Follow a bus live';

  @override
  String get linesOccupancyBySegment => 'Crowding by route segment';

  @override
  String linesDirectionTo(String destination) {
    return 'Direction: $destination';
  }

  @override
  String get stopAddToFavorites => 'Add to favourites';

  @override
  String get stopRemoveFromFavorites => 'Remove from favourites';

  @override
  String get stopPlanFromHere => 'Plan a trip from here';

  @override
  String get stopSelectDay => 'Select day';

  @override
  String get stopAllLines => 'All lines';

  @override
  String get stopLiveAndScheduledNote =>
      'Times combine live delays with the static timetable.';

  @override
  String get mapLocationDeniedTitle => 'Location access unavailable';

  @override
  String get mapLocationDeniedBody =>
      'You can still use the app fully by choosing your starting stop manually.';

  @override
  String get mapSelectManualStop => 'Choose starting stop';

  @override
  String mapFollowingLine(String code) {
    return 'Showing route for line $code';
  }

  @override
  String get mapTapStopHint =>
      'Tap a stop for departures or tap a bus to view its route.';

  @override
  String get mapNoNearbyStops => 'No stops found within this area.';

  @override
  String mapListDistance(String distance) {
    return '$distance away';
  }

  @override
  String get trackerSelectLineOrStop =>
      'Pick a line or stop to follow a bus live';

  @override
  String trackerDistanceAndEta(String distance, int minutes) {
    return '$distance away • about $minutes min';
  }

  @override
  String trackerNotifyMinutesAway(int minutes) {
    return 'Notify $minutes min before arrival';
  }

  @override
  String get trackerNoActiveBuses =>
      'No buses are currently active on this line.';

  @override
  String trackerEarlyActionTip(int minutes, int arriveEarlyMin) {
    return 'This bus is $minutes min early. It may leave before the timetable time. Be at the stop $arriveEarlyMin min sooner.';
  }

  @override
  String trackerLateActionTip(int minutes, String time) {
    return 'This bus is $minutes min late. Expected at $time.';
  }

  @override
  String get trackerNextStepCardTitle => 'Next step on your trip';

  @override
  String trackerGetOffNextStop(String stop) {
    return 'Get off at the next stop: $stop';
  }

  @override
  String trackerAlertFiredBanner(String line, int minutes, String stop) {
    return 'Bus $line is $minutes min away from $stop!';
  }

  @override
  String get planNoResultsTitle => 'No route found';

  @override
  String get planNoResultsBody =>
      'No matching bus trip was found for this time. Try walking to a hub stop or waiting for the next departure.';

  @override
  String get planTryWalkFurther => 'Search with longer walk';

  @override
  String get planTryWaitNext => 'Check later departures';

  @override
  String planWalkTimeAndDistance(int minutes, String distance) {
    return 'Walk $minutes min ($distance)';
  }

  @override
  String planDataReliability(String source) {
    return 'Data reliability: $source';
  }

  @override
  String planTransferWaitMinutes(int minutes, String stop) {
    return 'Transfer wait: $minutes min at $stop';
  }

  @override
  String planOptionSummary(
    int totalMin,
    String transfers,
    String walkDistance,
  ) {
    return '$totalMin min • $transfers • $walkDistance walk';
  }

  @override
  String get planSelectOrigin => 'Choose start';

  @override
  String get planSelectDestination => 'Choose destination';

  @override
  String get nearestStopGoalHint =>
      'Find the nearest stop with a bus to your destination';

  @override
  String get nearestStopSortedByArrival => 'Sorted by earliest arrival time';

  @override
  String nearestStopArrivesAt(String time) {
    return 'Arrives $time';
  }

  @override
  String get ticketsAuthRequiredTitle => 'Account needed to buy tickets';

  @override
  String get ticketsAuthRequiredBody =>
      'You can browse all ticket types as a guest. Sign in or create a free mock account to buy and save tickets.';

  @override
  String get ticketsStepChoose => '1. Ticket';

  @override
  String get ticketsStepPayment => '2. Payment';

  @override
  String get ticketsStepConfirm => '3. Confirm';

  @override
  String ticketsValidFromUntil(String from, String until) {
    return 'Valid from $from until $until';
  }

  @override
  String get ticketsStartNow => 'Valid immediately (recommended)';

  @override
  String get ticketsStartLater => 'Choose start time';

  @override
  String get ticketsTabUpcoming => 'Upcoming';

  @override
  String get ticketsTabExpired => 'Expired';

  @override
  String ticketsDriverFallbackCode(String code) {
    return 'Driver fallback code: $code';
  }

  @override
  String get ticketsLiveClockNote => 'Live clock prevents screenshot misuse';

  @override
  String get ticketsNfcComingSoon => 'NFC card in app coming soon';

  @override
  String get ticketsDemoPaymentNotice =>
      'Demo payment — no real money is charged';

  @override
  String get ticketsNoActiveTickets => 'You have no active tickets yet.';

  @override
  String get ticketsNoUpcomingTickets => 'No upcoming tickets.';

  @override
  String get ticketsNoExpiredTickets => 'No expired tickets.';

  @override
  String ticketsRemainingTime(String time) {
    return 'Remaining: $time';
  }

  @override
  String get paymentsCard => 'Payment card';

  @override
  String get paymentsGooglePay => 'Google Pay';

  @override
  String get paymentsApplePay => 'Apple Pay';

  @override
  String get paymentsBankTransfer => 'Bank transfer / e-banking';

  @override
  String get paymentsMobilePay => 'Mobile payment';

  @override
  String get paymentsCardBrandLabel => 'Card brand (e.g. Visa)';

  @override
  String get paymentsLast4Label => 'Last 4 digits only (demo)';

  @override
  String get paymentsLast4Validation => 'Enter exactly 4 digits';

  @override
  String get paymentsSetDefault => 'Set as default';

  @override
  String get accountSignUp => 'Create account';

  @override
  String get accountPasswordReset => 'Reset password';

  @override
  String get accountDeleteAccount => 'Delete my account and data';

  @override
  String get accountDeleteConfirmTitle => 'Delete account and all local data?';

  @override
  String get accountDeleteConfirmBody =>
      'This clears your mock profile, saved tickets, payment cards, and settings from this device.';

  @override
  String get accountNameLabel => 'Full name';

  @override
  String get accountEmailLabel => 'Email address';

  @override
  String get accountPasswordLabel => 'Password';

  @override
  String get accountDobLabel => 'Date of birth';

  @override
  String get accountDemoAccountHint => 'Demo user: demo@marprom.si / demo1234';

  @override
  String get accountYouthEligible => 'Eligible for youth / student fare';

  @override
  String get accountSeniorEligible => 'Eligible for senior fare';

  @override
  String accountResetSent(String email) {
    return 'Mock password reset link prepared for $email.';
  }

  @override
  String get accountSaveProfile => 'Save profile';

  @override
  String get onboardingConsentLocation =>
      'Allow location while app is open to find nearby stops (never leaves device in mock mode)';

  @override
  String get onboardingConsentNotifications =>
      'Allow arrival, delay, and ticket expiry alerts';

  @override
  String get onboardingConsentAnalytics =>
      'Optional anonymous usage statistics (off by default)';

  @override
  String get onboardingAccountOptionalNote =>
      'An account is optional now and only needed later when buying tickets.';

  @override
  String get noticesTriggerAlternative => 'Find alternative route';

  @override
  String get noticesSmartBusArriving => 'Bus arriving soon alert';

  @override
  String get noticesSmartLineDelayed => 'Favourite line delayed alert';

  @override
  String get noticesSmartTicketExpiring => 'Ticket expiring soon alert';

  @override
  String get noticesPreviewVibration => 'Test visual & vibration alert';

  @override
  String get settingsClearLocalData => 'Clear local cached data';

  @override
  String get settingsClearLocalDataDone => 'Local cache cleared.';

  @override
  String get settingsAboutTitle => 'About M Mobilnost 2.0';

  @override
  String get settingsAboutBody =>
      'Accessible unified Marprom transit and ticketing prototype for Maribor. Simulated live data is clearly marked.';

  @override
  String get settingsUsabilityStart => 'Start timed scenario';

  @override
  String get settingsUsabilityFinish => 'Complete scenario';

  @override
  String get settingsUsabilityRecordError => 'Log error (+1)';

  @override
  String get settingsUsabilityExportCsv => 'Export CSV';

  @override
  String get settingsUsabilityExportJson => 'Export JSON';

  @override
  String settingsUsabilitySummary(int seconds, int taps, int errors) {
    return 'Time: $seconds s • Taps: $taps • Errors: $errors';
  }
}
