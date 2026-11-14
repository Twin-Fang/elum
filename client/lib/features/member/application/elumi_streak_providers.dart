import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/elumi_streak.dart';
import 'member_providers.dart';

/// 지금 고른 이룸이의 연속 기록 (보호자 홈 불꽃 · 이룸이 홈 별 줄 공통)
/// 회원 정보를 못 받았거나 받는 중이면 0일 (숨김)
final elumiStreakProvider = Provider<ElumiStreak>((ref) {
  return ref.watch(memberProvider.select((member) => member.value?.streak ?? ElumiStreak.none));
});
