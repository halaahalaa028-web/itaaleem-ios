import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/subscriptions/data/models/subject_subscription_model.dart';
import 'package:itaaleem/features/subscriptions/data/repositories/subscription_repository.dart';

export 'package:itaaleem/features/subscriptions/data/repositories/subscription_repository.dart'
    show subscriptionRepositoryProvider;

/// One subject's subscription status. A demo session (or a logged-out one)
/// never locks anything.
final subjectSubscriptionProvider = FutureProvider.autoDispose
    .family<SubjectSubscriptionStatus, int>((ref, subjectId) async {
      final student = ref.watch(authControllerProvider).valueOrNull;
      if (student == null || student.isDemo) {
        return const SubjectSubscriptionStatus.open();
      }
      // Keep the answer while the app runs — subject cards scroll in and
      // out of view, and the status only changes when an admin acts.
      ref.keepAlive();
      return ref
          .read(subscriptionRepositoryProvider)
          .getSubjectStatus(subjectId);
    });

/// The student's subject subscriptions ("اشتراكاتي").
final mySubscriptionsProvider =
    FutureProvider.autoDispose<List<SubjectSubscription>>((ref) async {
      final student = ref.watch(authControllerProvider).valueOrNull;
      if (student == null || student.isDemo) return const [];
      return ref.read(subscriptionRepositoryProvider).getMySubscriptions();
    });
