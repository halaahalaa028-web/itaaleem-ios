import 'dart:async';

import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_input.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center/data/datasources/centers_remote_data_source.dart';
import 'package:itaaleem/features/center/data/dummy/center_dummy_data.dart';
import 'package:itaaleem/features/center/domain/entities/center_model.dart';
import 'package:itaaleem/features/center/presentation/screens/center_profile_screen.dart';
import 'package:itaaleem/features/center/presentation/utils/center_color.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Standalone route wrapper around [CenterSearchBody] (own [Scaffold] +
/// app bar) — kept for any direct/deep-link navigation to the search flow.
/// [HomeScreen] embeds [CenterSearchBody] directly instead, as its "لم
/// ينضم بعد" state, so students aren't confined to this screen to join.
class CenterSearchScreen extends StatelessWidget {
  const CenterSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ابحث عن سنترك')),
      body: const SafeArea(child: CenterSearchBody()),
    );
  }
}

/// Code-only center search + join entry point: the student enters the
/// center's own code (handed to them by their teacher/center) rather than
/// browsing or searching a list — `GET /centers?code=`. Tapping "انضم لهذا
/// السنتر" on a found center pushes [CenterProfileScreen], which in turn
/// pushes [SelectGradeScreen] to actually confirm the join.
class CenterSearchBody extends ConsumerStatefulWidget {
  const CenterSearchBody({super.key});

  @override
  ConsumerState<CenterSearchBody> createState() => _CenterSearchBodyState();
}

class _CenterSearchBodyState extends ConsumerState<CenterSearchBody> {
  final _codeController = TextEditingController();
  bool _searching = false;
  CenterModel? _foundCenter;
  bool _notFound = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _searching = true;
      _foundCenter = null;
      _notFound = false;
      _errorMessage = null;
    });

    // Demo ("دخول تجريبي"): any code returns the same local demo center —
    // there's no real backend to look one up against.
    final isDemo =
        ref.read(authControllerProvider).valueOrNull?.isDemo ?? false;
    if (isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _searching = false;
        _foundCenter = centerDummyData.first;
      });
      return;
    }

    try {
      final center = await ref
          .read(centersRemoteDataSourceProvider)
          .getCenterByCode(code)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _searching = false;
        _foundCenter = center;
        _notFound = center == null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final failure = failureOf(e);
      setState(() {
        _searching = false;
        _errorMessage = failure is NetworkFailure
            ? 'تأكد من اتصالك بالإنترنت'
            : failure.message;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _errorMessage = 'استغرق البحث وقتاً طويلاً، حاول مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.palette.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              size: 40,
              color: context.palette.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'انضم لسنترك',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ادخل الكود اللي المدرس أو السنتر اداهولك',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppInput(
            controller: _codeController,
            label: 'كود السنتر',
            hint: 'مثال: AX-204',
            prefixIcon: Icons.vpn_key_rounded,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchByCode(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton.primary(
            'بحث عن السنتر',
            loading: _searching,
            onPressed: _searching ? null : _searchByCode,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_foundCenter != null)
            _CenterResultCard(center: _foundCenter!)
          else if (_notFound)
            const _CenterNotFoundCard()
          else if (_errorMessage != null)
            _CenterErrorCard(message: _errorMessage!),
        ],
      ),
    );
  }
}

class _CenterResultCard extends StatelessWidget {
  const _CenterResultCard({required this.center});

  final CenterModel center;

  @override
  Widget build(BuildContext context) {
    final color = parseCenterColor(center.primaryColor);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color,
                child: Text(
                  center.initial,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.palette.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center.name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'كود: ${center.code}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: context.palette.warning,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          center.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.people_alt_rounded,
                          size: 14,
                          color: context.palette.textTertiary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${center.studentsCount} طالب',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          JoinCenterButton(center: center),
        ],
      ),
    );
  }
}

class _CenterNotFoundCard extends StatelessWidget {
  const _CenterNotFoundCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 32,
            color: context.palette.error,
          ),
          const SizedBox(height: 10),
          Text(
            'مفيش سنتر بالكود ده',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.palette.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'تأكد من الكود وجرب تاني',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CenterErrorCard extends StatelessWidget {
  const _CenterErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 32, color: context.palette.error),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.palette.error,
            ),
          ),
        ],
      ),
    );
  }
}
