import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../data/auth_repository.dart';
import '../data/consent_repository.dart';
import '../domain/consent_documents.dart';
import 'consent_document_screen.dart';
import 'widgets/consent_all_agree_button.dart';
import 'widgets/consent_row.dart';

/// 약관 동의 화면. 로그인 직후, 이룸이 정보를 받기 전에 선다.
///
/// Figma `739:3747`(미동의) · `726:5056`(전체 동의) — 같은 화면의 두 상태다 (이슈 #226).
/// 전체 동의 버튼 344×68 y=223, 항목 344×50 y=308부터 58 간격, CTA y=675.
///
/// **항목을 하나로 뭉치지 않는다.** 개인정보보호법은 필수와 선택을 나누어 받도록
/// 하며, 뭉쳐 받은 동의는 무효가 될 수 있다.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  /// 부제 하단(193) → 전체 동의 버튼(223). ElumHeader가 제목·부제를 y=131·177에
  /// 세우므로 여기서 남은 30만 띄운다. `headerToContent`(52)를 쓰면 22가 밀린다.
  static const _headerToAllAgree = 30.0;

  /// 전체 동의 버튼 하단(291) → 첫 항목(308)
  static const _allAgreeToItems = 17.0;

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
          label: _isSubmitting ? '저장하고 있어요' : '다음',
          onPressed: _allRequiredChecked && !_isSubmitting ? _submit : null,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElumHeader(
                title: '약관에 동의해주세요',
                // 부제가 상태를 말한다. 왜 `다음`이 꺼져 있는지 여기서만 알 수 있다 —
                // 고정 문구로 두면 비활성 버튼 앞에서 막힌 사람이 이유를 모른다.
                description: _allRequiredChecked
                    ? '항목을 눌러 상세 내용을 볼 수 있어요'
                    : '서비스 사용을 위해 약관 동의가 필요해요',
              ),
              SizedBox(height: _headerToAllAgree.h),

              ConsentAllAgreeButton(
                checked: _allRequiredChecked,
                onTap: _toggleAllRequired,
              ),
              SizedBox(height: _allAgreeToItems.h),

              for (final item in consentItems) ...[
                ConsentRow(
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
                SizedBox(height: ConsentRow.gap.h),
              ],

              // 디자인에 에러 자리가 없다. 항목 아래 빈 공간(항목 끝 590 → CTA 675)에
              // 둔다 — CTA를 밀지 않고, 실패했을 때만 나타난다.
              if (_errorMessage != null) ...[
                SizedBox(height: space.sm.h),
                Text(
                  _errorMessage!,
                  style: context.typo.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
