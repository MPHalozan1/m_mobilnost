// Shared UI helpers for payment methods, demo notices, date formatting, and auth prompts.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/accessibility/a11y_settings.dart';
import '../../../../core/accessibility/semantics_helpers.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/big_button.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../../data/models/payment_method.dart';
import '../../../../data/repositories/repository_providers.dart';
import '../../../../l10n/app_localizations.dart';

/// Navigates to [routeLocation] via GoRouter when mounted, or pushes [fallbackBuilder].
void navigateWithFallback(
  BuildContext context,
  String routeLocation, {
  WidgetBuilder? fallbackBuilder,
  bool replace = false,
}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (replace) {
      router.go(routeLocation);
    } else {
      router.push(routeLocation);
    }
    return;
  }
  if (fallbackBuilder != null) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: fallbackBuilder),
    );
  }
}

/// Formats a calendar [date] without time-of-day using the active [localeCode].
String formatCalendarDate(DateTime date, {String localeCode = 'sl'}) {
  final safeLocale = localeCode == 'sr_Latn'
      ? 'sr_Latn'
      : (const ['sl', 'en', 'de', 'sr'].contains(localeCode)
          ? localeCode
          : 'sl');
  try {
    return DateFormat.yMd(safeLocale).format(date);
  } catch (_) {
    return DateFormat('dd.MM.yyyy').format(date);
  }
}

/// Returns a distinct icon representing [type].
IconData iconForPaymentType(PaymentMethodType type) {
  switch (type) {
    case PaymentMethodType.card:
      return Icons.credit_card_rounded;
    case PaymentMethodType.googlePay:
      return Icons.account_balance_wallet_outlined;
    case PaymentMethodType.applePay:
      return Icons.phone_iphone_rounded;
    case PaymentMethodType.bankTransfer:
      return Icons.account_balance_rounded;
    case PaymentMethodType.mobilePay:
      return Icons.smartphone_rounded;
  }
}

/// Returns the localized channel name for [type].
String localizedPaymentTypeLabel(
  AppLocalizations l10n,
  PaymentMethodType type,
) {
  switch (type) {
    case PaymentMethodType.card:
      return l10n.paymentsCard;
    case PaymentMethodType.googlePay:
      return l10n.paymentsGooglePay;
    case PaymentMethodType.applePay:
      return l10n.paymentsApplePay;
    case PaymentMethodType.bankTransfer:
      return l10n.paymentsBankTransfer;
    case PaymentMethodType.mobilePay:
      return l10n.paymentsMobilePay;
  }
}

/// Prominent banner informing riders that all payments are simulated demos.
class DemoPaymentBanner extends StatelessWidget {
  /// Creates a [DemoPaymentBanner] with optional secondary [subtitle].
  const DemoPaymentBanner({
    super.key,
    this.subtitle,
  });

  /// Optional extra localized explanation text.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColors =
        Theme.of(context).extension<MarpromStatusColors>() ??
            MarpromStatusColors.light;

    return Semantics(
      container: true,
      label: l10n.ticketsDemoPaymentNotice,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: statusColors.infoBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: statusColors.infoFg.withValues(
              alpha: statusColors.highContrastBorders ? 1.0 : 0.35,
            ),
            width: statusColors.highContrastBorders ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, color: statusColors.infoFg, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ticketsDemoPaymentNotice,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: statusColors.infoFg,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: statusColors.infoFg,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calm prompt card inviting guest riders to sign in via Google or email before buying.
class GuestAuthPromptCard extends ConsumerWidget {
  /// Creates a [GuestAuthPromptCard] with [onSignInPressed] and optional [onSecondaryPressed].
  const GuestAuthPromptCard({
    super.key,
    required this.onSignInPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  /// Callback triggered when the rider taps the Sign In button.
  final VoidCallback onSignInPressed;

  /// Optional secondary dismiss/cancel button label.
  final String? secondaryLabel;

  /// Optional secondary button callback.
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = ref.watch(a11ySettingsProvider).localeCode;

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconWell(icon: Icons.person_outline_rounded, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.ticketsAuthRequiredTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.ticketsAuthRequiredBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            GoogleSignInButton(
              label: locale == 'sl'
                  ? 'Prijava z Google računom'
                  : 'Continue with Google',
              onPressed: () {
                ref.read(authRepositoryProvider).signInWithGoogle(
                      preferredLocaleCode: locale,
                    );
              },
            ),
            const SizedBox(height: 10),
            BigButton(
              icon: Icons.login_rounded,
              label: l10n.accountSignIn,
              variant: BigButtonVariant.secondary,
              expanded: true,
              onPressed: onSignInPressed,
            ),
            if (secondaryLabel != null && onSecondaryPressed != null) ...[
              const SizedBox(height: 10),
              BigButton(
                icon: Icons.close_rounded,
                label: secondaryLabel!,
                variant: BigButtonVariant.outlined,
                expanded: true,
                onPressed: onSecondaryPressed,
              ),
            ],
          ],
        ),
    );
  }
}
