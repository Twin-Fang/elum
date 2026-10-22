import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_text_field.dart';
import '../../../../shared/models/routine.dart';
import '../../domain/routine_group.dart';
import 'routine_group_pick_row.dart';

/// 일과 고르기 결과: 묶음 이름(새 묶음일 때) + 누른 순서대로의 일과 id
typedef RoutinePickResult = ({String name, List<String> routineIds});

/// 일과 고르기 시트 (#807): 끌기를 몰라도 묶음을 만들고 넣을 수 있는 길
///
/// 누른 순서대로 1·2·3 번호가 붙고 그 순서가 묶음 순서가 된다.
/// [groupName] 이 null 이면 새 묶음(이름 + 2개 이상), 있으면 그 묶음에 넣기(1개 이상).
Future<RoutinePickResult?> showRoutineGroupPicker(
  BuildContext context, {
  required List<Routine> candidates,
  String? groupName,
  List<String> preselectedIds = const [],
}) {
  return showElumSheet<RoutinePickResult>(
    context: context,
    builder: (_) => _RoutineGroupPicker(
      candidates: candidates,
      groupName: groupName,
      preselectedIds: preselectedIds,
    ),
  );
}

class _RoutineGroupPicker extends StatefulWidget {
  const _RoutineGroupPicker({
    required this.candidates,
    required this.groupName,
    required this.preselectedIds,
  });

  final List<Routine> candidates;
  final String? groupName;
  final List<String> preselectedIds;

  @override
  State<_RoutineGroupPicker> createState() => _RoutineGroupPickerState();
}

class _RoutineGroupPickerState extends State<_RoutineGroupPicker> {
  late final _nameController = TextEditingController();
  late final List<String> _picked = [...widget.preselectedIds];

  /// 시트 높이 (화면 대비, 시안 770/852) — 목록이 길어도 이름 칸과 버튼이 늘 보이게
  static const _heightRatio = 770 / 852;

  /// 시트 윗변 > 제목 · 칸 좌우 여백 · 글자 줄 추가 안쪽 (시안 40, 16, 8)
  static const _titleTop = 40.0;
  static const _contentInset = 16.0;
  static const _textInset = 8.0;

  /// 덩어리 사이(제목 > 라벨, 칸 > 안내) · 라벨 > 칸 · 안내 > 목록 · 줄 사이 (시안 24, 9, 16, 8)
  static const _blockGap = 24.0;
  static const _labelToField = 9.0;
  static const _hintToList = 16.0;
  static const _rowGap = 8.0;

  /// 그라데이션 윗변 > 버튼 · 홈 표시줄 위 버튼 아래 여백 (시안 16, 56 - 34)
  static const _fadeAboveButton = 16.0;
  static const _buttonBottomExtra = 22.0;

  bool get _isNewGroup => widget.groupName == null;

  bool get _canConfirm => _isNewGroup
      ? _picked.length >= RoutineGroup.minimumRoutineCount
      : _picked.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
    if (!_picked.remove(id)) _picked.add(id);
  });

  void _confirm() {
    if (!_canConfirm) return;
    // 이름을 비우면 기본 이름 — 나중에 바꿀 수 있다
    final typed = _nameController.text.trim();
    final name = typed.isEmpty ? context.l10n.routineGroupDefaultName : typed;
    Navigator.of(context).pop((name: name, routineIds: List.of(_picked)));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ElumSheetSurface(
        // 키보드가 올라오면 남은 공간 안으로 줄여 상태바 밑으로 올라가지 않게
        height: math.min(
          media.size.height * _heightRatio,
          media.size.height -
              media.viewInsets.bottom -
              media.padding.top -
              context.space.md.h,
        ),
        // 목록이 버튼 밑으로 흐려지며 사라진다 — 버튼을 목록 위에 띄운다
        child: Stack(
          children: [
            _buildForm(context),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildConfirmBar(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 제목 > (새 묶음이면) 이름 라벨·칸 > 고르기 안내 > 일과 목록
  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final groupName = widget.groupName;
    final labelStyle = context.typo.sheetFieldLabel.copyWith(
      color: colors.sheetFieldLabelText,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _contentInset.w,
        _titleTop.h,
        _contentInset.w,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _inset(
            Text(
              groupName == null
                  ? l10n.routineGroupNewTitle
                  : l10n.routineGroupAddTitle(groupName),
              style: context.typo.sheetTitle.copyWith(
                color: colors.sheetTitleText,
              ),
            ),
          ),
          if (_isNewGroup) ...[
            SizedBox(height: _blockGap.h),
            _inset(Text(l10n.routineGroupNameLabel, style: labelStyle)),
            SizedBox(height: _labelToField.h),
            ElumTextField(
              controller: _nameController,
              hintText: l10n.routineGroupNameHint,
              maxLength: RoutineGroup.nameMaxLength,
              inputStyle: context.typo.sheetFieldText,
            ),
          ],
          SizedBox(height: _blockGap.h),
          _inset(
            Text(
              _isNewGroup
                  ? l10n.routineGroupPickHintNew
                  : l10n.routineGroupPickHint,
              style: labelStyle,
            ),
          ),
          SizedBox(height: _hintToList.h),
          Expanded(child: _buildCandidateList(context)),
        ],
      ),
    );
  }

  /// 고를 일과 목록. 맨 아래는 버튼 띠만큼 비워 마지막 줄도 버튼 위로 올릴 수 있게
  Widget _buildCandidateList(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return Center(
        child: Text(
          context.l10n.routineGroupPickEmpty,
          textAlign: TextAlign.center,
          style: context.typo.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(bottom: _confirmBarHeight(context)),
      itemCount: widget.candidates.length,
      separatorBuilder: (_, _) => SizedBox(height: _rowGap.h),
      itemBuilder: (context, index) {
        final routine = widget.candidates[index];
        final order = _picked.indexOf(routine.id);
        return RoutineGroupPickRow(
          routine: routine,
          order: order < 0 ? null : order + 1,
          onTap: () => _toggle(routine.id),
        );
      },
    );
  }

  /// 아래 버튼 띠: 위 투명 > 아래 시트 바탕색 그라데이션 + 묶기 버튼
  Widget _buildConfirmBar(BuildContext context) {
    final l10n = context.l10n;
    final background = context.colors.background;
    return Container(
      padding: EdgeInsets.fromLTRB(
        _contentInset.w,
        _fadeAboveButton.h,
        _contentInset.w,
        _buttonBottomGap(context),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.withValues(alpha: 0), background],
        ),
      ),
      child: ElumButton(
        label: _isNewGroup
            ? l10n.routineGroupPickConfirmNew(_picked.length)
            : l10n.routineGroupPickConfirmAdd(_picked.length),
        onPressed: _canConfirm ? _confirm : null,
      ),
    );
  }

  /// 버튼 아래 여백 (홈 표시줄 포함, 시안 56)
  double _buttonBottomGap(BuildContext context) =>
      _buttonBottomExtra.h + MediaQuery.of(context).padding.bottom;

  /// 버튼 띠 전체 높이 = 그라데이션 위 + 버튼 + 버튼 아래
  double _confirmBarHeight(BuildContext context) =>
      _fadeAboveButton.h + context.space.buttonH.h + _buttonBottomGap(context);

  /// 글자 줄은 칸보다 8 안쪽에서 시작한다 (시안: 칸 x16, 글자 x24)
  Widget _inset(Widget child) => Padding(
    padding: EdgeInsets.symmetric(horizontal: _textInset.w),
    child: child,
  );
}
