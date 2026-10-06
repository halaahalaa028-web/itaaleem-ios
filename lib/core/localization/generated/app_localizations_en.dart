// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'منصة أونلاين';

  @override
  String get splashTagline => 'Education without borders';

  @override
  String get login => 'Log In';

  @override
  String get register => 'Register';

  @override
  String get logout => 'Log Out';

  @override
  String get fullName => 'Full Name';

  @override
  String get mobile => 'Mobile Number';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get loginButton => 'Log In';

  @override
  String get registerButton => 'Create Account';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginSubtitle => 'Log in to continue your learning journey';

  @override
  String get createAccount => 'Create Your Account';

  @override
  String get registerSubtitle => 'Join منصة أونلاين and start learning';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidMobile => 'Invalid mobile number';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get genericError => 'Something went wrong, please try again';

  @override
  String get networkError =>
      'Could not reach the server, check your connection';

  @override
  String get unauthorizedError => 'Invalid credentials';

  @override
  String get homeWelcome => 'Welcome';

  @override
  String get homeSubtitle => 'Great to have you back at منصة أونلاين';
}
