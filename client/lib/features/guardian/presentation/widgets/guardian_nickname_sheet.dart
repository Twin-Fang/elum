import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_shake.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_sheet_text_field.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../member/application/guardian_nickname_editor.dart';
import '../../../member/domain/guardian_nickname_policy.dart';

/// 내 이름 변경하기 시트 (시안 1759:9649): 입력 > 형식 확인 > 저장 > 닫기. 저장했으면 true
///
/// 저장을 시트 안에서 한다: 서버 거절(금지어·중복·7일)이면 사유를 입력칸 아래에 두고 고쳐 쓰게 함
Future<bool> showGuardianNicknameSheet(
  BuildContext context, {
  required String currentNickname,
}) async {
  final isSaved = await showElumSheet<bool>(
    context: context,
    builder: (_) => _GuardianNicknameSheet(currentNickname: currentNickname),
  );
  return isSaved ?? false;
}

class _GuardianNicknameSheet extends ConsumerStatefulWidget {
  const _GuardianNicknameSheet({required this.currentNickname});

  final String currentNickname;

  @override
  ConsumerState<_GuardianNicknameSheet> createState() =>
      _GuardianNicknameSheetState();
}

class _GuardianNicknameSheetState
    extends ConsumerState<_GuardianNicknameSheet> {
  late final _controller = TextEditingController(text: widget.currentNickname);

  /// 시안 1759:9649 실측: 입력칸 > 버튼 40 · 입력칸 > 거절 사유 8 (제목 · 설명 · 머리 > 본문은 [ElumSheetFrame])
  static const _fieldToButton = 40.0;
  static const _fieldToRejection = 8.0;

  /// 거절 사유는 제목 · 설명과 같은 x=24 (본문 16 + 8)
  static const _textInset = 8.0;

  bool _isSaving = false;

  /// 입력칸 아래 거절 사유. 고쳐 쓰기 시작하면 지움
  String? _rejectionMessage;

  /// 거절할 때마다 늘려 입력칸을 흔듦
  int _rejectionCount = 0;

  String get _newNickname => _controller.text.trim();

  bool get _canSave =>
      _newNickname.isNotEmpty && _newNickname != widget.currentNickname.trim();

  @override
  void initState() {
    super.initState();
    // 지금 닉네임을 통째로 골라 두어 바로 새로 쓸 수 있게
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentNickname.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 저장: 형식 확인 > 서버 저장 > 성공 닫기 / 거절 사유 표시 / 그 외 실패 팝업
  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    // 한글 조합 중 글자가 형식 밖으로 보이지 않게 저장을 누를 때만 확인
    if (!GuardianNicknamePolicy.isValidFormat(_newNickname)) {
      _reject(context.l10n.guardianNicknameInvalidFormat);
      return;
    }
    setState(() => _isSaving = true);
    final failure = await ref
        .read(guardianNicknameEditorProvider)
        .change(_newNickname);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (isGuardianNicknameRejection(failure)) {
      _reject(failure.messageOr(context.l10n.guardianNicknameInvalidFormat));
      return;
    }
    await showFailure(
      context,
      failure,
      fallback: context.l10n.guardianNicknameSaveFailed,
      fallbackCode: 'E-NICKNAME-SAVE',
    );
  }

  void _reject(String message) {
    setState(() {
      _rejectionMessage = message;
      _rejectionCount++;
    });
  }

  void _onChanged(String _) {
    setState(() => _rejectionMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rejection = _rejectionMessage;

    // 공통 시트 틀: 제목 > 설명 > 입력칸 > 저장 (키보드 · 큰 글자 스크롤 포함)
    return ElumSheetFrame(
      title: context.l10n.guardianNicknameSheetTitle,
      description: context.l10n.guardianNicknameSheetDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppShake(
            trigger: _rejectionCount,
            child: ElumSheetTextField(
              controller: _controller,
              hintText: context.l10n.guardianNicknameSheetHint,
              maxLength: GuardianNicknamePolicy.maxLength,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: (_) => _save(),
            ),
          ),
          // 거절 사유: 나타날 때 자리가 툭 생기지 않게 높이를 늘이며 보임
          AnimatedSize(
            duration: AppMotion.fast,
            curve: AppMotion.decelerate,
            alignment: Alignment.topCenter,
            child: rejection == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: EdgeInsets.fromLTRB(
                      _textInset.w,
                      _fieldToRejection.h,
                      _textInset.w,
                      0,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        rejection,
                        style: context.typo.myInfoMeta.copyWith(
                          color: colors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
          ),
          SizedBox(height: _fieldToButton.h),
          ElumButton(
            label: context.l10n.guardianNicknameSheetSave,
            loading: _isSaving,
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}
