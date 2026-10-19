import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';

import 'test_storage.dart';

/// 이룸이 화면 테스트용 데모 일과 (카드 4장·보상 있음, 카드 3장, 카드 2장)
final childDemoRoutines = <Routine>[
  Routine(
    id: 'r1',
    title: '아침에 학교 갈 준비',
    status: 'CONFIRMED',
    rewardText: '젤리 먹기',
    progressPercent: 25,
    completedStepCount: 1,
    totalStepCount: 4,
    steps: const [
      ActionCard(id: 'r1c1', stepOrder: 1, title: '세수해요', description: '물로 얼굴을 깨끗이 씻어요', pictogramId: 'wash_face_,_to'),
      ActionCard(id: 'r1c2', stepOrder: 2, title: '옷을 입어요', description: '학교에 갈 옷을 차례대로 입어요', pictogramId: 'put_on_coat_,_to'),
      ActionCard(id: 'r1c3', stepOrder: 3, title: '가방을 챙겨요', description: '책과 필통을 가방에 넣어요', pictogramId: 'school_bag'),
      ActionCard(id: 'r1c4', stepOrder: 4, title: '신발을 신어요', description: '현관에서 신발을 신어요', pictogramId: 'shoe_-_mans'),
    ],
  ),
  Routine(
    id: 'r2',
    title: '저녁 먹기 전 손 씻기',
    status: 'CONFIRMED',
    totalStepCount: 3,
    steps: const [
      ActionCard(id: 'r2c1', stepOrder: 1, title: '손을 적셔요', description: '물을 틀고 손을 적셔요', pictogramId: 'wash_hands_,_to'),
      ActionCard(id: 'r2c2', stepOrder: 2, title: '비누칠을 해요', description: '손바닥과 손등을 비벼요', pictogramId: 'soap'),
      ActionCard(id: 'r2c3', stepOrder: 3, title: '헹구고 닦아요', description: '물로 헹구고 수건으로 닦아요', pictogramId: 'towel'),
    ],
  ),
  Routine(
    id: 'r3',
    title: '잠자기 전 정리',
    status: 'CONFIRMED',
    totalStepCount: 2,
    steps: const [
      ActionCard(id: 'r3c1', stepOrder: 1, title: '이를 닦아요', description: '칫솔로 이를 구석구석 닦아요', pictogramId: 'brush_teeth_,_to'),
      ActionCard(id: 'r3c2', stepOrder: 2, title: '불을 꺼요', description: '잘 자요, 불을 꺼요', pictogramId: 'turn_off_,_to'),
    ],
  ),
];

/// 이룸이 화면이 서버 없이 데모 일과·별 15개로 뜨게 하는 provider override
// ignore: strict_top_level_inference
childDemoOverrides({bool isElumiDevice = true}) => [
  testStorageOverride(
    onboardingCompleted: true,
    nickname: '하늘이',
    elumiDevice: isElumiDevice,
  ),
  todayRoutinesProvider.overrideWith((ref) async => childDemoRoutines),
  myRoutinesProvider.overrideWith((ref) async => childDemoRoutines),
  pastRoutinesProvider.overrideWith((ref) async => const []),
  memberProvider.overrideWith(
    (ref) async => Member(nickname: '하늘이', totalStars: 15),
  ),
];
