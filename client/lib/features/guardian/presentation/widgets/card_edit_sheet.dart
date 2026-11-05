import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/state/busy_state_mixin.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_text_field.dart';
import '../../data/card_photo.dart';
import 'card_photo_block.dart';
import 'card_voice_block.dart';
import 'routine_flow_scaffold.dart' show dismissKeyboard;

/// 시트가 카드를 고치는지, 새로 넣는지.
enum CardSheetMode { edit, add }

/// 카드 제목·설명 시트 — 수정과 추가가 함께 쓴다.
///
/// 시안 `1197:5923`(수정) · `1197:6161`(수정 + 키보드) · `1197:6044`(추가).
/// 바텀시트이며 시안 간격을 위에서부터 쌓는다 (칸 높이는 글 높이를 따름).
///
/// **키보드가 올라오면 시트가 위로 커진다(y=82, 높이 770).** 입력칸을 키보드 위로
/// 밀어 올리는 것이 아니라 시트 자체가 화면 위까지 자라고, 버튼은 시트 바닥(키보드
/// 뒤)에 남는다. 입력칸은 키보드 위(y≤326)에 그대로 있어 가려지지 않는다.
///
/// 시트는 값만 돌려준다. 서버 반영은 호출한 화면의 몫이다.
class CardEditSheet extends StatefulWidget {
  const CardEditSheet({
    super.key,
    required this.mode,
    this.initialTitle = '',
    this.initialDescription = '',
    this.onSubmit,
    this.photo,
    this.voice,
  });

  final CardSheetMode mode;

  /// 그림을 사진으로 바꿀 카드. **서버 id 가 있는 수정 시트에서만** 준다 —
  /// null 이면 그림 칸도 `사진 바꾸기` 칩도 없다(추가 시트·서버에 없는 카드).
  final CardPhotoTarget? photo;

  /// 보호자 목소리를 녹음할 카드 (Pro 이거나 녹음이 남은 서버 카드만). null 이면 녹음 칸이 없다
  final CardPhotoTarget? voice;

  /// 값을 받아 서버에 넣는다. true 면 시트가 닫히고, false 면 **열린 채 입력을 남긴다.**
  ///
  /// null 이면 값만 돌려주고 닫는다(수정 — 실패는 호출한 화면이 닫힌 뒤 알린다).
  /// 추가는 새 카드의 id 를 서버가 줘야 해서, 실패했는데 시트가 닫히면 보호자가 쓴
  /// 글이 사라진다.
  final Future<bool> Function(String title, String description)? onSubmit;
  final String initialTitle;
  final String initialDescription;

  /// 시안 간격 (393×852 기준). 칸 높이는 고정하지 않고 위에서부터 쌓음 (글자 배율이 커져도 겹치지 않게)
  /// 수정: 제목 y40 > 본문 y84 > 칸 > 칸 사이 16 > 설명 칸 끝 > 버튼 42 > 바닥 56
  static const _titleTop = 40.0;
  static const _titleToBody = 24.0;

  /// 추가 시트는 제목 아래가 40 더 큼. 시안 추가 시트의 두 번째 `설명` 글자는 복사 잔재라 그리지 않음
  static const _addOffset = 40.0;
  static const _titleInset = 8.0;
  static const _fieldGap = 16.0;
  static const _fieldToButton = 42.0;
  static const _buttonToBottom = 56.0;

  /// 그림 칸·녹음 칸 아래 간격 (임시 시안)
  static const _photoGap = 16.0;
  static const _voiceGap = 12.0;

  /// 키보드가 올라오면 시트 윗변이 이 자리(y=82)까지 올라감
  static const _keyboardTop = 82.0;

  /// 수정 결과. 완료를 눌러야만 값이 돌아오고, 밖을 탭해 닫으면 null이다.
  static Future<({String title, String description})?> show(
    BuildContext context, {
    required String title,
    required String description,
    CardPhotoTarget? photo,
    CardPhotoTarget? voice,
  }) {
    return _open(
      context,
      CardEditSheet(
        mode: CardSheetMode.edit,
        initialTitle: title,
        initialDescription: description,
        photo: photo,
        voice: voice,
      ),
    );
  }

  /// 새 카드. 결과는 [show] 와 같다.
  static Future<({String title, String description})?> showAdd(
    BuildContext context, {
    required Future<bool> Function(String title, String description) onSubmit,
  }) {
    return _open(
      context,
      CardEditSheet(mode: CardSheetMode.add, onSubmit: onSubmit),
    );
  }

