// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'منصة أونلاين';

  @override
  String get splashTagline => 'تعليم بلا حدود';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get mobile => 'رقم الموبايل';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get loginButton => 'دخول';

  @override
  String get registerButton => 'إنشاء حساب';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get loginSubtitle => 'سجّل الدخول لمتابعة رحلتك التعليمية';

  @override
  String get createAccount => 'أنشئ حسابك';

  @override
  String get registerSubtitle => 'انضم إلى منصة أونلاين وابدأ التعلم';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get invalidMobile => 'رقم الموبايل غير صالح';

  @override
  String get passwordTooShort => 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';

  @override
  String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get genericError => 'حدث خطأ ما، حاول مرة أخرى';

  @override
  String get networkError => 'تعذر الاتصال بالخادم، تحقق من الإنترنت';

  @override
  String get unauthorizedError => 'بيانات الدخول غير صحيحة';

  @override
  String get homeWelcome => 'أهلاً بك';

  @override
  String get homeSubtitle => 'سعداء بعودتك إلى منصة أونلاين';
}
