import 'dart:io';

import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/student_avatar.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:itaaleem/features/auth/presentation/widgets/pick_profile_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// `PUT /profile`: edit the student's display name and/or profile photo.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  XFile? _pickedImage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final student = ref.read(authControllerProvider).valueOrNull;
    _fullNameController = TextEditingController(text: student?.fullName ?? '');
    _mobileController = TextEditingController(text: student?.mobile ?? '');
    _emailController = TextEditingController(text: student?.email ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceSheet() async {
    final image = await pickProfileImage(context);
    if (image != null) setState(() => _pickedImage = image);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Only what changed (the name is always sent — the API requires it);
    // re-sending the student's own mobile can trip a "taken" check.
    final student = ref.read(authControllerProvider).valueOrNull;
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    setState(() => _submitting = true);
    final failure = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          fullName: _fullNameController.text.trim(),
          mobile: mobile == (student?.mobile ?? '') ? null : mobile,
          email: email == (student?.email ?? '') ? null : email,
          avatarFilePath: _pickedImage?.path,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (failure != null) {
      AppToast.showError(
        context,
        failure.message.isNotEmpty
            ? failure.message
            : 'حدث خطأ ما، حاول مرة أخرى',
      );
      return;
    }
    if (!mounted) return;
    AppToast.showSuccess(context, 'تم تحديث الملف الشخصي بنجاح');
    Navigator.of(context).pop();
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  String? _validateMobile(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'هذا الحقل مطلوب';
    final digits = v.replaceAll(RegExp(r'[\s\-+]'), '');
    if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) return 'رقم الهاتف غير صحيح';
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // optional
    return _emailPattern.hasMatch(v) ? null : 'البريد الإلكتروني غير صحيح';
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authControllerProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Photo ---------------------------------------------
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'تغيير الصورة الشخصية',
                        child: StudentAvatar(
                          radius: 52,
                          avatarUrl: student?.avatarUrl,
                          localFile: _pickedImage != null
                              ? File(_pickedImage!.path)
                              : null,
                          onTap: _showImageSourceSheet,
                          showCameraBadge: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton.icon(
                        onPressed: _showImageSourceSheet,
                        icon: const Icon(Icons.photo_camera_rounded, size: 18),
                        label: const Text('تغيير الصورة'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // --- Personal info -------------------------------------
                    _SectionCard(
                      title: 'البيانات الشخصية',
                      icon: Icons.person_rounded,
                      children: [
                        AuthTextField(
                          controller: _fullNameController,
                          label: 'الاسم الكامل',
                          icon: Icons.badge_rounded,
                          textInputAction: TextInputAction.next,
                          validator: _required,
                        ),
                        const SizedBox(height: AppSpacing.base),
                        AuthTextField(
                          controller: _emailController,
                          label: 'البريد الإلكتروني (اختياري)',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.base),
                        AuthTextField(
                          controller: _mobileController,
                          label: 'رقم الهاتف',
                          icon: Icons.phone_iphone_rounded,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          validator: _validateMobile,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // --- Security ------------------------------------------
                    _SectionCard(
                      title: 'الأمان',
                      icon: Icons.shield_rounded,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.lock_reset_rounded,
                            color: scheme.primary,
                          ),
                          title: Text('كلمة المرور', style: text.titleSmall),
                          subtitle: Text(
                            'غيّر كلمة المرور الخاصة بحسابك',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          // The theme's minimumSize is `Size.fromHeight`
                          // (infinite width) — impossible in a ListTile
                          // trailing slot; that threw and left the page blank.
                          trailing: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(72, 40),
                            ),
                            onPressed: () => context.push(changePasswordPath),
                            child: const Text('تغيير'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Pinned above the keyboard (the Scaffold resizes for it).
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.base,
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('حفظ التغييرات'),
          ),
        ),
      ),
    );
  }
}

/// A titled group of fields.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          ...children,
        ],
      ),
    );
  }
}
