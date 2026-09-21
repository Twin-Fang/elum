import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';
import 'elum_button.dart';

/// 실패를 실패로 보여주는 공통 화면.
///
/// **왜 한 벌로 묶었나.** 예전에는 무엇이 망가져도 돌아가는 것처럼 보이게 했다 —
/// 목록을 못 불러오면 빈 목록을, 추천을 못 받으면 내장 데이터를 대신 보여줬다.
/// 그러면 "아직 만든 게 없다"와 "불러오지 못했다"가 같은 화면이 되어, 보호자는
/// 무엇이 잘못됐는지 알 수 없고 우리도 제보를 받아 추적할 수 없다.
///
/// 이제는 실패하면 실패라고 말한다. 다만 화면마다 제각각으로 말하면 그 자체가
/// 또 다른 혼란이라, 표현을 여기 한 곳에 모은다.
///
/// **[errorCode]는 되도록 넘긴다.** 사용자에게는 부차적이지만, 제보를 받았을 때
/// 어디서 터졌는지 아는 유일한 단서다 (docs 예외처리 규칙).
class ElumErrorView extends StatelessWidget {
  const ElumErrorView({
    super.key,
    required this.message,
    this.description,
    this.errorCode,
    this.onRetry,
    this.compact = false,
  });

  /// 무엇을 못 했는지. 해요체·긍정형으로 쓴다 (예: '일과를 불러오지 못했어요').
  final String message;

  /// 다음에 무엇을 하면 되는지. 비우면 기본 문구를 쓴다.
  final String? description;

  /// 추적용 식별자 (예: 'E-RT-001').
  final String? errorCode;

  /// null이면 버튼을 숨긴다 — 다시 눌러도 소용없는 실패에는 버튼을 두지 않는다.
  final VoidCallback? onRetry;

  /// 화면 일부만 실패했을 때 쓰는 축소 모드.
  ///
  /// 홈처럼 여러 구역이 있는 화면에서 한 구역이 실패했다고 화면 전체를 덮으면,
  /// 멀쩡한 나머지까지 쓸 수 없게 된다. 그래서 실패한 자리에만 작게 놓는다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;

    // 좁은 자리(목록 한 칸, 띠 한 줄)에 들어가야 하므로 최소한으로 줄인다.
    // 전체 화면과 같은 구성을 넣으면 넘쳐서 잘린다 — 실제로 홈 목록 자리에서
    // 136px이 잘렸다.
    if (compact) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: typo.promptBody.copyWith(color: colors.textPrimary),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  errorCode == null ? '다시 시도' : '다시 시도 ($errorCode)',
                  style: typo.promptBody.copyWith(color: colors.promptMuted),
                ),
              )
            else if (errorCode != null)
              Text(
                errorCode!,
                style: typo.promptBody.copyWith(color: colors.promptMuted),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            AppAssets.lumiThinking,
            width: 100.w,
            height: 100.w,
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
            description ?? '잠시 후 다시 해주세요',
            textAlign: TextAlign.center,
            style: typo.promptBody.copyWith(color: colors.promptMuted),
          ),
          if (onRetry != null) ...[
            SizedBox(height: space.lg),
            ElumButton(label: '다시 시도', onPressed: onRetry),
          ],
          if (errorCode != null) ...[
            SizedBox(height: space.md),
            // 추적용 식별자 — 제보 시 원인을 짚는 유일한 단서다.
            Text(
              errorCode!,
              style: typo.promptBody.copyWith(color: colors.promptMuted),
            ),
          ],
        ],
      ),
    );
  }
}
