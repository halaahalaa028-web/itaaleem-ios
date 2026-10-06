import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `GET /center-admin/banners` — add / edit / delete, enable toggle.
class CenterBannersScreen extends ConsumerWidget {
  const CenterBannersScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    AdminRecord? banner,
  }) async {
    final values = await showAdminForm(
      context,
      title: banner == null ? 'إضافة بنر' : 'تعديل البنر',
      fields: [
        AdminField(
          'title',
          'العنوان',
          icon: Icons.title_rounded,
          initial: banner?.text(['title']),
          required: true,
        ),
        AdminField(
          'image_url',
          'رابط الصورة',
          icon: Icons.image_rounded,
          initial: banner?.image,
          keyboard: TextInputType.url,
          required: banner == null,
        ),
        AdminField(
          'link',
          'رابط عند الضغط (اختياري)',
          icon: Icons.link_rounded,
          initial: banner?.text(['link', 'url', 'target_url']),
          keyboard: TextInputType.url,
        ),
      ],
      extra: (values, setState) {
        values.putIfAbsent(
          'is_active',
          () => banner == null ? true : banner.status == 'active',
        );
        return [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('مفعّل'),
            value: values['is_active'] as bool,
            onChanged: (v) => setState(() => values['is_active'] = v),
          ),
        ];
      },
    );
    if (values == null || !context.mounted) return;
    final repo = ref.read(centerAdminRepositoryProvider);
    await runAdminAction(
      context,
      ref,
      () => banner == null
          ? repo.create('banners', values)
          : repo.update('banners/${banner.id}', values),
      success: banner == null ? 'تمت إضافة البنر' : 'تم حفظ التعديلات',
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AdminRecord banner,
  ) async {
    final ok = await confirmAdmin(
      context,
      title: 'حذف البنر',
      message: 'حذف "${banner.title}"؟',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      () => ref
          .read(centerAdminRepositoryProvider)
          .remove('banners/${banner.id}'),
      success: 'تم حذف البنر',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('البنرات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('بنر جديد'),
      ),
      body: AdminDataTable(
        path: 'banners',
        emptyTitle: 'لا توجد بنرات',
        emptyIcon: Icons.view_carousel_outlined,
        bottomPadding: 96,
        itemBuilder: (context, r) => AdminRecordCard(
          title: r.text(['title']) ?? r.title,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 72,
              height: 44,
              color: scheme.surfaceContainerHighest,
              child: r.image == null
                  ? Icon(Icons.image_rounded, color: scheme.onSurfaceVariant)
                  : Image.network(
                      r.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          lines: [
            r.text(['link', 'url', 'target_url']),
          ],
          trailing: adminStatusBadge(r.status ?? 'active'),
          menu: [
            AdminMenuAction(
              'تعديل',
              Icons.edit_rounded,
              () => _edit(context, ref, banner: r),
            ),
            AdminMenuAction(
              'حذف',
              Icons.delete_rounded,
              () => _delete(context, ref, r),
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}
