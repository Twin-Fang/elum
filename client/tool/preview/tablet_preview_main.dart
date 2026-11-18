// 로그인·서버 없이 실제 앱(라우터·화면)을 데모 데이터로 띄우는 미리보기 진입점
//
// 시뮬레이터·에뮬레이터에서 태블릿 레이아웃을 확인하거나 스토어 스크린샷을 찍을 때 쓴다.
// 소셜 로그인은 자동화할 수 없고 서버 토큰은 만료되므로, 저장소·토큰·일과 목록을 메모리 데이터로 바꿔 끼운다.
// 앱 번들에 들어가지 않는다 (lib 밖).
//
// 실행: flutter run -t tool/preview/tablet_preview_main.dart -d <기기> --dart-define=PREVIEW_ROLE=child|guardian --dart-define=PREVIEW_LANGUAGE=ko|en|ja|zh|es [--dart-define=PREVIEW_FIRST_RUN=true]
import 'package:dio/dio.dart';
import 'package:elum/app.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/config/app_config.dart';
import 'package:elum/core/layout/orientation_policy.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/ads/application/ad_gate.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/domain/guide_tip.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_dio.dart';
import 'preview_demo_data.dart';
import 'package:elum/features/notification/data/push_messaging_client.dart';
import 'package:elum/features/notification/domain/push_message.dart';
import 'package:elum/features/notification/domain/push_permission_status.dart';

/// 데모 문구 언어: ko·en·ja·zh·es (기기 언어도 같은 언어로 맞춰 찍음, #1419)
const _previewLanguage = String.fromEnvironment(
  'PREVIEW_LANGUAGE',
  defaultValue: 'ko',
);

/// 홈 첫 진입 흐름(알림 안내 > 코치마크 · 가이드 팁)을 그대로 보기: true 면 미리 닫지 않음 (#1455)
const _isFirstRunPreview = bool.fromEnvironment('PREVIEW_FIRST_RUN');

/// 어느 화면으로 시작할지: child(이룸이 기기) | guardian(보호자 홈) | login(로그인 전) | onboarding(로그인 뒤 가입 절차)
const _previewRole = String.fromEnvironment(
  'PREVIEW_ROLE',
  defaultValue: 'child',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OrientationPolicy.apply();
  await AppConfig.load();

  final demo = toPreviewDemoData(_previewLanguage);
  final isChild = _previewRole == 'child';
  final isSignedIn = _previewRole != 'login';
  final isOnboarded = _previewRole == 'child' || _previewRole == 'guardian';
  final storage = InMemoryStorage(
    onboardingCompleted: isOnboarded,
    nickname: isOnboarded ? demo.nickname : null,
    character: isOnboarded ? 'cat' : null,
    pin: isOnboarded ? '1234' : null,
    elumiDevice: isChild,
  );
  if (_previewRole == 'guardian') await storage.setSelectedRole('guardian');
  // 스토어 스크린샷: 가이드 팁·알림 켜기 안내·코치마크를 미리 닫아 둠 (첫 진입 미리보기는 그대로)
  if (!_isFirstRunPreview) {
    await storage.setDismissedGuideTipSlugs([
      for (final tip in GuideTip.values) tip.slug,
    ]);
    await storage.setPushPermissionIntroSeen(true);
    await storage.setHomeCoachSeen(true);
  } else {
    // 메모리 저장소 기본값은 코치마크 봤음 > 첫 진입 미리보기는 안 봤음으로
    await storage.setHomeCoachSeen(false);
  }

  final tokens = isSignedIn
      ? InMemoryTokenStore(
          accessToken: 'preview-access',
          refreshToken: 'preview-refresh',
        )
      : InMemoryTokenStore();
  final dio = Dio(BaseOptions(baseUrl: 'https://preview.local'))
    // 진행률 저장은 성공으로 둔다 (404 면 "일과가 사라졌다"로 보고 홈으로 돌아간다)
    ..httpClientAdapter = FakeAdapter({
      for (final routine in demo.routines)
        'PUT /api/routines/${routine.id}/progress': const <String, Object?>{},
    });

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        // 스토어 스크린샷에 광고가 찍히지 않게 끔
        adsEnabledProvider.overrideWithValue(false),
        tokenStoreProvider.overrideWithValue(tokens),
        dioProvider.overrideWithValue(dio),
        myRoutinesProvider.overrideWith((ref) async => demo.routines),
        todayRoutinesProvider.overrideWith((ref) async => demo.routines),
        pastRoutinesProvider.overrideWith((ref) async => const []),
        memberProvider.overrideWith(
          (ref) async => Member(nickname: demo.nickname, totalStars: 15),
        ),
        // Firebase 없이 뜨므로 알림 권한은 가짜: 첫 진입 미리보기는 아직 안 물음 (알림 안내가 뜨게)
        if (_isFirstRunPreview)
          pushMessagingClientProvider.overrideWithValue(
            _PreviewPushMessagingClient(),
          ),
      ],
      child: const ElumApp(),
    ),
  );
}

/// 미리보기 알림: 권한은 아직 안 물음, 요청하면 허용, 토큰·메시지 없음
class _PreviewPushMessagingClient implements PushMessagingClient {
  PushPermissionStatus _status = PushPermissionStatus.notDetermined;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Future<PushPermissionStatus> permissionStatus() async => _status;

  @override
  Future<bool> requestPermission() async {
    _status = PushPermissionStatus.granted;
    return true;
  }

  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();

  @override
  Stream<PushMessage> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<PushMessage?> getInitialMessage() async => null;

  @override
  Future<void> disableSystemForegroundPresentation() async {}
}
