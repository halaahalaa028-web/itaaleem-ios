import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_input.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center/data/models/center_review.dart';
import 'package:itaaleem/features/center/presentation/providers/reviews_providers.dart';
import 'package:itaaleem/features/center/presentation/widgets/review_widgets.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Add a review, or — when [existing] is passed — edit the student's own.
class ReviewFormScreen extends ConsumerStatefulWidget {
  const ReviewFormScreen({super.key, required this.centerId, this.existing});

  final int centerId;
  final CenterReview? existing;

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment);
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_rating == 0) {
      AppToast.showError(context, 'اختار عدد النجوم أولاً');
      return;
    }
    setState(() => _sending = true);
    final controller = ref.read(
      reviewsControllerProvider(widget.centerId).notifier,
    );
    final text = _comment.text.trim();
    try {
      final existing = widget.existing;
      if (existing == null) {
        await controller.submit(_rating, text);
      } else {
        await controller.updateReview(existing.id, _rating, text);
      }
      if (!mounted) return;
      AppToast.showSuccess(
        context,
        existing == null ? 'تم إرسال تقييمك، شكراً لك' : 'تم تحديث تقييمك',
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.showError(context, failureOf(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل تقييمك' : 'أضف تقييمك')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ما تقييمك للسنتر؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              StarPicker(
                value: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppInput(
                controller: _comment,
                hint: 'اكتب تعليقك (اختياري)',
                maxLines: 5,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(
                editing ? 'حفظ التعديل' : 'إرسال',
                loading: _sending,
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
