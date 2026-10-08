import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_status/app_status_recheck.dart';
import '../core/dev/dev_locale_override.dart';
import '../core/l10n/effective_locale.dart';
import '../core/l10n/region_code.dart';
import '../core/network/accept_language_interceptor.dart';
import '../core/network/app_log_interceptor.dart';
import '../core/network/auth_interceptor.dart';
import '../core/network/dio_client.dart';
import '../core/network/failure_interceptor.dart';
import '../core/network/profile_header_interceptor.dart';
import '../core/network/session_expiry.dart';
import '../core/storage/card_image_disk_cache.dart';
import '../core/storage/local_storage.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/profile/application/profile_session.dart';

/// 앱 전역에서 쓰는 Dio.
///
/// 인증 인터셉터가 붙어 있어 Authorization 헤더와 토큰 재발급이 자동 처리된다.
/// repository는 이 provider를 통해서만 Dio를 받는다 — 각자 `DioClient.create()`를
/// 부르면 인터셉터 없는 인스턴스가 생겨 401이 그대로 터진다.
final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient.create(attachLog: false);

  // 앱 언어를 모든 요청에 싣는다. 요청마다 판정해 OS 언어가 바뀌어도 따라간다.
  // 맨 앞에 둔다 — 토큰 갱신 뒤 요청을 되살릴 때도 같은 헤더로 나간다.
  dio.interceptors.add(
    AcceptLanguageInterceptor(
      locale: () => effectiveAppLocale(
        devOverride: ref.read(devLocaleOverrideProvider),
      ),
      // 지역은 언어 강제와 무관하게 시스템 값을 싣는다 (region_code.dart)
      region: systemRegionCode,
    ),
  );

  // 보호자가 고른 이룸이를 모든 요청에 싣는다. 인증보다 먼저 붙인다 —
  // 토큰 갱신 뒤 요청을 되살릴 때도 같은 헤더로 나간다.
  dio.interceptors.add(
    ProfileHeaderInterceptor(
      profileId: () {
        try {
          final storage = ref.read(localStorageProvider);
          // 이룸이 휴대폰은 연결된 이룸이만 본다. 다른 이룸이를 지정하면 서버가 403 을 준다.
          return storage.isElumiDevice ? null : storage.selectedProfileId;
        } catch (_) {
          // 저장소를 올리지 않은 곳(일부 테스트)은 헤더 없이 — 서버가 첫 이룸이를 쓴다.
          return null;
        }
      },
      // 실패 응답 처리 중에 상태를 바꾸지 않는다 — 다음 마이크로태스크에서 한다.
      onProfileLost: (id) => Future<void>.microtask(() {
        if (ref.mounted) ref.read(profileSessionProvider.notifier).lost(id);
      }),
      onNoProfile: () => Future<void>.microtask(() {
        if (ref.mounted) ref.read(profileSessionProvider.notifier).markNoProfile();
      }),
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      tokens: ref.watch(tokenStoreProvider),
      dio: dio,
      // 갱신은 provider로 받은 **하나의 인스턴스**에 맡긴다.
      // 여기서 매번 new 하면 동시 갱신을 묶는 장치가 인스턴스마다 따로 생겨
      // 무력화된다. 같은 리프레시 토큰이 두 번 나가면 세션이 전부 끊긴다.
      refresh: () => ref.read(tokenRefresherProvider).refreshAccessToken(),
      // 갱신까지 실패하면 세션이 끝난 것이다. 화면이 캐시로 계속 그려지지 않도록
      // 앱 전역에 알린다 — 듣고 있는 쪽이 로그인으로 되돌린다.
      onSessionExpired: () {
        // 세션이 끝났으면 기기에 남은 카드 그림(보호자 사진 포함)도 치운다.
        // 다른 계정이 이어 로그인해도 이전 계정의 그림이 남지 않게 한다. clear 는 throw 하지 않는다.
        unawaited(ref.read(cardImageDiskCacheProvider).clear());
        ref.read(sessionExpiryProvider.notifier).markExpired();
      },
    ),
  );

  // 서버가 점검 중이라 막으면 앱 상태를 다시 묻는다. 이미 앱을 열어 둔 사람도
  // 다음 요청에서 곧바로 점검 화면으로 넘어간다.
  dio.interceptors.add(
    MaintenanceInterceptor(
      onMaintenance: () => ref.read(appStatusRecheckProvider.notifier).request(),
    ),
  );

  // **맨 뒤에 붙인다.** 앞의 인증 인터셉터가 토큰을 갱신해 요청을 되살리면
  // 그건 실패가 아니다 — 먼저 붙이면 되살아날 401 까지 실패로 남는다.
  dio.interceptors.add(const FailureInterceptor());

  // 기록은 그보다도 뒤에 둔다 — 다른 인터셉터가 붙인 헤더와 갱신·실패 해석을 거친
  // 최종 결과를 본다.
  dio.interceptors.add(AppLogInterceptor());

  return dio;
});
