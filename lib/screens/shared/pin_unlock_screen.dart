import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/screen_backdrop.dart';

/// Shown once per cold start — before the app's normal entry route —
/// whenever `settings.securityPinEnabled && settings.requirePinOnLaunch`
/// are both true (see splash_screen.dart, which is the only place this
/// screen is ever pushed from). Not shown again mid-session.
///
/// Styling mirrors [_SetupSecurityPinDialog] in admin_settings_screen.dart
/// so the PIN entry UI feels consistent between "set a PIN" and "enter
/// your PIN".
class PinUnlockScreen extends StatefulWidget {
  /// The correct PIN to match against, loaded by the caller from
  /// [SettingsModel.securityPin] before this screen is pushed.
  final String correctPin;

  /// Route to replace this screen with once the PIN matches — wherever
  /// splash would have gone had the PIN gate not been enabled. Navigated
  /// to using this screen's own context, since the splash screen that
  /// pushed this route is already gone by the time the PIN is entered.
  final String destinationRoute;

  /// Whatever [destinationRoute] itself needs as `settings.arguments`
  /// once pushed (e.g. a `UserRole` for completeProfile) — forwarded
  /// as-is from [PinUnlockArgs.destinationArguments]. `null` for routes
  /// that don't need any (role-selection, onboarding, home, ...).
  final Object? destinationArguments;

  const PinUnlockScreen({
    super.key,
    required this.correctPin,
    required this.destinationRoute,
    this.destinationArguments,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinCtrl = TextEditingController();

  static const int _maxAttempts = 3;
  int _attemptsLeft = _maxAttempts;
  String? _errorText;
  bool _lockedOutForNow = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_lockedOutForNow) return;
    if (!_formKey.currentState!.validate()) return;

    if (_pinCtrl.text.trim() == widget.correctPin) {
      Navigator.of(context).pushReplacementNamed(
        widget.destinationRoute,
        arguments: widget.destinationArguments,
      );
      return;
    }

    setState(() {
      _attemptsLeft -= 1;
      _pinCtrl.clear();
      if (_attemptsLeft <= 0) {
        // No backend-enforced lockout yet — just stop accepting further
        // attempts on this screen instance and tell the user why.
        _lockedOutForNow = true;
        _errorText = 'Too many incorrect attempts. Please try again.';
      } else {
        _errorText =
            'Incorrect PIN. $_attemptsLeft attempt${_attemptsLeft == 1 ? '' : 's'} left.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textOnDark : AppColors.text;
    final subtitleColor = isDark ? AppColors.subtitleOnDark : AppColors.subtitle;

    return Scaffold(
      body: ScreenBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Enter App Lock PIN',
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your 4-digit PIN to continue',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: subtitleColor),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _pinCtrl,
                        enabled: !_lockedOutForNow,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24,
                            letterSpacing: 12,
                            color: textColor),
                        decoration: InputDecoration(
                          hintText: '••••',
                          hintStyle: TextStyle(color: subtitleColor),
                          counterText: '',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length != 4) {
                            return 'PIN must be 4 digits';
                          }
                          if (int.tryParse(v) == null) {
                            return 'PIN must contain numbers only';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    GradientButton(
                      label: 'Unlock',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _lockedOutForNow ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}