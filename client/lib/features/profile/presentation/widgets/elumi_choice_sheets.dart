import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/selectable_group.dart';
import '../../../../shared/models/character.dart';
import '../../../../shared/models/image_style.dart';
import '../../../../core/widgets/character_card.dart';
import '../../../../core/widgets/image_style_credit_bar.dart';
import '../../../../core/widgets/image_style_option_card.dart';
import '../../../credit/application/credit_costs.dart';

/// 캐릭터 바꾸기 시트: 카드 2장 중 하나 > 저장하기. 저장하면 고른 캐릭터를 돌려준다 (#660)
Future<CardCharacter?> showElumiCharacterSheet(
  BuildContext context, {
  required CardCharacter current,
}) {
  return showElumSheet<CardCharacter>(
    context: context,
    barrierColor: context.colors.sheetScrim,
    builder: (_) => _ChoiceSheet<CardCharacter>(
      title: context.l10n.elumiInfoCharacterSheetTitle,
      current: current,
      bodyBuilder: (context, picked, onPicked) =>
          _CharacterChoices(picked: picked, onPicked: onPicked),
    ),
  );
}

/// 그림 방식 바꾸기 시트: 크레딧 띠 + 방식 3개 중 하나 > 저장하기. 저장하면 고른 방식을 돌려준다 (#660)
///
/// 만화 예시에는 그 이룸이의 [character] 를 그린다
Future<ImageStyle?> showElumiImageStyleSheet(
  BuildContext context, {
  required ImageStyle current,
  required CardCharacter character,
}) {
  return showElumSheet<ImageStyle>(
    context: context,
    barrierColor: context.colors.sheetScrim,
    builder: (_) => _ChoiceSheet<ImageStyle>(
      title: context.l10n.elumiInfoImageStyleSheetTitle,
      current: current,
      bodyBuilder: (context, picked, onPicked) => _ImageStyleChoices(
        picked: picked,
        character: character,
        onPicked: onPicked,
      ),
    ),
  );
}

/// 하나 고르기 시트 틀: 제목 > 고르기 영역(스크롤) > 저장하기 (지금 값 그대로면 저장 막음)
class _ChoiceSheet<T> extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.current,
    required this.bodyBuilder,
  });

  final String title;
  final T current;
  final Widget Function(
    BuildContext context,
    T picked,
    ValueChanged<T> onPicked,
  )
  bodyBuilder;

  @override
  State<_ChoiceSheet<T>> createState() => _ChoiceSheetState<T>();
}

class _ChoiceSheetState<T> extends State<_ChoiceSheet<T>> {
  late T _picked = widget.current;

  bool get _canSave => _picked != widget.current;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return ElumSheetSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          space.md.w,
          space.lg.h,
          space.md.w,
          space.md.h + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: context.typo.sectionTitle.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: space.md.h),
            // 글자를 키우면 카드가 시트를 넘음 > 스크롤
            Flexible(
              child: SingleChildScrollView(
                child: widget.bodyBuilder(
                  context,
                  _picked,
                  (next) => setState(() => _picked = next),
                ),
              ),
            ),
            SizedBox(height: space.md.h),
            ElumButton(
              label: context.l10n.elumiInfoSave,
              onPressed: _canSave
                  ? () => Navigator.of(context).pop(_picked)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 캐릭터 카드 2열 (온보딩 캐릭터 카드 재사용)
class _CharacterChoices extends StatelessWidget {
  const _CharacterChoices({required this.picked, required this.onPicked});

  final CardCharacter picked;
  final ValueChanged<CardCharacter> onPicked;

  @override
  Widget build(BuildContext context) {
    final group = SelectableGroup<CardCharacter>(
      items: CardCharacter.values,
      selected: {picked},
      // 늘 하나는 골라져 있어야 함
      allowDeselect: false,
      onChanged: (next) {
        if (next.isNotEmpty) onPicked(next.first);
      },
      itemBuilder: (context, character, isSelected) =>
          CharacterCard(character: character, isSelected: isSelected),
      semanticLabelOf: (character) => character.displayName,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final character in CardCharacter.values) ...[
          Expanded(child: group.buildItem(context, character)),
          if (character != CardCharacter.values.last)
            SizedBox(width: context.space.sm.w),
        ],
      ],
    );
  }
}

/// 크레딧 띠 + 그림 방식 카드 목록 (설정 그림 방식 화면과 같은 카드)
class _ImageStyleChoices extends StatelessWidget {
  const _ImageStyleChoices({
    required this.picked,
    required this.character,
    required this.onPicked,
  });

  final ImageStyle picked;
  final CardCharacter character;
  final ValueChanged<ImageStyle> onPicked;

  @override
  Widget build(BuildContext context) {
    final gap = context.space.sm.h;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 고른 방식의 비용을 저장 전에 보여 줌
        // 단가는 크레딧 기능에서 읽어 넘긴다
        Consumer(
          builder: (context, ref, _) => ImageStyleCreditBar(
            style: picked,
            costs: ref.watch(creditCostsProvider),
          ),
        ),
        SizedBox(height: gap),
        SelectableGroup<ImageStyle>(
          items: ImageStyle.values,
          selected: {picked},
          allowDeselect: false,
          gap: gap,
          asRadio: true,
          onChanged: (next) {
            if (next.isNotEmpty) onPicked(next.first);
          },
          itemBuilder: (context, style, isSelected) => ImageStyleOptionCard(
            style: style,
            isSelected: isSelected,
            character: character,
          ),
          semanticLabelOf: ImageStyleOptionCard.semanticLabel,
        ),
      ],
    );
  }
}
