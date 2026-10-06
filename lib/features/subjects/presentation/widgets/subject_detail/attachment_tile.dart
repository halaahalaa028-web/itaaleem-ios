import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_section.dart';

class AttachmentTileData {
  const AttachmentTileData({required this.name, this.type, this.sizeLabel});

  final String name;

  /// File extension/type (e.g. "PDF", "docx"); picks the icon.
  final String? type;
  final String? sizeLabel;
}

/// One subject file: type icon, name, "PDF • 2.5 MB" and an action button —
/// download when [onDownload] is set, otherwise open. Tapping the card
/// always opens it.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.data,
    required this.onOpen,
    this.onDownload,
  });

  final AttachmentTileData data;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = _iconFor(context, data.type);
    final type = data.type?.trim().toUpperCase();
    final meta = [
      if (type != null && type.isNotEmpty) type,
      if (data.sizeLabel != null) data.sizeLabel!,
    ].join(' • ');

    return SubjectTileShell(
      onTap: onOpen,
      child: Row(
        children: [
          SubjectTileIcon(icon: icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: subjectTileTitleStyle,
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: onDownload != null ? 'تحميل' : 'فتح',
            onPressed: onDownload ?? onOpen,
            icon: Icon(
              onDownload != null
                  ? Icons.download_rounded
                  : Icons.open_in_new_rounded,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _iconFor(BuildContext context, String? type) {
    final palette = context.palette;
    final t = (type ?? '').toLowerCase();
    if (t.contains('pdf')) return (Icons.picture_as_pdf_rounded, palette.error);
    if (t.contains('doc') || t.contains('txt') || t.contains('rtf')) {
      return (Icons.description_rounded, palette.info);
    }
    if (t.contains('ppt') || t.contains('key')) {
      return (Icons.slideshow_rounded, palette.warning);
    }
    if (t.contains('xls') || t.contains('csv')) {
      return (Icons.table_chart_rounded, palette.success);
    }
    if (const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'image'].any(t.contains)) {
      return (Icons.image_rounded, palette.primary);
    }
    if (const ['zip', 'rar', '7z'].any(t.contains)) {
      return (Icons.folder_zip_rounded, palette.textSecondary);
    }
    if (const ['mp3', 'wav', 'm4a', 'audio'].any(t.contains)) {
      return (Icons.audiotrack_rounded, palette.primary);
    }
    return (Icons.insert_drive_file_rounded, palette.primary);
  }
}
