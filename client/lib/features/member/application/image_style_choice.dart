import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/image_style.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../../subscription/domain/plan_benefit.dart';
import 'member_providers.dart';
import 'plan_access.dart';

/// 그림 방식 고르기 공통 (#1149): 온보딩 · 보호자 설정 · 이룸이 정보 시트가 같은 규칙
/// 네 방식은 늘 보임 (#1286). Pro 방식(만화·사진 같은 그림)은 AI 맞춤 그림 권한이 있어야 고름, 없으면 잠금 > 요금제 화면

/// 잠긴 방식인가 (Pro 배지 표시): Pro 방식 + AI 맞춤 그림 권한 없음
bool isImageStyleLocked(ImageStyle style, PlanAccess access) =>
    style.isProOnly && !access.canUseAiPictures;

/// 누른 방식 > 실제로 고를 값 (null 이면 고른 값 그대로)
///
/// 잠긴 방식: 요금제 화면(그림 혜택 맨 위, 판매 중이 아니면 Pro 안내 팝업) > 닫힌 뒤 새 권한으로 다시 판정 > Pro 가 됐으면 누른 방식
/// 결제 없이 닫으면 null
Future<ImageStyle?> chooseImageStyle(BuildContext context, WidgetRef ref, ImageStyle tapped) async {
  if (!isImageStyleLocked(tapped, ref.read(planAccessProvider))) return tapped;
  await openProOnlyNotice(context, ref, benefit: PlanBenefit.aiImageStyles);
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
