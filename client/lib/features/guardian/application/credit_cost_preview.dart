import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/image_style.dart';
import '../../credit/application/credit_costs.dart';
import '../../member/application/member_providers.dart';
import '../../member/application/plan_access.dart';

/// 만들기 전 비용 미리 보기: 일과 글 단가 · 카드 그림 한 장 단가(AI 그림을 안 그리면 null) · 지금 남은 크레딧
typedef CreditCostPreview = ({int routineCredits, int? imageCredits, int available});

/// 카드 만들기 버튼 아래 · 카드 추가 시트가 보는 비용 (서버 단가 · 잔액). 크레딧이 꺼졌거나 모르면 null > 줄 숨김
///
/// AI 그림은 그림 방식이 그림을 그리고(캐릭터 · 실사) 요금제가 AI 그림을 줄 때만 (아니면 서버가 그림 기호로 대신함)
final creditCostPreviewProvider = Provider.autoDispose<CreditCostPreview?>((ref) {
  final costs = ref.watch(routineCreateCreditCostsProvider);
  final available = ref.watch(availableCreditsProvider);
  if (costs == null || available == null) return null;
  final imageStyle = ref.watch(memberProvider).value?.imageStyle ?? ImageStyle.character;
  final canUseAiPictures = ref.watch(planAccessProvider.select((access) => access.canUseAiPictures));
  final isDrawingAiPictures = imageStyle.drawsCardImages && canUseAiPictures;
  return (
    routineCredits: costs.routine,
    imageCredits: isDrawingAiPictures ? costs.image : null,
    available: available,
  );
});
