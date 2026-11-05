import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/image_style.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../../subscription/domain/plan_benefit.dart';
import 'member_providers.dart';
import 'plan_access.dart';

/// 그림 방식 고르기 공통 (#1149): 온보딩 · 보호자 설정 · 이룸이 정보 시트가 같은 규칙
/// Pro 방식(캐릭터·사진 같은 그림)은 AI 맞춤 그림 권한이 있어야 고름, 없으면 요금제 화면으로

/// 화면에 보일 방식: 살 수 없고 권한도 없으면 Pro 방식 숨김
/// 저장값([saved])과 화면에서 고른 값([picked])은 늘 보임 — 다른 걸 눌러 봐도 저장값으로 되돌릴 수 있게
List<ImageStyle> visibleImageStyles(
  PlanAccess access, {
  required ImageStyle saved,
  required ImageStyle picked,
}) => [
  for (final style in ImageStyle.values)
    if (!isImageStyleLocked(style, access) || access.canPurchasePro || style == saved || style == picked)
      style,
];

/// 잠긴 방식인가 (Pro 배지 표시): Pro 방식 + AI 맞춤 그림 권한 없음
bool isImageStyleLocked(ImageStyle style, PlanAccess access) =>
    style.isProOnly && !access.canUseAiPictures;

/// 누른 방식 > 실제로 고를 값 (null 이면 고른 값 그대로)
///
/// 잠긴 방식: 요금제 화면(그림 혜택 맨 위) > 닫힌 뒤 새 권한으로 다시 판정 > Pro 가 됐으면 누른 방식
/// 결제 없이 닫으면 null (팝업 없음)
Future<ImageStyle?> chooseImageStyle(BuildContext context, WidgetRef ref, ImageStyle tapped) async {
  if (!isImageStyleLocked(tapped, ref.read(planAccessProvider))) return tapped;
  await openPlanPaywall(context, ref, highlight: PlanBenefit.aiImageStyles);
  if (!context.mounted) return null;
  // 결제 직후 회원 정보를 다시 받는 중이면 끝날 때까지 기다림 (옛 Free 판정으로 거절하지 않게)
  try {
    await ref.read(memberProvider.future);
  } catch (error) {
    // 회원 조회 실패는 지금 판정 그대로 (고른 값 유지) — 실패 표시는 회원 화면 몫
    debugPrint('[image style] member refresh failed after paywall : $error');
  }
  if (!context.mounted) return null;
  return isImageStyleLocked(tapped, ref.read(planAccessProvider)) ? null : tapped;
}
