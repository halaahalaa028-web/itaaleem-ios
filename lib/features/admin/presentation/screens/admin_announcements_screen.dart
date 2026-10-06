import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_input.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_widgets.dart';

/// Center announcements: list (with an active switch and delete) plus a
/// FAB to post a new one — optionally with an image and a push
/// notification to the students.
class AdminAnnouncementsScreen extends ConsumerWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(adminAnnouncementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات')),
      floatingActionButton: announcements.hasValue
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => const _AnnouncementForm(),
                );
                if (created == true) ref.invalidate(adminAnnouncementsProvider);
              },
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('إعلان جديد'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminAnnouncementsProvider.future),
        child: announcements.when(
          loading: () => const ShimmerList(count: 4),
          error: (e, _) => AdminScrollable(
            child: AdminErrorView(
              error: e,
              onRetry: () => ref.invalidate(adminAnnouncementsProvider),
              panelPath: 'announcements',
            ),
          ),
          data: (items) => items.isEmpty
              ? const AdminScrollable(
                  child: AppEmptyState(
                    icon: Icons.campaign_rounded,
                    title: 'لا توجد إعلانات بعد',
                    subtitle: 'اضغط "إعلان جديد" لإرسال أول إعلان للطلاب',
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.base,
                    AppSpacing.screenHorizontal,
                    96,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.listItemSpacing),
                  itemBuilder: (context, i) =>
                      _AnnouncementCard(announcement: items[i]),
                ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerStatefulWidget {
  const _AnnouncementCard({required this.announcement});

  final AdminAnnouncement announcement;

  @override
  ConsumerState<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<_AnnouncementCard> {
  late bool _active = widget.announcement.isActive;
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() {
      _active = value;
      _saving = true;
    });
    final ok = await runAdminAction(
      context,
      () => ref.read(adminRepositoryProvider).updateAnnouncement(
        widget.announcement.id,
        {'is_active': value},
      ),
      successMessage: value ? 'الإعلان ظاهر للطلاب' : 'تم إخفاء الإعلان',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _active = !value;
    });
  }

  Future<void> _delete() async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'حذف الإعلان',
      message: 'حذف "${widget.announcement.title}" نهائياً؟',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .deleteAnnouncement(widget.announcement.id),
      successMessage: 'تم حذف الإعلان',
    );
    if (ok) ref.invalidate(adminAnnouncementsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = widget.announcement;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (a.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) => CachedNetworkImage(
                    imageUrl: a.imageUrl!,
                    fit: BoxFit.cover,
                    // Decode at display size, not the full upload size.
                    memCacheWidth:
                        (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    placeholder: (_, _) =>
                        ColoredBox(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) => ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.base,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(a.title, style: text.titleSmall)),
                    Switch(value: _active, onChanged: _saving ? null : _toggle),
                    IconButton(
                      tooltip: 'حذف',
                      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                      onPressed: _delete,
                    ),
                  ],
                ),
                if (a.body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.md,
                    ),
                    child: Text(a.body, style: text.bodyMedium),
                  ),
                if (a.createdAt != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    displayDate(a.createdAt!),
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementForm extends ConsumerStatefulWidget {
  const _AnnouncementForm();

  @override
  ConsumerState<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends ConsumerState<_AnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _imagePath;
  bool _active = true;
  bool _sendPush = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked != null) setState(() => _imagePath = picked.path);
    } catch (_) {
      if (mounted) AppToast.showError(context, 'تعذر اختيار الصورة');
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .createAnnouncement(
            title: _title.text.trim(),
            body: _body.text.trim(),
            isActive: _active,
            sendPush: _active && _sendPush,
            imagePath: _imagePath,
          ),
      successMessage: _active && _sendPush
          ? 'تم نشر الإعلان وإرسال الإشعار'
          : 'تم حفظ الإعلان',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? 'مطلوب' : null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.base,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إعلان جديد', style: text.titleMedium),
              const SizedBox(height: AppSpacing.base),
              AppInput(
                label: 'العنوان',
                controller: _title,
                validator: required,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppInput(
                label: 'نص الإعلان',
                controller: _body,
                validator: required,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_imagePath == null)
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('إضافة صورة (اختياري)'),
                )
              else
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                      ),
                    ),
                    PositionedDirectional(
                      top: AppSpacing.xs,
                      end: AppSpacing.xs,
                      child: IconButton.filledTonal(
                        tooltip: 'إزالة الصورة',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _imagePath = null),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ظاهر للطلاب'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إرسال إشعار للطلاب'),
                subtitle: _active
                    ? null
                    : Text(
                        'الإشعار بيتبعت مع الإعلانات الظاهرة بس',
                        style: text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                value: _active && _sendPush,
                onChanged: _active
                    ? (v) => setState(() => _sendPush = v)
                    : null,
              ),
              const SizedBox(height: AppSpacing.base),
              AppButton.primary(
                'نشر',
                icon: Icons.send_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
