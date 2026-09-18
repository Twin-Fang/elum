import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/app_role.dart';
import 'widgets/role_card.dart';

/// 역할 선택 (Figma `732:5176`·`732:5258` · 이슈 #212 · #229).
///
/// 약관 동의 뒤, 보호자와 이룸이가 갈라지는 지점이다. 로그인·약관은 이룸이도
/// 똑같이 거친다 — 약관 동의는 법적 요건이라 예외가 없다.
///
/// ## 누르면 바로 넘어가지 않는다
///
/// 전에는 카드를 누르는 순간 이동했다. 이제 **고르기와 확정이 나뉜다** —
/// 카드를 누르면 선택만 되고 `다음`을 눌러야 이동한다. 한 번 고르면 온보딩 경로가
/// 갈리는 화면이라, 잘못 눌렀을 때 되돌릴 여지를 둔다 (이슈 #229).
///
/// ## `isElumiDevice`를 여기서 세우지 않는다
///
/// 세션이 없을 때 이룸이 휴대폰을 연결 화면으로 보내는 라우터 가드(이슈 #206)가
/// 곧바로 다시 잡아가 **뒤로가기가 막힌다.** 그 값은 연결에 성공한 순간에만 선다.
class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  /// Figma 카드 y차(391-279=112)에서 카드 높이(96)를 뺀 값
  static const _cardGap = 16.0;

  /// 부제 하단(227) → 첫 카드(279)
  static const _headerToCards = 52.0;

  AppRole? _selected;

  Future<void> _submit() async {
    final role = _selected;
    if (role == null) return;

    // 저장이 실패해도 화면을 멈추지 않는다. 다음에 다시 물으면 될 뿐이다.
    try {
      await ref.read(localStorageProvider).setSelectedRole(role.storageValue);
    } catch (e) {
      debugPrint('역할 저장 실패: $e');
    }
    if (!mounted) return;

    switch (role) {
      // 양쪽 다 push다. 잘못 고른 사람이 **어느 쪽으로 갔든** 뒤로 돌아와야 한다.
      // go로 갈아끼우면 스택이 없어 pop이 실패한다 (이슈 #194와 같은 함정).
      case AppRole.guardian:
        context.push(Routes.onboardingName);
      case AppRole.elumi:
        context.push(Routes.linkEnter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElumScaffold(
      // 약관에서 왔으므로 돌아갈 곳이 있다. 스택이 없으면 버튼을 그리지 않는다.
      onBack: context.canPop() ? context.pop : null,
      bottomButton: ElumButton(
        label: '다음',
        onPressed: _selected != null ? _submit : null,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              // 시안은 `이 기기는`이었다. `기기`만 `휴대폰`으로 바꾼다 —
              // 50대 보호자가 실제로 못 알아듣는 말이라서다 (이슈 #228 합의).
              title: '이 휴대폰은 누가\n사용하나요?',
              // `모드`는 시안 그대로 둔다. 널리 쓰이는 말이고, 시안을 고치면
              // 디자이너와 화면이 어긋나 매번 대조해야 한다 (이슈 #228 합의).
              description: '보호자모드와 이룸이모드가 나눠져 있어요',
              hasBackButton: context.canPop(),
            ),
            SizedBox(height: _headerToCards.h),
            for (final role in AppRole.values) ...[
              AppPressable(
                onTap: () => setState(() => _selected = role),
                child: RoleCard(role: role, selected: _selected == role),
              ),
              if (role != AppRole.values.last) SizedBox(height: _cardGap.h),
            ],
          ],
        ),
      ),
    );
  }
}
