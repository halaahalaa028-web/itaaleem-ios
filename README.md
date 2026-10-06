# منصة أونلاين — iOS Build

## المتطلبات
- macOS مع Xcode 15.4+
- Flutter SDK 3.x (stable)
- CocoaPods (`sudo gem install cocoapods`)
- Apple Developer Account

## خطوات البناء

### 1. تثبيت Dependencies
```bash
flutter pub get
cd ios && pod install --repo-update && cd ..
```
`flutter pub get` بيولّد ملفات `ios/Flutter/Generated.xcconfig` وغيرها تلقائياً —
مش موجودة في الحزمة عن قصد (فيها مسارات خاصة بالجهاز).

### 2. فتح المشروع في Xcode
```bash
open ios/Runner.xcworkspace
```
⚠️ افتح `.xcworkspace` مش `.xcodeproj`

### 3. إعدادات Signing
1. اختار Runner target
2. Signing & Capabilities:
   - Team: اختار حساب Apple Developer
   - Bundle ID: `com.itaaleem.app`

### 4. Capabilities
موجودين بالفعل في المشروع — تأكد بس إنهم ظاهرين بعد اختيار الـ Team:
- Push Notifications (`Runner.entitlements` → `aps-environment`)
- Background Modes → Remote notifications + Background fetch

### 5. إعداد الإشعارات (مهم)
1. في developer.apple.com:
   - Certificates, Identifiers & Keys → Keys
   - أنشئ APNs Key (ملف .p8)
   - سجّل Key ID و Team ID
2. في Firebase Console:
   - Project Settings → Cloud Messaging
   - ارفع ملف الـ .p8
   - اكتب Key ID و Team ID

⚠️ ملف الـ `.p8` سرّي — ما يتحطش في المشروع ولا في git.

### 6. Build & Archive
يُفضّل البناء مع obfuscation:
```bash
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
```
احتفظ بمجلد `build/debug-info` — محتاجه عشان تقرا تقارير الأعطال.

أو من Xcode:
- Product → Archive
- Distribute App → App Store Connect

### 7. رفع على App Store Connect
- من Xcode بعد Archive → Distribute
- أو باستخدام Transporter app

## معلومات التطبيق
- **الاسم**: منصة أونلاين
- **Bundle ID**: com.itaaleem.app
- **اللغة**: العربية
- **Deployment Target**: iOS 15.0 (مطلوب لـ Firebase — ما تنزّلوش)
- **الإصدار**: 3.0.0 (Build 37)

  رقم الـ Build بييجي من `pubspec.yaml` (`version: 3.0.0+37`) — مشترك مع
  Android اللي استخدم لحد 36، فمش ممكن يبقى 1. App Store بيقبل 37 كأول build.

## الصلاحيات المطلوبة (Info.plist)
- Push Notifications (إشعارات)
- Photo Library (صورة البروفايل)
- Camera / Microphone (مكتبة image_picker بتطلبهم — من غيرهم App Store بيرفض الـ build)

## ملاحظات
- التطبيق عربي فقط (RTL)
- الإشعارات لا تعمل على Simulator — لازم جهاز حقيقي
- لا تغيّر الـ Bundle ID — مربوط بـ Firebase (`ios/Runner/GoogleService-Info.plist`)
- على iOS الاشتراكات والمدفوعات مخفية من واجهة الطالب (سياسة Apple) — ده مقصود
