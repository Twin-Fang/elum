import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../shared/models/routine.dart';

/// 인쇄용으로 받기 화면 열기 (일과 상세 시트의 내려받기 버튼 · 세 입구 공통)
void openCardExport(BuildContext context, Routine routine) {
  context.push(Routes.guardianCardExport, extra: routine);
}
