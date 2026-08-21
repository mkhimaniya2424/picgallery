import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/admin/section_header.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/common/app_popup.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/screen_backdrop.dart';
import '../../widgets/inputs/cascading_location_picker.dart';
import '../../widgets/inputs/custom_text_field.dart';
import '../../widgets/inputs/tag_input_field.dart';
import '../auth/complete_profile_screen.dart' show kStudioSpecializations;

/// Fixed option set for the Studio Details "Studio Type" field — no
/// backend-driven list exists for this yet, so (same convention as
/// `kStudioSpecializations`) a small hardcoded set is used.
const List<String> kStudioTypes = ['Solo Photographer', 'Small Studio', 'Large Studio', 'Agency'];

/// Fixed weekday set for "Availability Days" — shown as selectable chips.
const List<String> kWeekDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Fixed option set for the Client Preferences "Gender" field.
const List<String> kGenderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

/// Edit Profile screen (Task 7): Personal Details (Name, read-only
/// Country/State/City, plus (Task 8) role-specific sections —
/// Studio Details + Social Media Links (Task 9) for photographer
/// accounts, Preferences for client accounts — and a shared Bio field.
///
/// Loads the current user the same way `CompleteProfileScreen` does —
/// prefer whatever's already cached in [authProvider], but force a
/// fresh fetch via `refreshMe()` (`GET /auth/me`; the backend has no
/// separate `GET /users/me`, so this is the endpoint that actually
/// backs "load current user") if nothing's cached yet, e.g. after a
/// cold app restart. Saving calls `PATCH /users/me` through
/// [UserRepository] and pushes the result back into [authProvider] via
/// `AuthNotifier.setUser()`, so every other screen watching the
/// current user (e.g. the Profile tab's greeting) updates immediately.
///
/// Standalone screen only, per Task 7 — nothing navigates here yet
/// (`ProfileScreen`'s "Edit Profile" row is still a no-op).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _addressController = TextEditingController();

  String? _country;
  String? _state;
  String? _city;

  // Studio-only fields (Task 8) — photographer role only.
  final _studioAddressController = TextEditingController();
  String? _studioType;
  final _yearEstablishedController = TextEditingController();
  final _teamSizeController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  List<String> _serviceAreas = [];
  List<String> _languages = [];
  final _equipmentHighlightsController = TextEditingController();
  final _pricingMinController = TextEditingController();
  final _pricingMaxController = TextEditingController();
  final _packageDetailsController = TextEditingController();
  final Set<String> _availabilityDays = {};

  // Social Media Links (Task 9) — photographer role only.
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _pinterestController = TextEditingController();

  // Client-only fields (Task 8) — client role only.
  String? _gender;
  DateTime? _dateOfBirth;
  final Set<String> _preferredPhotoTypes = {};
  final _preferredCityController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();

  bool _seeded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  /// Prefers whatever's already cached in [authProvider]; if nothing's
  /// loaded yet, forces a fresh `GET /auth/me` via `refreshMe()` first —
  /// same fallback `CompleteProfileScreen` uses, so this screen never
  /// shows blank fields just because of app-restart timing.
  Future<void> _loadCurrentUser() async {
    final cached = ref.read(authProvider).valueOrNull;
    if (cached == null) {
      try {
        await ref.read(authProvider.notifier).refreshMe();
      } on ApiException {
        // Leave the error state to `build()`'s authAsync.hasError branch,
        // which offers a Retry that calls this method again.
      }
    }
  }

  void _seedControllers(AppUser user) {
    _fullNameController.text = user.fullName;
    _bioController.text = user.bio ?? '';
    _addressController.text = user.address ?? '';
    _country = user.country;
    _state = user.state;
    _city = user.city;

    if (user.role == AppUserRole.photographer) {
      _studioAddressController.text = user.studioAddress ?? '';
      _studioType = user.studioType;
      _yearEstablishedController.text = user.yearEstablished?.toString() ?? '';
      _teamSizeController.text = user.teamSize?.toString() ?? '';
      _experienceYearsController.text = user.experienceYears?.toString() ?? '';
      _serviceAreas = List.of(user.serviceAreas ?? const []);
      _languages = List.of(user.languages ?? const []);
      _equipmentHighlightsController.text = user.equipmentHighlights ?? '';
      _pricingMinController.text = user.pricingMin?.toString() ?? '';
      _pricingMaxController.text = user.pricingMax?.toString() ?? '';
      _packageDetailsController.text = user.packageDetails ?? '';
      _availabilityDays
        ..clear()
        ..addAll(user.availabilityDays ?? const []);
      _instagramController.text = user.instagramUrl ?? '';
      _facebookController.text = user.facebookUrl ?? '';
      _youtubeController.text = user.youtubeUrl ?? '';
      _pinterestController.text = user.pinterestUrl ?? '';
    } else {
      _gender = user.gender;
      _dateOfBirth = user.dateOfBirth;
      _preferredPhotoTypes
        ..clear()
        ..addAll(user.preferredPhotoTypes ?? const []);
      _preferredCityController.text = user.preferredCity ?? '';
      _budgetMinController.text = user.budgetMin?.toString() ?? '';
      _budgetMaxController.text = user.budgetMax?.toString() ?? '';
    }

    _seeded = true;
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  int? _parseInt(String text) => text.trim().isEmpty ? null : int.tryParse(text.trim());

  double? _parseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());

  /// Simple, permissive URL check — the field is optional (can be left
  /// blank per Task 9), so only non-blank input is validated. Accepts
  /// any `http(s)://` URL with a host; doesn't try to confirm the URL
  /// actually belongs to the named platform.
  String? _validateOptionalUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    final looksValid = uri != null &&
        (uri.isScheme('HTTP') || uri.isScheme('HTTPS')) &&
        uri.host.isNotEmpty &&
        uri.host.contains('.');
    return looksValid ? null : 'Enter a valid URL, e.g. https://instagram.com/yourstudio';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final user = ref.read(authProvider).valueOrNull;
    final isPhotographer = user?.role == AppUserRole.photographer;

    try {
      final updated = await ref.read(userRepositoryProvider).updateProfile(
            fullName: _fullNameController.text.trim(),
            country: _country,
            state: _state,
            city: _city,
            address: _emptyToNull(_addressController.text),
            bio: _emptyToNull(_bioController.text),
            studioAddress: isPhotographer ? _emptyToNull(_studioAddressController.text) : null,
            studioType: isPhotographer ? _studioType : null,
            yearEstablished: isPhotographer ? _parseInt(_yearEstablishedController.text) : null,
            teamSize: isPhotographer ? _parseInt(_teamSizeController.text) : null,
            experienceYears: isPhotographer ? _parseInt(_experienceYearsController.text) : null,
            serviceAreas: isPhotographer ? _serviceAreas : null,
            languages: isPhotographer ? _languages : null,
            equipmentHighlights: isPhotographer ? _emptyToNull(_equipmentHighlightsController.text) : null,
            pricingMin: isPhotographer ? _parseDouble(_pricingMinController.text) : null,
            pricingMax: isPhotographer ? _parseDouble(_pricingMaxController.text) : null,
            packageDetails: isPhotographer ? _emptyToNull(_packageDetailsController.text) : null,
            availabilityDays: isPhotographer ? _availabilityDays.toList() : null,
            instagramUrl: isPhotographer ? _instagramController.text.trim() : null,
            facebookUrl: isPhotographer ? _facebookController.text.trim() : null,
            youtubeUrl: isPhotographer ? _youtubeController.text.trim() : null,
            pinterestUrl: isPhotographer ? _pinterestController.text.trim() : null,
            gender: !isPhotographer ? _gender : null,
            dateOfBirth: !isPhotographer ? _dateOfBirth : null,
            preferredPhotoTypes: !isPhotographer ? _preferredPhotoTypes.toList() : null,
            preferredCity: !isPhotographer ? _emptyToNull(_preferredCityController.text) : null,
            budgetMin: !isPhotographer ? _parseDouble(_budgetMinController.text) : null,
            budgetMax: !isPhotographer ? _parseDouble(_budgetMaxController.text) : null,
          );
      ref.read(authProvider.notifier).setUser(updated);

      if (!mounted) return;
      AppToast.show(context, 'Profile updated');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await AppPopup.show(context, title: 'Something Went Wrong', message: e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _studioAddressController.dispose();
    _yearEstablishedController.dispose();
    _teamSizeController.dispose();
    _experienceYearsController.dispose();
    _equipmentHighlightsController.dispose();
    _pricingMinController.dispose();
    _pricingMaxController.dispose();
    _packageDetailsController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _youtubeController.dispose();
    _pinterestController.dispose();
    _preferredCityController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final user = authAsync.valueOrNull;

    Widget body;
    if (user == null) {
      if (authAsync.hasError) {
        body = _LoadErrorView(
          message: authAsync.error is ApiException
              ? (authAsync.error as ApiException).message
              : "Couldn't load your profile.",
          onRetry: _loadCurrentUser,
        );
      } else {
        body = const Center(child: LoadingWidget(message: 'Loading your profile...'));
      }
    } else {
      if (!_seeded) _seedControllers(user);
      body = _buildForm(context, user);
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Edit Profile'),
      body: ScreenBackdrop(child: SafeArea(top: false, child: body)),
    );
  }

  Widget _buildForm(BuildContext context, AppUser user) {
    final isPhotographer = user.role == AppUserRole.photographer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Personal Details', actionLabel: null),
                const SizedBox(height: AppSpacing.md),
                GlassCard(
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        controller: _fullNameController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ReadOnlyField(label: 'Email', value: user.email, icon: Icons.email_outlined),
                      const SizedBox(height: AppSpacing.md),
                      CustomTextField(
                        label: 'Bio',
                        icon: Icons.edit_note_rounded,
                        controller: _bioController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CustomTextField(
                        label: 'Address',
                        icon: Icons.home_outlined,
                        controller: _addressController,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(title: 'Location', actionLabel: null),
                const SizedBox(height: AppSpacing.md),
                GlassCard(
                  child: CascadingLocationPicker(
                    initialCountry: _country,
                    initialState: _state,
                    initialCity: _city,
                    onChanged: (country, state, city) {
                      setState(() {
                        _country = country;
                        _state = state;
                        _city = city;
                      });
                    },
                  ),
                ),
                if (isPhotographer) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(title: 'Studio Details', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  GlassCard(child: _buildStudioFields(context)),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(title: 'Social Media Links', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  GlassCard(child: _buildSocialFields(context)),
                ] else ...[
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(title: 'Preferences', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  GlassCard(child: _buildClientFields(context)),
                ],
                const SizedBox(height: AppSpacing.xl),
                GradientButton(label: 'Save Changes', isLoading: _isSaving, onPressed: _handleSave),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          label: 'Studio Address',
          icon: Icons.location_on_outlined,
          controller: _studioAddressController,
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Studio Type', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15)),
        const SizedBox(height: AppSpacing.sm),
        _SingleChoiceChips(
          options: kStudioTypes,
          selected: _studioType,
          onSelected: (v) => setState(() => _studioType = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Year Established',
                icon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
                controller: _yearEstablishedController,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                label: 'Team Size',
                icon: Icons.groups_rounded,
                keyboardType: TextInputType.number,
                controller: _teamSizeController,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          label: 'Experience (Years)',
          icon: Icons.workspace_premium_outlined,
          keyboardType: TextInputType.number,
          controller: _experienceYearsController,
        ),
        const SizedBox(height: AppSpacing.md),
        TagInputField(
          label: 'Service Areas',
          hint: 'e.g. Rajkot, add and press enter',
          icon: Icons.map_outlined,
          values: _serviceAreas,
          onChanged: (v) => setState(() => _serviceAreas = v),
        ),
        const SizedBox(height: AppSpacing.md),
        TagInputField(
          label: 'Languages',
          hint: 'e.g. English, add and press enter',
          icon: Icons.translate_rounded,
          values: _languages,
          onChanged: (v) => setState(() => _languages = v),
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          label: 'Equipment Highlights',
          icon: Icons.camera_alt_outlined,
          controller: _equipmentHighlightsController,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Pricing Min',
                icon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _pricingMinController,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                label: 'Pricing Max',
                icon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _pricingMaxController,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          label: 'Package Details',
          icon: Icons.card_giftcard_rounded,
          controller: _packageDetailsController,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Availability Days', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kWeekDays.map((day) {
            final selected = _availabilityDays.contains(day);
            return FilterChip(
              label: Text(day),
              selected: selected,
              onSelected: (v) => setState(() {
                v ? _availabilityDays.add(day) : _availabilityDays.remove(day);
              }),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              selectedColor: AppColors.primary,
              side: BorderSide(color: selected ? AppColors.primary : Theme.of(context).colorScheme.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSocialFields(BuildContext context) {
    return Column(
      children: [
        CustomTextField(
          label: 'Instagram',
          hint: 'https://instagram.com/yourstudio',
          icon: Icons.camera_alt_rounded,
          keyboardType: TextInputType.url,
          controller: _instagramController,
          validator: _validateOptionalUrl,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          label: 'Facebook',
          hint: 'https://facebook.com/yourstudio',
          icon: Icons.facebook,
          keyboardType: TextInputType.url,
          controller: _facebookController,
          validator: _validateOptionalUrl,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          label: 'YouTube',
          hint: 'https://youtube.com/@yourstudio',
          icon: Icons.play_circle_outline_rounded,
          keyboardType: TextInputType.url,
          controller: _youtubeController,
          validator: _validateOptionalUrl,
        ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          label: 'Pinterest',
          hint: 'https://pinterest.com/yourstudio',
          icon: Icons.push_pin_outlined,
          keyboardType: TextInputType.url,
          controller: _pinterestController,
          validator: _validateOptionalUrl,
        ),
      ],
    );
  }

  Widget _buildClientFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15)),
        const SizedBox(height: AppSpacing.sm),
        _SingleChoiceChips(
          options: kGenderOptions,
          selected: _gender,
          onSelected: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        _DateField(
          label: 'Date of Birth',
          icon: Icons.cake_outlined,
          value: _dateOfBirth,
          onTap: _pickDateOfBirth,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Preferred Photo Types', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kStudioSpecializations.map((type) {
            final selected = _preferredPhotoTypes.contains(type);
            return FilterChip(
              label: Text(type),
              selected: selected,
              onSelected: (v) => setState(() {
                v ? _preferredPhotoTypes.add(type) : _preferredPhotoTypes.remove(type);
              }),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              selectedColor: AppColors.primary,
              side: BorderSide(color: selected ? AppColors.primary : Theme.of(context).colorScheme.outline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        CustomTextField(
          label: 'Preferred City',
          icon: Icons.location_city_rounded,
          controller: _preferredCityController,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Budget Min',
                icon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _budgetMinController,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomTextField(
                label: 'Budget Max',
                icon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _budgetMaxController,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Single-select chip row — same visual language as the [FilterChip]
/// multi-select pattern used for Specializations/Availability Days, but
/// picking a new option deselects the previous one. Used for fields
/// backed by a single nullable string (Studio Type, Gender) rather than
/// a `List<String>`.
class _SingleChoiceChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SingleChoiceChips({required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected == option;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (v) => onSelected(v ? option : null),
          showCheckmark: false,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          selectedColor: AppColors.primary,
          side: BorderSide(color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        );
      }).toList(),
    );
  }
}

/// Tappable, [CustomTextField]-styled field that opens [showDatePicker]
/// instead of the keyboard — used for Date of Birth.
class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.icon, required this.value, required this.onTap});

  String _format(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: Icon(Icons.calendar_month_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
        ),
        child: Text(
          value != null ? _format(value!) : 'Select date',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: value != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Styled to match [CustomTextField]'s icon/label look, but with no
/// controller/focus behavior at all — the Email field is read-only per
/// Task 7 (email changes aren't part of this screen).
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyField({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final outlineColor = Theme.of(context).colorScheme.outline;
    final bgColor = isDark
        ? AppColors.darkSurfaceRaised.withValues(alpha: 0.5)
        : AppColors.border.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: outlineColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: onSurfaceVariant, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, color: onSurfaceVariant, size: 16),
        ],
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            GradientButton(label: 'Retry', onPressed: onRetry, height: 48),
          ],
        ),
      ),
    );
  }
}