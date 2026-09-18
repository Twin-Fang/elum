import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/app_role.dart';
import 'widgets/role_card.dart';

/// 역할 선택 (이슈 #212 · 명세 §4-3).
///
/// 약관 동의 뒤, 보호자와 이룸이가 갈라지는 지점이다. 로그인·약관은 이룸이도
/// 똑같이 거친다 — 약관 동의는 법적 요건이라 예외가 없다.
///
/// ## 뒤로가기를 두지 않는다
///
/// 여기가 첫 갈림길이라 돌아갈 화면이 없다. 잘못 골랐을 때의 복귀는
/// **연결 암호 넣기 화면의 `←`**다 (명세 §5-2). 그래서 이룸이 쪽은 `push`로
/// 띄운다 — `go`로 갈아끼우면 스택이 없어 `pop`이 실패한다 (이슈 #194와 같은 함정).
///
/// ## `isElumiDevice`를 여기서 세우지 않는다
///
/// 세션이 없을 때 이룸이 휴대폰을 연결 화면으로 보내는 라우터 가드(이슈 #206)가
/// 곧바로 다시 잡아가 **뒤로가기가 막힌다.** 그 값은 연결에 성공한 순간에만 선다.
class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  /// 카드 사이 간격 18 — 온보딩 목표 칩과 같은 리듬.
  static const _cardGap = 18.0;

  Future<void> _pick(BuildContext context, WidgetRef ref, AppRole role) async {
    // 저장이 실패해도 화면을 멈추지 않는다. 다음에 다시 물으면 될 뿐이다.
    try {
      await ref.read(localStorageProvider).setSelectedRole(role.storageValue);
    } catch (e) {
      debugPrint('역할 저장 실패: $e');
    }
    if (!context.mounted) return;

    switch (role) {
      case AppRole.guardian:
        context.go(Routes.onboardingName);
      case AppRole.elumi:
        // push — 연결 암호 넣기에서 뒤로 누르면 이 화면으로 돌아와야 한다
        context.push(Routes.linkEnter);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElumScaffold(
      // 뒤로가기 없음 (명세 §4-3)
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ElumHeader(
              title: '서비스를\n누가 사용하나요?',
              // 되돌릴 수 있다는 것을 **고르기 전에** 말한다
              description: '나중에 바꿀 수 있어요',
            ),
            SizedBox(height: context.space.headerToContent),
            for (final role in AppRole.values) ...[
              AppPressable(
                onTap: () => _pick(context, ref, role),
                child: RoleCard(role: role),
              ),
              if (role != AppRole.values.last) SizedBox(height: _cardGap.h),
            ],
          ],
        ),
      ),
    );
  }
}
