import 'package:itaaleem/features/chat/domain/entities/message_model.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

String _formatTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 < 12 ? 'ص' : 'م';
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isMine ? context.palette.primary : context.palette.surface,
            border: isMine ? null : Border.all(color: context.palette.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isMine ? context.palette.onPrimary : context.palette.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: isMine
                      ? context.palette.onPrimary.withValues(alpha: 0.7)
                      : context.palette.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
