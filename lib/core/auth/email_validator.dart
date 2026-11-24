//**********************************************
// Strict email domain & password validation   *
//**********************************************

import 'package:flutter/foundation.dart';

//**********************************************
// Email validation result & allowlists        *
//**********************************************

/// Result returned by [EmailValidator.validate].
@immutable
class EmailValidationResult {
  /// Creates an [EmailValidationResult].
  const EmailValidationResult({
    required this.isValid,
    required this.normalizedEmail,
    this.errorCode,
    this.errorMessageSl,
    this.errorMessageEn,
    this.suggestedEmail,
  });

  /// True when the email syntax and domain are valid and trusted.
  final bool isValid;

  /// Lowercased, trimmed email address.
  final String normalizedEmail;

  /// Machine-readable reason code when invalid.
  final String? errorCode;

  /// User-facing Slovenian error message when invalid.
  final String? errorMessageSl;

  /// User-facing English error message when invalid.
  final String? errorMessageEn;

  /// Optional typo-correction suggestion (e.g. `user@gmail.com`).
  final String? suggestedEmail;

  /// Returns the localized error message for [localeCode].
  String? localizedError(String localeCode) =>
      localeCode == 'sl' ? errorMessageSl : errorMessageEn;
}

/// Password strength levels (`0..4`) for live registration feedback.
@immutable
class PasswordStrengthResult {
  /// Creates a [PasswordStrengthResult].
  const PasswordStrengthResult({
    required this.score,
    required this.labelSl,
    required this.labelEn,
  });

  /// Strength score from `0` (empty/weak) to `4` (very strong).
  final int score;

  /// Slovenian label for the strength bar.
  final String labelSl;

  /// English label for the strength bar.
  final String labelEn;
}

/// Enforces strict email validation blocking fake, gibberish, disposable,
/// and phishing lookalike domains while permitting Gmail, Microsoft, Apple,
/// Marprom, and verified school/university domains.
abstract final class EmailValidator {
  /// Trusted exact email domains permitted for registration and sign-in.
  static const Set<String> kAllowedEmailDomains = <String>{
    // Google / Gmail
    'gmail.com',
    'googlemail.com',
    // Microsoft Accounts
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'outlook.de',
    'outlook.at',
    'hotmail.co.uk',
    'hotmail.de',
    'live.co.uk',
    // Apple
    'icloud.com',
    'me.com',
    'mac.com',
    // Marprom
    'marprom.si',
    // Slovenian Schools & Universities
    'student.um.si',
    'um.si',
    'student.uni-lj.si',
    'uni-lj.si',
    'upr.si',
    'famnit.upr.si',
    'ung.si',
    'arnes.si',
    'guest.arnes.si',
    'sc-mb.si',
    'sers.si',
    'ii-gimnazija.org',
    'prva-gimnazija.org',
    'tretja-gimnazija.si',
    'serg.si',
    'tsck.si',
  };

  /// Verified academic domain suffixes for schools and universities.
  static const List<String> kAllowedAcademicSuffixes = <String>[
    '.edu',
    '.edu.si',
    '.ac.at',
    '.ac.uk',
    '.um.si',
    '.uni-lj.si',
    '.upr.si',
    '.ung.si',
    '.arnes.si',
  ];

  /// Known disposable / temporary mail domains blocked unconditionally.
  static const Set<String> kDisposableEmailDomains = <String>{
    'mailinator.com',
    'tempmail.com',
    'temp-mail.org',
    '10minutemail.com',
    'guerrillamail.com',
    'yopmail.com',
    'trashmail.com',
    'sharklasers.com',
    'maildrop.cc',
    'dispostable.com',
    'getnada.com',
    'mohmal.com',
    'fakeinbox.com',
    'throwawaymail.com',
    'tempail.com',
    'emailondeck.com',
    'mintemail.com',
    'burnermail.io',
    'mailnesia.com',
    'spamgourmet.com',
  };

  /// Common typos and phishing lookalike domains mapped to the real domain.
  static const Map<String, String> kTypoAndPhishingLookalikes = <String, String>{
    'gmial.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'gmail.si': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'g00gle.com': 'gmail.com',
    'g00glemail.com': 'googlemail.com',
    'outlok.com': 'outlook.com',
    'outloo.com': 'outlook.com',
    '0utlook.com': 'outlook.com',
    'out1ook.com': 'outlook.com',
    'outlook.cm': 'outlook.com',
    'hotmal.com': 'hotmail.com',
    'hotmial.com': 'hotmail.com',
    'hotmai1.com': 'hotmail.com',
    'micr0soft.com': 'outlook.com',
    'icl0ud.com': 'icloud.com',
    'icoud.com': 'icloud.com',
    'studnet.um.si': 'student.um.si',
  };

  static final RegExp _localPartRegex = RegExp(
    r"^[a-z0-9](?:[a-z0-9._+-]{0,62}[a-z0-9])?$",
  );
  static final RegExp _domainRegex = RegExp(
    r"^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,12}$",
  );

