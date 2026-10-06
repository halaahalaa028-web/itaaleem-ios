import 'dart:async';

import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/network/center_deactivated_events.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center/data/datasources/centers_remote_data_source.dart';
import 'package:itaaleem/features/center/data/dummy/center_dummy_data.dart';
import 'package:itaaleem/features/center/data/models/center_json_mapper.dart';
import 'package:itaaleem/features/center/domain/entities/center_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _centerIdKey = 'joined_center_id';
const _gradeIdKey = 'joined_grade_id';

/// Real (non-demo) session equivalent of the demo keys above — written the
/// moment `join()` below succeeds, independently of whatever `GET /profile`
/// returns, and read back in `build()` if `/profile`'s response doesn't
/// carry a center/grade for some reason (an unrecognized response shape, a
/// stale cache, …). A real session's *primary* source of truth is still
/// `Student.centerId`/`gradeId` from `/profile` — this is only the local
/// fallback for when that hasn't caught up yet.
const _realCenterIdKey = 'real_joined_center_id';
const _realGradeIdKey = 'real_joined_grade_id';

/// The center + grade a student has joined.
class CenterMembership {
  const CenterMembership({required this.centerId, this.gradeId});

  final int centerId;
  final int? gradeId;
}

/// Whether the logged-in student has joined a center yet.
///
/// A demo session ([Student.isDemo]) keeps the old local-only behavior
/// (persisted in [SharedPreferences], never touches the network) — a real
/// session derives its initial membership straight from
/// [authControllerProvider]'s [Student.centerId]/[Student.gradeId] (as
/// returned by `/login`, `/register` and `/profile`), and [join]/[leave]
/// call the real `/centers` endpoints, updating this controller's own state
/// directly on success rather than re-fetching the profile.
///
/// [AppRouter] redirects a logged-in student with no membership to
/// `/center-search` until this resolves to non-null.
class CenterMembershipController extends AsyncNotifier<CenterMembership?> {
  @override
  Future<CenterMembership?> build() async {
    // Only the fields the membership derives from — watching the whole
    // Student re-ran this build (prefs writes + an AsyncLoading flash for
    // everything watching membership) on every unrelated profile refresh.
    final (loggedIn, isDemo, profileCenterId, profileGradeId) = ref.watch(
      authControllerProvider.select((s) {
        final student = s.valueOrNull;
        return (
          student != null,
          student?.isDemo ?? false,
          student?.centerId,
          student?.gradeId,
        );
      }),
    );
    if (!loggedIn) return null;

    if (isDemo) {
      final prefs = await SharedPreferences.getInstance();
      final centerId = prefs.getInt(_centerIdKey);
      if (centerId == null) return null;
      return CenterMembership(centerId: centerId, gradeId: prefs.getInt(_gradeIdKey));
    }

    if (profileCenterId == null) {
      // `join()` below sets this controller's state directly, straight
      // from the successful `/join` call, without waiting on a profile
      // refetch. If something later re-triggers this build (e.g. a
      // best-effort `GET /profile` after joining, fired to keep other
      // `Student.centerId` readers in sync) and that response hasn't
      // caught up with the join yet, trust the membership already held
      // here instead of bouncing the student back to the join-by-code
      // screen right after they just joined.
      if (state.valueOrNull != null) {
        if (kDebugMode) {
          debugPrint(
            '[CenterMembership] profile has no center/grade yet — keeping '
            'previously joined membership (centerId=${state.valueOrNull?.centerId}, '
            'gradeId=${state.valueOrNull?.gradeId})',
          );
        }
        return state.valueOrNull;
      }

      // No in-memory state either (e.g. a cold app restart, where this
      // notifier's build() runs for the first time) — fall back to the
      // locally persisted join before concluding the student really has no
      // center, since `/profile` not carrying a center/grade could just
      // mean the response shape wasn't what [StudentModel.fromJson] expects
      // rather than the student genuinely never having joined.
      final prefs = await SharedPreferences.getInstance();
      final cachedCenterId = prefs.getInt(_realCenterIdKey);
      if (kDebugMode) {
        debugPrint(
          '[CenterMembership] profile has no center/grade — cached local '
          'join: centerId=$cachedCenterId gradeId=${prefs.getInt(_realGradeIdKey)}',
        );
      }
      if (cachedCenterId == null) return null;
      return CenterMembership(
        centerId: cachedCenterId,
        gradeId: prefs.getInt(_realGradeIdKey),
      );
    }

    // `/profile` is the source of truth once it does carry a center — keep
    // the local cache in sync so it stays a faithful fallback.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_realCenterIdKey, profileCenterId);
    if (profileGradeId != null) {
      await prefs.setInt(_realGradeIdKey, profileGradeId);
    } else {
      await prefs.remove(_realGradeIdKey);
    }
    return CenterMembership(
      centerId: profileCenterId,
      gradeId: profileGradeId,
    );
  }

