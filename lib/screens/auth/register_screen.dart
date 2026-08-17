import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/auth_container.dart';
import '../../widgets/common/anchored_dropdown_field.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/screen_backdrop.dart';
import '../../widgets/inputs/custom_text_field.dart';

/// Three-step registration: (1) identity, (2) password, (3) role-specific
/// details + terms. Photographers see Studio fields on step 3; Clients
/// skip straight to the terms checkbox. Progress shown via a segmented
/// gradient bar at the top.
class RegisterScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const RegisterScreen({super.key, required this.role});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _isSubmitting = false;

  // Step 1
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  // Step 2
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  // Step 3 (photographer only)
  final _studioNameController = TextEditingController();
  final _studioAddressController = TextEditingController();
  String _businessType = 'Freelance Photographer';
  bool _agreedToTerms = false;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  bool get _isPhotographer => widget.role == UserRole.photographer;
  int get _totalSteps => 3;

  Future<void> _next() async {
    if (_step == 0 && !_step1Key.currentState!.validate()) return;
    if (_step == 1 && !_step2Key.currentState!.validate()) return;

    if (_step == _totalSteps - 1) {
      if (!_step3Key.currentState!.validate()) return;
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the Terms & Conditions')),
        );
        return;
      }
      await _submit();
      return;
    }

    setState(() => _step++);
    _pageController.nextPage(
        duration: AppDurations.medium, curve: Curves.easeOutCubic);
  }

  /// Actually creates the account via POST /auth/register. Previously
  /// this screen only built a local SignupData object and navigated
  /// on without ever calling the backend, so no account — client or
  /// photographer — was created server-side and nothing showed up
  /// after "signing up" this way (Google/Apple sign-up worked because
  /// that path calls the API directly via AuthNotifier.socialLogin).
  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authProvider.notifier).register(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: widget.role == UserRole.photographer
                ? AppUserRole.photographer
                : AppUserRole.client,
            agreedToTerms: _agreedToTerms,
            studioName: _isPhotographer ? _studioNameController.text.trim() : null,
            studioAddress: _isPhotographer ? _studioAddressController.text.trim() : null,
            businessType: _isPhotographer ? _businessType : null,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // 400 here is most often the backend's "A Client/Studio account
      // already exists for this email" (uq_users_email_role) message —
      // show it as-is rather than a generic failure.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // register() already returns an access token and logs the user
    // in (unverified), so go straight into the verification-pending
    // step with the real account's email/role. (Uses
    // VerificationPendingScreen, not the dummy EmailVerificationScreen,
    // since only the former's Resend Email / Continue buttons actually
    // call the backend.)
    Navigator.of(context).pushNamed(AppRoutes.verificationPending,
        arguments: {'email': _emailController.text.trim(), 'role': widget.role});
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
        duration: AppDurations.medium, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _nameController,
      _emailController,
      _passwordController,
      _confirmController,
      _studioNameController,
      _studioAddressController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Create Account',
        onBack: _back,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.md),
            child: _StepProgress(step: _step, total: _totalSteps),
          ),
        ),
      ),
      body: ScreenBackdrop(
        child: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 86),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: GradientButton(
                      label:
                          _step == _totalSteps - 1 ? 'Create Account' : 'Next',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      )
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: _StepScaffold(
        title: 'Let\'s get to know you',
        subtitle: 'Basic details to set up your account.',
        children: [
          CustomTextField(
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            controller: _nameController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Full name is required'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: _StepScaffold(
        title: 'Secure your account',
        subtitle: 'Choose a strong password you\'ll remember.',
        children: [
          CustomTextField(
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            controller: _passwordController,
            // Backend (UserRegister schema) requires min 8 chars AND
            // at least one digit — this only checked 6 chars, so a
            // password that passed here could still get rejected by
            // the server after the user finished all 3 steps.
            validator: (v) {
              if (v == null || v.length < 8) return 'Minimum 8 characters';
              if (!v.contains(RegExp(r'[0-9]'))) {
                return 'Must include at least one number';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            label: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            controller: _confirmController,
            validator: (v) =>
                v != _passwordController.text ? 'Passwords do not match' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _step3Key,
      child: _StepScaffold(
        title: _isPhotographer ? 'Tell us about your studio' : 'Almost there',
        subtitle: _isPhotographer
            ? 'This helps clients discover you.'
            : 'Review our terms to finish up.',
        children: [
          if (_isPhotographer) ...[
            CustomTextField(
                label: 'Studio Name',
                icon: Icons.storefront_rounded,
                controller: _studioNameController,
                // Backend requires studio_name for photographer
                // accounts and rejects registration without it — this
                // field previously had no validator at all (and wasn't
                // even inside a Form), so a photographer could submit
                // with it blank and only find out after the round trip
                // to the server.
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Studio name is required'
                    : null),
            const SizedBox(height: AppSpacing.md),
            CustomTextField(
                label: 'Studio Address',
                icon: Icons.location_on_outlined,
                controller: _studioAddressController),
            const SizedBox(height: AppSpacing.md),
            AnchoredDropdownField<String>(
              value: _businessType,
              decoration: const InputDecoration(
                labelText: 'Business Type',
                prefixIcon: Icon(Icons.business_center_outlined,
                    color: AppColors.primary, size: 20),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'Freelance Photographer',
                    child: Text('Freelance Photographer')),
                DropdownMenuItem(value: 'Studio', child: Text('Studio')),
                DropdownMenuItem(
                    value: 'Event Company', child: Text('Event Company')),
              ],
              onChanged: (v) =>
                  setState(() => _businessType = v ?? _businessType),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          InkWell(
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 22,
                  width: 22,
                  child: Checkbox(
                    value: _agreedToTerms,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'I agree to the Terms & Conditions and Privacy Policy',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.subtitle,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _StepScaffold(
      {required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return AuthContainer(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      maxWidth: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.subtitle)),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int step;
  final int total;
  const _StepProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }
}