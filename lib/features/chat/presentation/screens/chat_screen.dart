import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';
import 'package:itaaleem/features/chat/data/datasources/messages_remote_data_source.dart';
import 'package:itaaleem/features/chat/domain/entities/message_model.dart';
import 'package:itaaleem/features/chat/presentation/providers/chat_providers.dart';
import 'package:itaaleem/features/chat/presentation/widgets/message_bubble.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Newest-first dummy conversation seed (paired with `ListView.builder`'s
/// `reverse: true` below, so index 0 renders at the bottom of the screen)
/// — stands in for a future `GET /chat/{centerId}` history.
List<MessageModel> _seedMessages({required int studentId, required int centerId}) {
  final today = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(today.year, today.month, today.day, hour, minute);

  final chronological = [
    MessageModel(
      id: '1',
      body: 'أهلاً بيك في سنتر الأستاذ عامر! لو محتاج أي حاجة كلمنا 😊',
      senderId: centerId,
      receiverId: studentId,
      isMine: false,
      createdAt: at(10, 0),
    ),
    MessageModel(
      id: '2',
      body: 'شكراً! عايز أعرف مواعيد المحاضرات',
      senderId: studentId,
      receiverId: centerId,
      isMine: true,
      createdAt: at(10, 2),
    ),
    MessageModel(
      id: '3',
      body: 'المحاضرات كل يوم سبت وثلاثاء من 4 لـ 6 مساءً',
      senderId: centerId,
      receiverId: studentId,
      isMine: false,
      createdAt: at(10, 5),
    ),
    MessageModel(
      id: '4',
      body: 'تمام، وامتحان نص الترم إمتى؟',
      senderId: studentId,
      receiverId: centerId,
      isMine: true,
      createdAt: at(10, 6),
    ),
    MessageModel(
      id: '5',
      body: 'الأسبوع الجاي إن شاء الله — هنبعتلك إشعار بالتفاصيل',
      senderId: centerId,
      receiverId: studentId,
      isMine: false,
      createdAt: at(10, 10),
    ),
    MessageModel(
      id: '6',
      body: 'حاضر يا أستاذ',
      senderId: studentId,
      receiverId: centerId,
      isMine: true,
      createdAt: at(10, 11),
    ),
    MessageModel(
      id: '7',
      body: 'بالتوفيق! 💪',
      senderId: centerId,
      receiverId: studentId,
      isMine: false,
      createdAt: at(10, 12),
    ),
    MessageModel(
      id: '8',
      body: 'شكراً جزيلاً',
      senderId: studentId,
      receiverId: centerId,
      isMine: true,
      createdAt: at(10, 13),
    ),
  ];
  return chronological.reversed.toList();
}

/// Student <-> center chat. A demo ("دخول تجريبي") session keeps the old
/// dummy conversation and purely local sending exactly as before; a real
/// session loads/sends through `GET`/`POST /messages`.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageModel>? _messages;
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendDemo(int studentId, int centerId) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages!.insert(
        0,
        MessageModel(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          body: text,
          senderId: studentId,
          receiverId: centerId,
          isMine: true,
          createdAt: DateTime.now(),
        ),
      );
    });
    _inputController.clear();
    _scrollToBottom();
  }

  Future<void> _sendReal() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    final optimistic = MessageModel(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      body: text,
      senderId: 0,
      receiverId: 0,
      isMine: true,
      createdAt: DateTime.now(),
    );
    // The list lives in ChatController (kept alive + cached on disk), so the
    // message survives leaving the chat even while it's still sending.
    final chat = ref.read(chatControllerProvider.notifier);
    final source = ref.read(messagesRemoteDataSourceProvider);
    chat.addPending(optimistic);
    setState(() => _sending = true);
    _inputController.clear();
    _scrollToBottom();
    try {
      final sent = await source.sendMessage(text);
      chat.resolvePending(optimistic.id, sent);
    } on DioException catch (e) {
      chat.removePending(optimistic.id);
      if (mounted) {
        // Give the text back so nothing typed is lost.
        if (_inputController.text.isEmpty) _inputController.text = text;
        AppToast.showError(context, failureOf(e).message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refreshReal() => ref.read(chatControllerProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final (isDemo, studentId) = ref.watch(
      authControllerProvider.select(
        (state) => (
          state.valueOrNull?.isDemo ?? false,
          state.valueOrNull?.id ?? 0,
        ),
      ),
    );
    final membership = ref.watch(centerMembershipProvider).valueOrNull;
    final center = membership == null
        ? null
        : ref.watch(centerByIdProvider(membership.centerId));
    final centerId = center?.id ?? 0;
    final centerName = center?.name ?? 'السنتر';
    final centerInitial = center?.initial ?? 'س';

    if (isDemo) {
      _messages ??= _seedMessages(studentId: studentId, centerId: centerId);
      return _buildScaffold(
        centerName: centerName,
        centerInitial: centerInitial,
        messages: _messages!,
        onSend: () => _sendDemo(studentId, centerId),
      );
    }

    final messagesAsync = ref.watch(chatControllerProvider);
    return messagesAsync.when(
      loading: () => Scaffold(
        appBar: _buildAppBar(centerName, centerInitial),
        body: const ShimmerList(count: 5, thumbnailSize: 36),
      ),
      error: (error, _) => Scaffold(
        appBar: _buildAppBar(centerName, centerInitial),
        body: ErrorView(
          message: failureOf(error).message,
          retryLabel: 'إعادة المحاولة',
          onRetry: () => ref.invalidate(chatControllerProvider),
        ),
      ),
      data: (messages) {
        return _buildScaffold(
          centerName: centerName,
          centerInitial: centerInitial,
          messages: messages,
          onSend: _sendReal,
          onRefresh: _refreshReal,
        );
      },
    );
  }

  AppBar _buildAppBar(String centerName, String centerInitial) {
    return AppBar(
      backgroundColor: context.palette.surface,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.palette.primary,
            child: Text(
              centerInitial,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.palette.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'متصل الآن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: context.palette.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffold({
    required String centerName,
    required String centerInitial,
    required List<MessageModel> messages,
    required VoidCallback onSend,
    Future<void> Function()? onRefresh,
  }) {
    final list = messages.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(
                child: Text(
                  'ابدأ محادثة مع السنتر',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.textSecondary),
                ),
              ),
            ],
          )
        : ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            itemCount: messages.length + 1,
            itemBuilder: (context, index) {
              if (index == messages.length) {
                return const _DateDivider(label: 'اليوم');
              }
              final message = messages[index];
              final older =
                  index + 1 < messages.length ? messages[index + 1] : null;
              final spacing =
                  (older == null || older.isMine != message.isMine) ? 12.0 : 6.0;
              return Padding(
                padding: EdgeInsets.only(top: spacing),
                child: MessageBubble(message: message),
              );
            },
          );

    return Scaffold(
      appBar: _buildAppBar(centerName, centerInitial),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: onRefresh == null
                  ? list
                  : RefreshIndicator(onRefresh: onRefresh, child: list),
            ),
            _ChatInputBar(controller: _inputController, onSend: onSend),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
          decoration: BoxDecoration(
            color: context.palette.surfaceVariant,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.palette.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(top: BorderSide(color: context.palette.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: null,
              icon: Icon(
                Icons.attach_file_rounded,
                color: context.palette.textTertiary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  filled: true,
                  fillColor: context.palette.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: 10,
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
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSend,
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    Icons.send_rounded,
                    color: context.palette.onPrimary,
                    size: 22,
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
