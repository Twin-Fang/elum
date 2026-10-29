import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_multiline_text_field.dart';
import '../../domain/talk_text_limits.dart';

/// 한마디 입력칸(안내는 칸 안 placeholder) + 아래 글자 수 (올리기 · 고치기가 함께 쓴다, 시안 1870:9449)
class TalkNoteField extends StatelessWidget {
  const TalkNoteField({
    super.key,
    required this.controller,
    required this.isEnabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isEnabled;
  final ValueChanged<String> onChanged;

  /// 처음 보이는 줄 · 늘어나는 최대 줄 · 칸 안쪽 (시안 칸 높이 124 = 안쪽 20 + 5줄 × 16.8 + 20)
  static const _minLines = 5;
  static const _maxLines = 8;
  static const _contentInset = 20.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElumMultilineTextField(
          controller: controller,
          hintText: context.l10n.talkNoteGuide,
          maxLength: TalkTextLimits.maxNoteLength,
          minLines: _minLines,
          maxLines: _maxLines,
          enabled: isEnabled,
          onChanged: onChanged,
          textStyle: context.typo.talkNoteInput,
          contentInset: _contentInset,
          textColor: context.colors.talkNoteText,
          hintColor: context.colors.talkNoteHint,
        ),
        TalkNoteCaption(noteLength: controller.text.length),
      ],
    );
  }
}

/// 한마디 입력칸 아래 캡션: 오른쪽 글자 수 카운터 (시안 1870:9456)
class TalkNoteCaption extends StatelessWidget {
  const TalkNoteCaption({super.key, required this.noteLength});

  final int noteLength;

  /// 입력칸 > 캡션 · 캡션 글자가 칸보다 들어가는 폭 (시안 12 · 16)
  static const _fieldToCaption = 12.0;
  static const _captionInset = 16.0;

  /// 남은 글자가 이만큼 아래면 카운터를 진하게 (넘기기 전에 알아채게)
  static const _nearLimitRemaining = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.talkNoteCounter.copyWith(
      color: colors.talkMetaText,
    );
    final isNearLimit =
        TalkTextLimits.maxNoteLength - noteLength <= _nearLimitRemaining;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _captionInset.w,
        _fieldToCaption.h,
        _captionInset.w,
        0,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.fast,
          style: isNearLimit
              ? style.copyWith(
                  color: colors.talkAccentText,
                  fontWeight: FontWeight.w600,
                )
              : style,
          child: Text('$noteLength/${TalkTextLimits.maxNoteLength}'),
        ),
      ),
    );
  }
}