  /// Joins (or, called again with a different grade, switches) a center.
  /// [centerId] is kept for local state/membership tracking, but the API
  /// itself resolves the center from [centerCode] — the live backend's
  /// `POST /centers/join` route has no id in the URL and expects `{code,
  /// grade_id?}`. [gradeId] is omitted for centers with no grades to choose
  /// from. Returns `null` on success, or the [Failure] to show if the API
  /// call failed — the caller (e.g. select-grade screen) is responsible for
  /// surfacing it.
  Future<Failure?> join({
    required int centerId,
    required String centerCode,
    int? gradeId,
  }) async {
    final isDemo =
        ref.read(authControllerProvider).valueOrNull?.isDemo ?? false;
    if (isDemo) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_centerIdKey, centerId);
      if (gradeId != null) {
        await prefs.setInt(_gradeIdKey, gradeId);
      } else {
        await prefs.remove(_gradeIdKey);
      }
      state = AsyncData(CenterMembership(centerId: centerId, gradeId: gradeId));
      return null;
    }

    try {
      await ref
          .read(centersRemoteDataSourceProvider)
          .joinCenter(code: centerCode, gradeId: gradeId);
      // Persisted immediately, independently of `/profile` — this is what
      // `build()` falls back to on a cold restart if that response's shape
      // isn't recognized as carrying a center/grade.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_realCenterIdKey, centerId);
      if (gradeId != null) {
        await prefs.setInt(_realGradeIdKey, gradeId);
      } else {
        await prefs.remove(_realGradeIdKey);
      }
      state = AsyncData(CenterMembership(centerId: centerId, gradeId: gradeId));
      // The membership change above already reloads every cached content
      // provider (subjects, lessons, banners, teachers — see `ref.cached`);
      // the profile is refreshed too so a now-active subscription unlocks
      // lessons without restarting the app.
      unawaited(ref.read(authControllerProvider.notifier).refreshProfile());
      return null;
    } on DioException catch (e) {
      return failureOf(e);
    }
  }

  /// Clears the joined center — [AppRouter] reacts by bouncing the student
  /// back to `/center-search` since they no longer have a membership. Same
  /// as [AuthController.logout], the local membership is cleared regardless
  /// of whether the server call itself succeeds.
  Future<void> leave() async {
    final isDemo =
        ref.read(authControllerProvider).valueOrNull?.isDemo ?? false;
    if (isDemo) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_centerIdKey);
      await prefs.remove(_gradeIdKey);
      state = const AsyncData(null);
      return;
    }

    state = const AsyncData(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_realCenterIdKey);
    await prefs.remove(_realGradeIdKey);
    try {
      await ref.read(centersRemoteDataSourceProvider).leaveCenter();
    } on DioException {
      // Already cleared locally above — nothing further to do.
    }
  }

  /// Clears only the local real-session join cache, without calling `POST
  /// /centers/leave` — the student isn't actually leaving the center, just
  /// logging out. Called from [AuthController.logout]/`forceLogout` so a
  /// different student who later logs in on the same device doesn't
  /// briefly inherit this cache before their own `/profile` resolves.
  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_realCenterIdKey);
    await prefs.remove(_realGradeIdKey);
  }
}

