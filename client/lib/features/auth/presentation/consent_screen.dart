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

/// 약관 동의 화면. 로그인 직후, 아이 정보를 받기 전에 선다.
///
/// **항목을 하나로 뭉치지 않는다.** 개인정보보호법은 필수와 선택을 나누어 받도록
/// 하며, 뭉쳐 받은 동의는 무효가 될 수 있다. 전체 동의 버튼은 편의를 위해 두되
/// 개별 항목도 그대로 노출한다.
///
/// 전문은 **앱 안에서** 보여준다. 웹으로 보내면 흐름이 끊기고, 네트워크가 없으면
/// 읽을 수조차 없다. 읽을 수 없는 상태에서 받은 동의는 고지로서 성립하지 않는다.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  final _checked = <String, bool>{
    for (final item in consentItems) item.key: false,
  };

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _allRequiredChecked => consentItems
      .where((item) => item.required)
      .every((item) => _checked[item.key] == true);

  bool get _allChecked => _checked.values.every((v) => v);

  void _toggleAll() {
    final next = !_allChecked;
    setState(() {
      for (final key in _checked.keys) {
        _checked[key] = next;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final saved = await ref.read(consentRepositoryProvider).agree(
          marketingAgreed: _checked['marketingAgreed'] == true,
        );

    if (!mounted) return;

    if (!saved) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = '동의를 저장하지 못했어요. 잠시 후 다시 눌러주세요. (E-CONSENT)';
      });
      return;
    }

    // 동의를 마쳤으니 아이 정보를 받을 차례다.
    context.go(Routes.onboardingName);
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
    return PopScope(
      // 뒤로가기로 빠져나가면 동의 없이 화면이 열린다. 나가려면 로그아웃이어야 한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ElumScaffold(
        bottomButton: ElumButton(
          label: _isSubmitting ? '저장 중...' : '동의하고 시작하기',
          onPressed: _allRequiredChecked && !_isSubmitting ? _submit : null,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ElumHeader(
                title: '시작하기 전에\n확인해주세요',
                description: '항목을 눌러 내용을 모두 보실 수 있어요.',
              ),
              SizedBox(height: context.space.headerToContent),

              _AllAgreeRow(checked: _allChecked, onTap: _toggleAll),
              SizedBox(height: 8.h),
              Divider(color: context.colors.border, height: 1),
              SizedBox(height: 8.h),

              for (final item in consentItems)
                _ConsentRow(
                  item: item,
                  checked: _checked[item.key] == true,
                  onToggle: () => setState(
                    () => _checked[item.key] = !(_checked[item.key] == true),
                  ),
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConsentDocumentScreen(item: item),
                    ),
                  ),
                ),

              if (_errorMessage != null) ...[
                SizedBox(height: context.space.md),
                Text(
                  _errorMessage!,
                  style: context.typo.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],

              SizedBox(height: 16.h),
              Center(
                child: AppPressable(
                  onTap: _leave,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
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

class _AllAgreeRow extends StatelessWidget {
  const _AllAgreeRow({required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            _CheckMark(checked: checked),
            SizedBox(width: 12.w),
            Expanded(
              child: Text('모두 동의합니다', style: context.typo.title),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.item,
    required this.checked,
    required this.onToggle,
    required this.onOpen,
  });

  final ConsentItem item;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 체크 영역과 전문 열기 영역을 나눈다. 한 덩어리로 두면
          // 내용을 보려다 동의가 눌리거나 그 반대가 된다.
          AppPressable(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: _CheckMark(checked: checked),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: AppPressable(
              onTap: onOpen,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.required ? '[필수] ' : '[선택] ',
                          style: context.typo.body.copyWith(
                            color: item.required
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(item.label, style: context.typo.body),
                        ),
                        Icon(Icons.chevron_right,
                            size: 20.w, color: colors.textSecondary),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.summary,
                      style: context.typo.caption
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 체크 표시. 아동도 보는 앱이라 빨강·경고색을 쓰지 않는다.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        color: checked ? colors.textPrimary : Colors.transparent,
        border: Border.all(
          color: checked ? colors.textPrimary : colors.border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: checked
          ? Icon(Icons.check, size: 16.w, color: colors.surface)
          : null,
    );
  }
}
