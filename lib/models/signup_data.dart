import '../../core/routes/app_routes.dart';

/// Data class carrying registration parameters from [RegisterScreen]
/// into [EmailVerificationScreen] and then [CompleteProfileScreen].
///
/// Mirrors the backend's `POST /auth/register` request shape so the
/// verification screen can prefill the email display and the
/// complete-profile screen can skip asking for fields already collected.
class SignupData {
  final UserRole role;
  final String name;
  final String email;
  final String password;
  final String? studioName;
  final String? studioAddress;
  final String? businessType;

  const SignupData({
    required this.role,
    required this.name,
    required this.email,
    required this.password,
    this.studioName,
    this.studioAddress,
    this.businessType,
  });
}