final centerMembershipProvider =
    AsyncNotifierProvider<CenterMembershipController, CenterMembership?>(
      CenterMembershipController.new,
    );

/// In-memory cache of centers fetched via [centerByIdProvider], keyed by id
/// — lets that provider stay a plain synchronous `CenterModel?` (matching
/// what every screen that reads it already expects) while still being fed
/// by a real, async `GET /centers/{id}` behind the scenes.
class _CenterCache extends Notifier<Map<int, CenterModel>> {
  @override
  Map<int, CenterModel> build() => {};

  void put(CenterModel center) {
    state = {...state, center.id: center};
  }
}

final _centerCacheProvider =
    NotifierProvider<_CenterCache, Map<int, CenterModel>>(_CenterCache.new);

/// Tracks the last error for a [centerByIdProvider] fetch that's currently
/// failed, keyed by center id — lets dependent screens show a "تعذر
/// التحميل" + retry state instead of [centerByIdProvider] returning `null`
/// forever (which every call site otherwise reads as "still loading").
class _CenterFetchErrors extends Notifier<Map<int, Object>> {
  @override
  Map<int, Object> build() => {};

  void setError(int id, Object error) => state = {...state, id: error};

  void clear(int id) {
    if (!state.containsKey(id)) return;
    state = {...state}..remove(id);
  }
}

final _centerFetchErrorsProvider =
    NotifierProvider<_CenterFetchErrors, Map<int, Object>>(
      _CenterFetchErrors.new,
    );

/// Non-null once [centerByIdProvider]'s `GET /centers/{id}` fetch for this
/// id has failed — screens use this (instead of an indefinite spinner) to
/// show an error state with a retry button wired to [retryCenterFetch].
final centerFetchErrorProvider = Provider.family<Object?, int>((ref, id) {
  return ref.watch(_centerFetchErrorsProvider.select((errors) => errors[id]));
});

/// Clears a fetch failure recorded by [centerFetchErrorProvider] so the next
/// read of [centerByIdProvider] fires the request again.
void retryCenterFetch(WidgetRef ref, int id) {
  ref.read(_centerFetchErrorsProvider.notifier).clear(id);
}

/// Sticky gate [AppRouter] redirects on: `true` once either (a) a 403 from
/// any endpoint has been flagged by [ErrorMappingInterceptor] as meaning the
/// joined center was deactivated server-side, or (b) the joined center's own
/// `GET /centers/{id}` fetch resolved with `is_active: false`. Re-derives
/// from (b) on every rebuild (e.g. after leaving/rejoining a different
/// center), so only (a)'s one-shot event needs sticky `state =` handling.
class CenterDeactivatedController extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(centerDeactivatedStreamProvider, (previous, next) {
      if (next.hasValue) state = true;
    });

    final membership = ref.watch(centerMembershipProvider).valueOrNull;
    if (membership == null) return false;
    final center = ref.watch(centerByIdProvider(membership.centerId));
    return center != null && !center.isActive;
  }
}

final centerDeactivatedProvider =
    NotifierProvider<CenterDeactivatedController, bool>(
      CenterDeactivatedController.new,
    );

