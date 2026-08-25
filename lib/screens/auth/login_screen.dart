import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_providers.dart';
import '../../services/social_auth_service.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/buttons/social_button.dart';
import '../../widgets/common/auth_container.dart';
import '../../widgets/common/app_popup.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/inline_error_banner.dart';
import '../../widgets/common/logo_widget.dart';
import '../../widgets/common/screen_backdrop.dart';
import '../../widgets/inputs/custom_text_field.dart';
import 'role_selection_screen.dart';

/// Floating login layout (no big white card) — logo + heading up top,
/// fields and gradient Sign In button floating over the blurred backdrop,
/// then a divider with social buttons and a Create Account link.
///
/// On success, routing priority is: unverified email always wins first
/// (→ [AppRoutes.verificationPending]), then an incomplete profile
/// (→ [AppRoutes.completeProfile]), and only once both of those are
/// satisfied does role decide the final home
/// ([AppRoutes.adminHome] for photographers, [AppRoutes.home] for
/// clients). See [_navigateAfterAuth] for the exact order — reused
/// as-is by `splash_screen.dart`'s session bootstrap.
class LoginScreen extends ConsumerStatefulWidget {
  final UserRole? role;
  const LoginScreen({super.key, this.role});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  /// Which social button (if any) is mid-flow — 'google' | 'apple' |
  /// null. A String (not a shared bool) so tapping Google doesn't also
  /// spin the Apple button, and vice versa.
  String? _socialLoadingProvider;

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _shakeAnimation = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

  Future<void> _handleSignIn() async {
    if (_socialLoadingProvider != null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
            role: widget.role == null
                ? null
                : (widget.role == UserRole.photographer ? AppUserRole.photographer : AppUserRole.client),
            rememberMe: _rememberMe,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e.statusCode == 401 || e.statusCode == 400) {
        // 401 = wrong credentials; 400 = this email is registered under
        // both a Client and a Studio account and widget.role wasn't
        // enough to disambiguate (e.g. Login reached without a
        // preselected role) — same inline-banner treatment either way.
        setState(() => _errorMessage = e.message);
        _shakeController.forward(from: 0);
        return;
      }
      await AppPopup.show(context, title: 'Something Went Wrong', message: e.message, isError: true);
      return;
    } catch (_) {
      // Anything that isn't an ApiException (e.g. a response-parsing
      // error) must still clear _isLoading — otherwise the Sign In
      // button spins forever with no error shown at all.
      if (!mounted) return;
      setState(() => _isLoading = false);
      await AppPopup.show(
        context,
        title: 'Something Went Wrong',
        message: 'Something went wrong. Please try again.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    _navigateAfterAuth(user);
  }

  /// Google/Apple button handler, shared by both. If [widget.role]
  /// wasn't already picked (only possible on this screen — reached
  /// without a role via Forgot Password's success flows), Role
  /// Selection runs first in "pick and return" mode; social sign-in
  /// always needs a role up front since there's no password afterward
  /// to disambiguate a same-email/both-roles account.
  Future<void> _handleSocialSignIn(String provider) async {
    if (_isLoading) return;
    UserRole? role = widget.role;
    if (role == null) {
      role = await Navigator.of(context).push<UserRole>(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen(selectOnly: true)),
      );
      if (role == null) return; // user backed out of Role Selection
    }
    if (!mounted) return;

    setState(() {
      _socialLoadingProvider = provider;
      _errorMessage = null;
    });

    try {
      final service = ref.read(socialAuthServiceProvider);
      final result = provider == 'google' ? await service.signInWithGoogle() : await service.signInWithApple();

      await ref.read(authProvider.notifier).socialLogin(
            provider: result.provider,
            idToken: result.idToken,
            role: role == UserRole.photographer ? AppUserRole.photographer : AppUserRole.client,
            fullName: result.fullName,
          );
    } on SocialAuthCancelled {
      if (!mounted) return;
      setState(() => _socialLoadingProvider = null);
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _socialLoadingProvider = null);
      await AppPopup.show(context, title: 'Sign-in Failed', message: e.message, isError: true);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _socialLoadingProvider = null);
      await AppPopup.show(
        context,
        title: 'Sign-in Failed',
        message: 'Something went wrong. Please try again.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _socialLoadingProvider = null);

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    _navigateAfterAuth(user);
  }

  /// Sends the user to the right place after a successful login, in
  /// priority order: unverified email first, then an incomplete
  /// profile ([AppUser.hasCompletedProfile]), and only then role-based
  /// home. Each branch passes the argument shape that route actually
  /// expects per `app_routes.dart` (`verificationPending` wants a Map,
  /// `completeProfile` wants a raw `UserRole?`). `splash_screen.dart`
  /// (Task 10) reuses this same priority order and the same getter.
  ///
  /// The verification/profile branches use a plain `pushNamed` (not
  /// `pushNamedAndRemoveUntil`) so Login stays on the stack beneath the
  /// gate screen — otherwise the gate screen's back button has nothing
  /// to pop to and silently does nothing. Only the final, fully-set-up
  /// destination clears the whole stack, since you shouldn't be able to
  /// back out of Home into Login.
  void _navigateAfterAuth(AppUser user) {
    final legacyRole = user.role == AppUserRole.photographer ? UserRole.photographer : UserRole.client;
    final navigator = Navigator.of(context);

    if (!user.isEmailVerified) {
      navigator.pushNamed(
        AppRoutes.verificationPending,
        arguments: {'email': user.email, 'role': legacyRole},
      );
      return;
    }

    if (!user.hasCompletedProfile) {
      navigator.pushNamed(
        AppRoutes.completeProfile,
        arguments: legacyRole,
      );
      return;
    }

    final destination = legacyRole == UserRole.photographer ? AppRoutes.adminHome : AppRoutes.home;
    navigator.pushNamedAndRemoveUntil(destination, (route) => false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection);
      }
    }

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(onBack: handleBack),
        body: ScreenBackdrop(
        child: SafeArea(
          top: true,
          child: AuthContainer(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(child: LogoWidget(size: 56)),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Welcome Back', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Continue your creative journey.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.subtitle),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_errorMessage != null) ...[
                    InlineErrorBanner(message: _errorMessage!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Email',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CustomTextField(
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          controller: _passwordController,
                          validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Remember me', style: TextStyle(fontSize: 13, color: AppColors.subtitle, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
                        child: const Text('Forgot Password?',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GradientButton(
                    label: 'Sign In',
                    isLoading: _isLoading,
                    onPressed: _socialLoadingProvider != null ? null : _handleSignIn,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or continue with', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: SocialButton(
                          icon: Icons.g_mobiledata_rounded,
                          label: 'Google',
                          isLoading: _socialLoadingProvider == 'google',
                          onTap: () => _handleSocialSignIn('google'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SocialButton(
                          icon: Icons.apple_rounded,
                          label: 'Apple',
                          isLoading: _socialLoadingProvider == 'apple',
                          onTap: () => _handleSocialSignIn('apple'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // TEMP DEBUG — remove once the client/studio
                        // role mismatch is confirmed fixed.
                        debugPrint('[ROLE_DEBUG] LoginScreen Create Account tapped, widget.role=${widget.role}');
                        Navigator.of(context).pushNamed(AppRoutes.register, arguments: widget.role);
                      },
                      child: RichText(
                        text: const TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: AppColors.subtitle, fontSize: 13.5, fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(text: 'Create Account', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
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