  static Future<({String title, String description})?> _open(
    BuildContext context,
    CardEditSheet sheet,
  ) {
    return showElumSheet<({String title, String description})>(
      context: context,
      barrierColor: context.colors.sheetScrim,
      builder: (_) => sheet,
    );
  }

  @override
  State<CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<CardEditSheet>
    with BusyStateMixin<CardEditSheet> {
  late final _titleController = TextEditingController(
    text: widget.initialTitle,
  );
  late final _descriptionController = TextEditingController(
    text: widget.initialDescription,
  );

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isAdd => widget.mode == CardSheetMode.add;

  /// 제목·설명 둘 다 있어야 저장할 수 있다.
  /// 빈 카드가 저장되면 이룸이 화면에 내용 없는 카드가 나간다.
  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final submit = widget.onSubmit;

    if (submit != null) {
      // 서버에 넣는 동안 다시 눌러도 두 번 가지 않게 잠근다. 진행 중이면 null 이다.
      final ok = await runBusy(() => submit(title, description));
      if (ok == null || !mounted) return;
      // 실패하면 열어 둔다 — 쓴 글이 남아 있어야 다시 누를 수 있다
      if (!ok) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop((title: title, description: description));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return GestureDetector(
      // 빈 곳을 누르면 키보드가 내려간다 — 버튼이 키보드 뒤에 있어 내려야 누를 수 있다
      behavior: HitTestBehavior.opaque,
      onTap: dismissKeyboard,
      // 손잡이는 시트 면이 그린다 — 시안은 굵기 4 선의 **가운데**가 y=16 이라 윗변은 14 다
      child: ElumSheetSurface(
        animationDuration: AppMotion.fast,
        animationCurve: Curves.easeOut,
        // 키보드: 시트가 y82 까지 자라고 버튼은 바닥(키보드 뒤). 그 외: 내용 높이
        height: keyboardOpen ? (852 - CardEditSheet._keyboardTop).h : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.space.buttonMarginH.w,
            CardEditSheet._titleTop.h,
            context.space.buttonMarginH.w,
            CardEditSheet._buttonToBottom.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 글자가 커져 시트 최대 높이를 넘으면 본문만 스크롤
              Flexible(child: SingleChildScrollView(child: _body(context, keyboardOpen: keyboardOpen))),
              SizedBox(height: CardEditSheet._fieldToButton.h),
              ElumButton(
                label: _isAdd
                    ? context.l10n.cardEditAddAction
                    : context.l10n.cardEditDoneAction,
                onPressed: _canSave ? _save : null,
                loading: busy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 제목 > (그림 칸) > (녹음 칸) > 제목 칸 > 설명 칸
  Widget _body(BuildContext context, {required bool keyboardOpen}) {
    final colors = context.colors;
    final photo = widget.photo;
    final voice = widget.voice;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: CardEditSheet._titleInset.w),
          child: Text(
            _isAdd ? context.l10n.cardEditAddTitle : context.l10n.cardEditTitle,
            style: context.typo.sheetHeading.copyWith(color: colors.textPrimary),
          ),
        ),
        SizedBox(height: (CardEditSheet._titleToBody + (_isAdd ? CardEditSheet._addOffset : 0)).h),
        // 그림·녹음 칸은 키보드가 올라오면 접되 트리에 남겨 상태(올리는 중·녹음 중)를 지킴
        if (photo != null && !_isAdd)
          Visibility(
            visible: !keyboardOpen,
            maintainState: true,
            child: Padding(
              padding: EdgeInsets.only(bottom: CardEditSheet._photoGap.h),
              child: CardPhotoBlock(routineId: photo.routineId, stepId: photo.stepId),
            ),
          ),
        if (voice != null && !_isAdd)
          Visibility(
            visible: !keyboardOpen,
            maintainState: true,
            child: Padding(
              padding: EdgeInsets.only(bottom: CardEditSheet._voiceGap.h),
              child: CardVoiceBlock(routineId: voice.routineId, stepId: voice.stepId),
            ),
          ),
        ElumSheetTextField(
          controller: _titleController,
          label: context.l10n.cardEditFieldTitle,
          hintText: context.l10n.cardEditTitleHint,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: CardEditSheet._fieldGap.h),
        ElumSheetTextField(
          controller: _descriptionController,
          label: context.l10n.cardEditFieldDescription,
          hintText: context.l10n.cardEditDescriptionHint,
          // 설명은 소리로 읽히는 한 문장: 두 줄까지 보이고 줄바꿈은 막음
          maxLines: 2,
          shouldBlockLineBreaks: true,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
