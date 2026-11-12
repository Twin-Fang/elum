import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/elum_guide_panel.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../domain/credit_summary.dart';
import '../presentation/credit_cost_guide.dart';

/// 크레딧 안내 창 열기 (내 크레딧 카드 제목 옆 물음표): `Pro 알아보기` 를 고르면 창을 닫고 요금제 화면
///
/// 다른 기능이 credit 의 presentation 을 직접 알지 않게 하는 입구 (tool/check_layer_imports.dart)
Future<void> showCreditCostGuide(BuildContext context, WidgetRef ref, CreditSummary summary) async {
  final choice = await showElumGuideDialog<CreditCostGuideChoice>(
    context: context,
    barrierDismissible: true,
    builder: (_) => CreditCostGuide(summary: summary),
  );
  if (choice == CreditCostGuideChoice.learnPro && context.mounted) await openPlanPaywall(context, ref);
}
