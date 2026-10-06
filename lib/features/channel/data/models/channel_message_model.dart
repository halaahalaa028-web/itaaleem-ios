import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/channel/domain/entities/channel_message.dart';

/// Maps one item of `GET /channel`'s message array onto [ChannelMessage].
/// Field names are hedged defensively, the same way other models in this
/// app do (the exact backend shape isn't pinned down in APP_SPEC.md yet).
class ChannelMessageModel extends ChannelMessage {
  const ChannelMessageModel({
    required super.id,
    required super.createdAt,
    super.text,
    super.imageUrl,
    super.isPinned,
  });

  factory ChannelMessageModel.fromJson(Map<String, dynamic> json) {
    return ChannelMessageModel(
      id: _asInt(json['id']),
      text: _asNonEmpty(json['text'] ?? json['body'] ?? json['message'] ?? json['content']),
      imageUrl: ApiEndpoints.mediaUrl(
        (json['image'] ?? json['image_url'] ?? json['photo']) as String?,
      ),
      isPinned: (json['is_pinned'] ?? json['pinned'] ?? false) == true,
      createdAt: _asDate(json['created_at']),
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _asNonEmpty(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _asDate(Object? value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
