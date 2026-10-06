import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/ai/domain/entities/ai_answer.dart';
import 'package:itaaleem/features/ai/presentation/providers/ai_providers.dart';
import 'package:itaaleem/features/courses/presentation/providers/courses_providers.dart';
import 'package:itaaleem/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// "المساعد الذكي" tab: a simple chat with `POST /ai/ask`, gated by
/// `ai_enabled` from `GET /public/settings`.
class AiAssistantTab extends ConsumerWidget {
  const AiAssistantTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('المساعد الذكي'),
      ),
      body: settingsAsync.when(
        loading: () => const ShimmerList(count: 3, thumbnailSize: 40),
        // Settings failing to load must never block the chat itself (same
        // fail-open policy other settings-gated features follow) — only an
        // explicit `aiEnabled == false` shows [_AiUnavailable].
        error: (error, stackTrace) => const _AiChatBody(),
        data: (settings) =>
            settings.aiEnabled ? const _AiChatBody() : const _AiUnavailable(),
      ),
    );
  }
}

class _AiUnavailable extends StatelessWidget {
  const _AiUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: context.palette.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: context.palette.onPrimary,
                size: 44,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'الميزة غير متاحة حالياً',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class _AiChatBody extends ConsumerStatefulWidget {
  const _AiChatBody();

  @override
  ConsumerState<_AiChatBody> createState() => _AiChatBodyState();
}

class _AiChatBodyState extends ConsumerState<_AiChatBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;
  int? _remainingQuestions;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _sending) return;

    final courses = ref.read(coursesProvider).valueOrNull;
    final courseId = (courses != null && courses.isNotEmpty) ? courses.first.id : null;

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final useCase = ref.read(askAiUseCaseProvider);
    final result = await useCase(question, courseId: courseId);
    if (!mounted) return;

    switch (result) {
      case Ok<AiAnswer>(:final value):
        setState(() {
          _messages.add(_ChatMessage(text: value.answer, isUser: false));
          _remainingQuestions = value.remainingQuestions;
          _sending = false;
        });
        _scrollToBottom();
      case Err<AiAnswer>(:final failure):
        setState(() => _sending = false);
        AppToast.showError(
          context,
          failure.message.isNotEmpty
              ? failure.message
              : 'تعذر إرسال السؤال، حاول مرة أخرى',
        );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_remainingQuestions != null) _RemainingBanner(count: _remainingQuestions!),
        Expanded(
          child: _messages.isEmpty
              ? const _EmptyChatHint()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsetsDirectional.all(16),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _messages.length) {
                      return const _TypingBubble();
                    }
                    return _ChatBubble(message: _messages[index]);
                  },
                ),
        ),
        _ChatInput(controller: _controller, sending: _sending, onSend: _send),
      ],
    );
  }
}

class _RemainingBanner extends StatelessWidget {
  const _RemainingBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: context.palette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 16,
            color: context.palette.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'الأسئلة المتبقية اليوم: $count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: context.palette.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: context.palette.onPrimary,
                size: 44,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'اسأل المساعد الذكي',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'اسأل أي سؤال عن موادك وسيجيبك فوراً من ملزماتك',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary : colorScheme.surface,
          border: isUser ? null : Border.all(color: colorScheme.outline),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(AppRadius.lg),
            topEnd: const Radius.circular(AppRadius.lg),
            bottomStart: Radius.circular(isUser ? 16 : 4),
            bottomEnd: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.base,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(18),
            topEnd: Radius.circular(18),
            bottomEnd: Radius.circular(18),
            bottomStart: Radius.circular(AppRadius.xs),
          ),
        ),
        child: SizedBox(
          width: 20,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.palette.primary,
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك هنا...',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: context.palette.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: sending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
