import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_state_body.dart';

/// 일과 만들기 로딩이 실패했을 때의 본문: 그림, 제목, 설명, 에러 코드를 가운데 한 묶음으로
/// 버튼은 여기 두지 않는다 (흐름 화면 공통 스캐폴드의 하단 고정 CTA가 맡는다)
class RoutineFailureBody extends StatelessWidget {
  const RoutineFailureBody({
    super.key,
    required this.message,
    required this.description,
    this.errorCode,
  });

  /// 무엇을 못 했는지 (예: '카드를 만들지 못했어요')
  final String message;

  /// 다음에 무엇을 하면 되는지. 서버 문구 또는 연결 확인 안내
  final String description;

  /// 추적용 식별자. 제보 시 어디서 터졌는지 아는 유일한 단서
  final String? errorCode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;

    return ElumStateBody(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.cardCreationFailedLumi,
              width: 200.w,
              fit: BoxFit.contain,
            ),
            SizedBox(height: space.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: typo.promptTitle.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: space.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: typo.promptBody.copyWith(color: colors.promptMuted),
            ),
            if (errorCode != null) ...[
              SizedBox(height: space.md),
              Text(
                errorCode!,
                style: typo.promptBody.copyWith(color: colors.promptMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
