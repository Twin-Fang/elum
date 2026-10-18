import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/app_status/app_status_repository.dart';
import '../../../core/theme/theme_context_ext.dart';

/// 우측 상단 구석의 앱 버전 (`v1.44.0`). **개발 쪽 임시안이다**.
///
/// 로그인하지 못한 사용자는 설정 화면에 갈 수 없어, 제보할 때 어느 빌드인지
/// 확인할 방법이 여기뿐이다. 사용자가 의식할 필요는 없어 **거의 안 보일 만큼
/// 작고 옅게** 둔다.
///
/// 자리를 우측 상단으로 고른 이유 — 두 배치 모두 문구가 y=104 아래에서 시작해
/// 상단이 비어 있다. 아래쪽은 병아리 그림·버튼·`최근 로그인` 알약이 차 있어
/// 작은 글자가 묻히고, 버튼 묶음 여백(85)을 건드리면 누르는 자리가 흔들린다.
///
/// 버전을 못 읽으면 아무것도 그리지 않는다. 사용자가 할 수 있는 일이 없다.
class LoginVersionCorner extends ConsumerWidget {
  const LoginVersionCorner({super.key});

  /// 상태바 아래로 4, 오른쪽에서 16 — 제공자 버튼 좌우 여백과 맞춘다.
  static const _top = 4.0;
  static const _right = 16.0;

  /// 글자 크기는 `appVersionTag`(10) 토큰에 있다. 알고 찾아야 보이는 정도로 옅게 둔다.
  static const _opacity = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref
        .watch(appVersionProvider)
        .maybeWhen(data: (value) => value, orElse: () => '');
    if (version.isEmpty) return const SizedBox.shrink();

    return Positioned(
      // 노치·다이내믹 아일랜드 아래로 내린다. 상태바 안에 두면 시계와 겹친다.
      top: MediaQuery.paddingOf(context).top + _top.h,
      right: _right.w,
      child: Text(
        'v$version',
        style: context.typo.appVersionTag.copyWith(
          color: context.colors.textPlaceholder.withValues(alpha: _opacity),
        ),
      ),
    );
  }
}
