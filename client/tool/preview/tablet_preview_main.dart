// 로그인·서버 없이 실제 앱(라우터·화면)을 데모 데이터로 띄우는 미리보기 진입점
//
// 시뮬레이터·에뮬레이터에서 태블릿 레이아웃을 확인하거나 스토어 스크린샷을 찍을 때 쓴다.
// 소셜 로그인은 자동화할 수 없고 서버 토큰은 만료되므로, 저장소·토큰·일과 목록을 메모리 데이터로 바꿔 끼운다.
// 앱 번들에 들어가지 않는다 (lib 밖).
//
// 실행: flutter run -t tool/preview/tablet_preview_main.dart -d <기기> --dart-define=PREVIEW_ROLE=child|guardian
import 'package:dio/dio.dart';
import 'package:elum/app.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/config/app_config.dart';
import 'package:elum/core/layout/orientation_policy.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fake_dio.dart';

/// 어느 화면으로 시작할지: child(이룸이 기기) | guardian(보호자 홈) | login(로그인 전) | onboarding(로그인 뒤 가입 절차)
const _previewRole = String.fromEnvironment(
  'PREVIEW_ROLE',
  defaultValue: 'child',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OrientationPolicy.apply();
  await AppConfig.load();

  final isChild = _previewRole == 'child';
  final isSignedIn = _previewRole != 'login';
  final isOnboarded = _previewRole == 'child' || _previewRole == 'guardian';
  final storage = InMemoryStorage(
    onboardingCompleted: isOnboarded,
    nickname: isOnboarded ? '하늘이' : null,
    character: isOnboarded ? 'cat' : null,
    pin: isOnboarded ? '1234' : null,
    elumiDevice: isChild,
  );
  if (_previewRole == 'guardian') await storage.setSelectedRole('guardian');

  final tokens = isSignedIn
      ? InMemoryTokenStore(
          accessToken: 'preview-access',
          refreshToken: 'preview-refresh',
        )
      : InMemoryTokenStore();
  final dio = Dio(BaseOptions(baseUrl: 'https://preview.local'))
    // 진행률 저장은 성공으로 둔다 (404 면 "일과가 사라졌다"로 보고 홈으로 돌아간다)
    ..httpClientAdapter = FakeAdapter({
      for (final routine in _demoRoutines)
        'PUT /api/routines/${routine.id}/progress': const <String, Object?>{},
    });

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
        dioProvider.overrideWithValue(dio),
        myRoutinesProvider.overrideWith((ref) async => _demoRoutines),
        todayRoutinesProvider.overrideWith((ref) async => _demoRoutines),
        pastRoutinesProvider.overrideWith((ref) async => const []),
        memberProvider.overrideWith(
          (ref) async => Member(nickname: '하늘이', totalStars: 15),
        ),
      ],
      child: const ElumApp(),
    ),
  );
}

ActionCard _card(
  String id,
  int order,
  String title,
  String description,
  String pictogramId,
) => ActionCard(
  id: id,
  stepOrder: order,
  title: title,
  description: description,
  pictogramId: pictogramId,
);

final _demoRoutines = <Routine>[
  Routine(
    id: 'r1',
    title: '아침에 학교 갈 준비',
    status: 'CONFIRMED',
    rewardText: '젤리 먹기',
    rewardPresetKey: 'SNACK',
    progressPercent: 25,
    completedStepCount: 1,
    totalStepCount: 4,
    steps: [
      _card('r1c1', 1, '세수해요', '물로 얼굴을 깨끗이 씻어요', 'wash_face_,_to'),
      _card('r1c2', 2, '옷을 입어요', '학교에 갈 옷을 차례대로 입어요', 'put_on_coat_,_to'),
      _card('r1c3', 3, '가방을 챙겨요', '책과 필통을 가방에 넣어요', 'school_bag'),
      _card('r1c4', 4, '신발을 신어요', '현관에서 신발을 신어요', 'shoe_-_mans'),
    ],
  ),
  Routine(
    id: 'r2',
    title: '저녁 먹기 전 손 씻기',
    status: 'CONFIRMED',
    progressPercent: 0,
    totalStepCount: 3,
    steps: [
      _card('r2c1', 1, '손을 적셔요', '물을 틀고 손을 적셔요', 'wash_hands_,_to'),
      _card('r2c2', 2, '비누칠을 해요', '손바닥과 손등을 비벼요', 'soap'),
      _card('r2c3', 3, '헹구고 닦아요', '물로 헹구고 수건으로 닦아요', 'towel'),
    ],
  ),
  Routine(
    id: 'r3',
    title: '잠자기 전 정리',
    status: 'COMPLETED',
    progressPercent: 100,
    completedStepCount: 2,
    totalStepCount: 2,
    steps: [
      _card('r3c1', 1, '이를 닦아요', '칫솔로 이를 구석구석 닦아요', 'brush_teeth_,_to'),
      _card('r3c2', 2, '불을 꺼요', '잘 자요, 불을 꺼요', 'turn_off_,_to'),
    ],
  ),
];
