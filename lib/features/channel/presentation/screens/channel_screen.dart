import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:itaaleem/features/channel/presentation/providers/channel_providers.dart';
import 'package:itaaleem/features/channel/presentation/widgets/channel_message_card.dart';
import 'package:itaaleem/features/channel/presentation/widgets/channel_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// "القناة" tab: the last 50 broadcast messages from `GET /channel`, newest
/// first with pinned ones glued to the top.
///
/// `FLAG_SECURE` for this tab is toggled by `HomeShell` itself, based on
/// which tab is actually selected — not by wrapping this widget in
/// `SecureScreen` the way a normally-pushed route would. `HomeShell` keeps
/// every tab alive at once via `IndexedStack` (so switching tabs doesn't
/// lose scroll position/state), which means this widget's own
/// `initState`/`dispose` would fire once for the shell's whole lifetime
/// instead of each time the student actually switches to/away from this
/// tab — wrapping it in `SecureScreen` here would leak `FLAG_SECURE` onto
/// the entire app the instant the shell first builds, and never clear it.
class ChannelScreen extends ConsumerWidget {
  const ChannelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(channelMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('القناة'),
      ),
      body: RefreshIndicator(
        color: context.palette.primary,
        onRefresh: () => ref.refresh(channelMessagesProvider.future),
        child: messagesAsync.when(
          loading: () => const ChannelShimmer(),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 420,
                child: ErrorView(
                  message: 'تعذر تحميل رسائل القناة، حاول مرة أخرى',
                  retryLabel: 'إعادة المحاولة',
                  onRetry: () => ref.invalidate(channelMessagesProvider),
                ),
              ),
            ],
          ),
          data: (messages) {
            if (messages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 420, child: _EmptyChannel()),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.all(16),
              itemCount: messages.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => FadeSlideIn(
                delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
                child: ChannelMessageCard(message: messages[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyChannel extends StatelessWidget {
  const _EmptyChannel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.palette.primary.withValues(alpha: 0.12),
                  context.palette.primary.withValues(alpha: 0.04),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.campaign_rounded,
              size: 42,
              color: context.palette.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'لا توجد رسائل بعد',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'ستظهر هنا رسائل وتحديثات الأكاديمية',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