/// Looks up a center by id — synchronously `null` while a demo lookup
/// misses, or while a real fetch is still in flight/hasn't been triggered
/// yet; every current call site already treats `null` as "show a loading
/// state" unless [centerFetchErrorProvider] for the same id is non-null, in
/// which case it's a failure, not a loading state.
final centerByIdProvider = Provider.family<CenterModel?, int>((ref, id) {
  final isDemo = ref.watch(isDemoSessionProvider);
  if (isDemo) {
    for (final center in centerDummyData) {
      if (center.id == id) return center;
    }
    return null;
  }

  // `select` so a cache write for another id doesn't rebuild this provider
  // (and re-fire its request).
  final cached = ref.watch(_centerCacheProvider.select((m) => m[id]));
  if (cached != null) return cached;

  // A previous attempt already failed and hasn't been retried — don't
  // keep re-firing the request every time something else causes this
  // provider to rebuild; wait for [retryCenterFetch] to clear it.
  final hasError = ref.watch(
    _centerFetchErrorsProvider.select((errors) => errors.containsKey(id)),
  );
  if (hasError) return null;

  // Cache miss: fire the real fetch once and populate the cache when it
  // resolves, which re-runs this provider (it watches [_centerCacheProvider]
  // above) and returns the loaded center on the next read.
  // Rebuilds while the request is in flight must not fire a second one.
  final inFlight = ref.read(_centerFetchesInFlightProvider);
  if (!inFlight.add(id)) return null;
  final cacheNotifier = ref.read(_centerCacheProvider.notifier);
  final errorsNotifier = ref.read(_centerFetchErrorsProvider.notifier);
  ref
      .read(centersRemoteDataSourceProvider)
      .getCenterDetails(id)
      .timeout(const Duration(seconds: 10))
      .then((center) {
        inFlight.remove(id);
        cacheNotifier.put(center);
      })
      .catchError((Object error) {
        inFlight.remove(id);
        if (kDebugMode) {
          debugPrint('[centerByIdProvider] GET /centers/$id failed: $error');
        }
        errorsNotifier.setError(id, error);
      });
  return null;
});

/// Ids with a `GET /centers/{id}` currently running (see [centerByIdProvider]).
///
/// Owned by the [ProviderContainer] rather than a top-level variable, so it
/// starts empty with every container (app start, tests) instead of living for
/// the whole isolate. Deliberately a plain [Provider] holding a mutable set,
/// not a `StateProvider`: [centerByIdProvider] marks an id in flight while it
/// is building, and Riverpod forbids writing another provider's `state` at
/// that moment. Nothing watches this set, so mutating it needs no
/// notification.
final _centerFetchesInFlightProvider = Provider<Set<int>>((ref) => <int>{});

/// The center the student has joined, for display (name, logo, cover,
/// brand color). Prefers the fetched `GET /centers/{id}` record, but fills
/// any missing logo/cover — and stands in entirely while that fetch is
/// pending or failed — from the `center` object already delivered by
/// `GET /profile`.
final joinedCenterProvider = Provider<CenterModel?>((ref) {
  final membership = ref.watch(centerMembershipProvider).valueOrNull;
  // Rebuild only when the profile's center payload actually changes (compared
  // by content — every refresh parses a fresh map), not on every refresh.
  ref.watch(
    authControllerProvider.select(
      (s) => (s.valueOrNull?.isDemo, s.valueOrNull?.centerJson?.toString()),
    ),
  );
  final student = ref.read(authControllerProvider).valueOrNull;
  final fetched = membership == null
      ? null
      : ref.watch(centerByIdProvider(membership.centerId));

  CenterModel? fromProfile;
  final json = student?.centerJson;
  if (json != null && !(student?.isDemo ?? false)) {
    try {
      fromProfile = centerModelFromJson(json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('>>> HOME profile center parse failed: $e');
      }
    }
  }

  if (fetched == null) {
    // Only trust the profile's center while it matches the joined one.
    if (membership != null && fromProfile != null &&
        fromProfile.id != membership.centerId) {
      return null;
    }
    return fromProfile;
  }
  if (fromProfile == null || fromProfile.id != fetched.id) return fetched;
  return fetched.copyWith(
    logo: (fetched.logo == null || fetched.logo!.isEmpty)
        ? fromProfile.logo
        : null,
    cover: (fetched.cover == null || fetched.cover!.isEmpty)
        ? fromProfile.cover
        : null,
  );
});
