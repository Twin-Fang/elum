import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../data/auth_repository.dart';
import '../data/consent_repository.dart';
import '../domain/consent_documents.dart';
import 'consent_document_screen.dart';
import 'widgets/consent_chip.dart';

/// 약관 동의 화면. 로그인 직후, 아이 정보를 받기 전에 선다.
///
/// Figma에 이 화면은 없다(신규). 그래서 **온보딩 목표 선택(`204:1002`) 규격을
/// 그대로 따른다** — 같은 "여러 개 고르기"이고 같은 흐름 안에 있기 때문이다.
/// 칩 344×68 r20, 간격 18, 제목 y=131, 설명 y=211, 콘텐츠 y=279.
///
/// **항목을 하나로 뭉치지 않는다.** 개인정보보호법은 필수와 선택을 나누어 받도록
/// 하며, 뭉쳐 받은 동의는 무효가 될 수 있다.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  /// 칩 간격 18 — Figma 칩 y좌표 차(86)에서 칩 높이(68)를 뺀 값 (목표 화면과 동일)
  static const _chipGap = 18.0;

  final _checked = <String>{};

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _allRequiredChecked => consentItems
      .where((item) => item.required)
      .every((item) => _checked.contains(item.key));

  /// 일괄 동의는 **필수 항목만** 다룬다 (이슈 #189).
  ///
  /// 선택 항목(광고성 정보 수신)은 화면 높이에 따라 접혀서 안 보일 수 있다. 일괄
  /// 동의가 거기까지 켜면, 사용자는 **무엇에 동의했는지 본 적도 없이** 동의하게 된다.
  /// 실제로 필수 4개까지만 보이는 화면에서 이 버튼을 누르면 마케팅 동의가 함께 켜졌다.
  ///
  /// 선택 항목은 눈으로 보고 직접 누르게 둔다. 한 번 더 누르는 비용보다
  /// 모르고 동의하는 비용이 크다.
  void _toggleAllRequired() {
    setState(() {
      if (_allRequiredChecked) {
        _checked.removeAll(_requiredKeys);
      } else {
        _checked.addAll(_requiredKeys);
      }
    });
  }

  Iterable<String> get _requiredKeys =>
      consentItems.where((item) => item.required).map((item) => item.key);

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final saved = await ref.read(consentRepositoryProvider).agree(
          marketingAgreed: _checked.contains('marketingAgreed'),
        );

    if (!mounted) return;

    if (!saved) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = '동의를 저장하지 못했어요. 다시 해주세요 (E-CONSENT)';
      });
      return;
    }

    // 동의를 마쳤으니 이제 누가 쓰는 휴대폰인지 묻는다 (이슈 #212).
    // 보호자인지 이룸이인지에 따라 다음 화면이 갈린다 — 여기서 바로 이름을
    // 물으면 이룸이 휴대폰이 보호자 온보딩으로 빨려 들어간다.
    context.go(Routes.roleSelect);
  }

  /// 동의하지 않고 나간다. 서비스를 쓸 수 없으므로 로그아웃 상태로 되돌린다.
  ///
  /// 토큰만 남겨두면 다음 실행에서 동의 화면을 건너뛰고 들어올 수 있어
  /// 동의 없이 서비스가 열린다.
  Future<void> _leave() async {
    await ref.read(authRepositoryProvider).logout();
    if (!mounted) return;
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return PopScope(
      // 뒤로가기로 빠져나가면 동의 없이 화면이 열린다. 나가려면 로그아웃이어야 한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ElumScaffold(
        bottomButton: ElumButton(
          label: _isSubmitting ? '저장하고 있어요' : '동의하고 시작하기',
          onPressed: _allRequiredChecked && !_isSubmitting ? _submit : null,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ElumHeader(
                title: '시작하기 전에\n확인해주세요',
                description: '항목을 누르면 전문을 볼 수 있어요',
              ),
              SizedBox(height: space.headerToContent.h),

              _AllAgreeRow(
                checked: _allRequiredChecked,
                onTap: _toggleAllRequired,
              ),
              SizedBox(height: space.sm.h),

              for (final item in consentItems) ...[
                ConsentChip(
                  item: item,
                  isChecked: _checked.contains(item.key),
                  onToggle: () => setState(() {
                    if (!_checked.remove(item.key)) _checked.add(item.key);
                  }),
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConsentDocumentScreen(item: item),
                    ),
                  ),
                ),
                SizedBox(height: _chipGap.h),
              ],

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: context.typo.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: space.sm.h),
              ],

              Center(
                child: AppPressable(
                  onTap: _leave,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: space.xs.h),
                    child: Text(
                      '다른 계정으로 로그인',
                      style: context.typo.caption.copyWith(
                        color: context.colors.textSecondary,
                        decoration: TextDecoration.underline,
                        decorationColor: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전체 동의. 칩이 아니라 한 줄로 둔다 — 항목과 같은 무게로 보이면
/// 다섯 개 중 하나처럼 읽혀 "전부"라는 뜻이 흐려진다.
class _AllAgreeRow extends StatelessWidget {
  const _AllAgreeRow({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      child: Padding(
        // 칩 내부 좌측 여백과 맞춰 체크가 아래 항목들과 세로로 정렬되게 한다
        padding: EdgeInsets.symmetric(
          horizontal: ConsentChip.markLeft.w,
          vertical: space.sm.h,
        ),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_circle : Icons.check_circle_outline,
              size: space.checkSize.w,
              color: checked ? colors.consentSelectedBorder : colors.border,
            ),
            SizedBox(width: space.sm.w),
            Expanded(
              // "모두"라고만 쓰면 선택 항목까지 켜지는 줄 안다. 무엇을 켜는지 적는다.
              child: Text('필수 항목에 모두 동의해요',
                  style: context.typo.subtitle),
            ),
          ],
        ),
      ),
    );
  }
}