  /// Validates [rawEmail] against syntax, phishing/typo lookalikes, disposable
  /// blocklists, and trusted Gmail/Microsoft/Apple/Marprom/School allowlists.
  static EmailValidationResult validate(String rawEmail) {
    final normalized = rawEmail.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const EmailValidationResult(
        isValid: false,
        normalizedEmail: '',
        errorCode: 'empty',
        errorMessageSl: 'Vnesite svoj e-poštni naslov.',
        errorMessageEn: 'Please enter your email address.',
      );
    }

    final parts = normalized.split('@');
    if (parts.length != 2) {
      return EmailValidationResult(
        isValid: false,
        normalizedEmail: normalized,
        errorCode: 'invalid_syntax',
        errorMessageSl: 'E-poštni naslov mora vsebovati veljaven znak @ in domeno.',
        errorMessageEn: 'Email must contain a valid @ symbol and domain.',
      );
    }

    final local = parts[0];
    final domain = parts[1];

    if (!_localPartRegex.hasMatch(local) || local.contains('..')) {
      return EmailValidationResult(
        isValid: false,
        normalizedEmail: normalized,
        errorCode: 'invalid_local',
        errorMessageSl: 'Uporabniško ime pred znakom @ ni veljavno.',
        errorMessageEn: 'The username before @ is not valid.',
      );
    }

    if (domain.contains('xn--') || !_domainRegex.hasMatch(domain)) {
      return EmailValidationResult(
        isValid: false,
        normalizedEmail: normalized,
        errorCode: 'invalid_domain_syntax',
        errorMessageSl: 'Domena e-pošte ni veljavna ali vsebuje sumljive znake.',
        errorMessageEn: 'Email domain format is invalid or suspicious.',
      );
    }

    // Reject typosquatting & phishing lookalikes with helpful correction.
    final typoSuggestion = kTypoAndPhishingLookalikes[domain];
    if (typoSuggestion != null) {
      return EmailValidationResult(
        isValid: false,
        normalizedEmail: normalized,
        errorCode: 'typo_or_phishing',
        suggestedEmail: '$local@$typoSuggestion',
        errorMessageSl:
            'Domena "@$domain" ni dovoljena (zatipk ali lažna domena). Ali ste mislili $local@$typoSuggestion?',
        errorMessageEn:
            'Domain "@$domain" is blocked (typo or lookalike). Did you mean $local@$typoSuggestion?',
      );
    }

    // Reject disposable temporary inboxes.
    if (kDisposableEmailDomains.contains(domain)) {
      return EmailValidationResult(
        isValid: false,
        normalizedEmail: normalized,
        errorCode: 'disposable_domain',
        errorMessageSl:
            'Začasni ali enkratni e-poštni naslovi (@$domain) niso dovoljeni.',
        errorMessageEn:
            'Disposable or temporary email addresses (@$domain) are not allowed.',
      );
    }

    // Check exact allowlist or verified school/university domain suffix.
    final isExactAllowed = kAllowedEmailDomains.contains(domain);
    final isAcademicSuffix = kAllowedAcademicSuffixes.any(
      (suffix) => domain.endsWith(suffix) && domain.length > suffix.length,
    );

    if (!isExactAllowed && !isAcademicSuffix) {
      return EmailValidationResult(
        isValid: false,
        normalizedEmail: normalized,
        errorCode: 'untrusted_domain',
        errorMessageSl:
            'Domena "@$domain" ni podprta. Uporabite Gmail, Microsoft (Outlook/Hotmail), iCloud ali šolski/univerzitetni e-naslov (npr. @student.um.si).',
        errorMessageEn:
            'Domain "@$domain" is not allowed. Please use Gmail, Microsoft (Outlook/Hotmail), iCloud, or a verified school/university email.',
      );
    }

    return EmailValidationResult(
      isValid: true,
      normalizedEmail: normalized,
    );
  }

  /// Evaluates [password] strength on a `0..4` scale for UI feedback.
  static PasswordStrengthResult evaluatePasswordStrength(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthResult(
        score: 0,
        labelSl: 'Vnesite geslo (min. 8 znakov)',
        labelEn: 'Enter password (min. 8 chars)',
      );
    }
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) || password.length >= 12) {
      score++;
    }
    score = score.clamp(1, 4);

    return switch (score) {
      1 => const PasswordStrengthResult(
          score: 1,
          labelSl: 'Šibko geslo',
          labelEn: 'Weak password',
        ),
      2 => const PasswordStrengthResult(
          score: 2,
          labelSl: 'Srednje geslo',
          labelEn: 'Fair password',
        ),
      3 => const PasswordStrengthResult(
          score: 3,
          labelSl: 'Dobro geslo',
          labelEn: 'Good password',
        ),
      _ => const PasswordStrengthResult(
          score: 4,
          labelSl: 'Zelo močno geslo',
          labelEn: 'Strong password',
        ),
    };
  }
}
