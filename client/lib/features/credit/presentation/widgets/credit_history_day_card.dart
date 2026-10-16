import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/credit_history.dart';
import 'credit_history_labels.dart';

/// 하루치 내역: 날짜 머리글 > 흰 카드(줄마다 제목·부제·증감) (Figma `1589:8359`)
class CreditHistoryDayCard extends StatelessWidget {
  const CreditHistoryDayCard({super.key, required this.day});

  final CreditHistoryDay day;

  /// 날짜 글자 왼쪽 여백과 날짜 > 카드 사이 (카드 y26 - 날짜 높이 14)
  static const _dateInsetLeft = 20.0;
  static const _dateToCardGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: _dateInsetLeft.w),
          child: Text(
            context.l10n.creditHistoryDay(day.date.month, day.date.day),
            style: context.typo.creditHistoryDate.copyWith(
              color: colors.creditHistoryMutedText,
            ),
          ),
        ),
        SizedBox(height: _dateToCardGap.h),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.creditCardBg,
            borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          ),
          child: Column(
            children: [
              for (final entry in day.entries) CreditHistoryRow(entry: entry),
            ],
          ),
        ),
      ],
    );
  }
}

/// 내역 한 줄: 왼쪽 위 제목, 아래 부제, 오른쪽 가운데 증감
///
/// 사용 줄은 일과 제목이 위에 서고(일과가 지워졌으면 종류가 대신 선다), 지급·만료·조정은 종류가 위에 선다.
class CreditHistoryRow extends StatelessWidget {
  const CreditHistoryRow({super.key, required this.entry});

  final CreditHistoryEntry entry;

  /// 줄 높이 69 = 위아래 안쪽 16 + 제목 16 + 사이 8 + 부제 13 (Figma `1589:8379`)
  static const _minHeight = 69.0;
  static const _padH = 20.0;
  static const _padV = 16.0;
  static const _titleToDetailGap = 8.0;
  static const _textToDeltaGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final kindLabel = creditHistoryKindLabel(l10n, entry);
    final routineTitle = entry.routineTitle;
    final isTitledUsage = (entry.kind?.isUsage ?? false) && routineTitle != null;

    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.occurredAt));
    final title = isTitledUsage ? routineTitle : kindLabel;
    final detail = isTitledUsage ? l10n.creditHistoryDetail(kindLabel, time) : time;

    final isGain = entry.delta > 0;
    final deltaText = isGain ? '+${entry.delta}' : '${entry.delta}';

    return MergeSemantics(
      child: ConstrainedBox(
        key: ValueKey('credit-history-row-${entry.id}'),
        constraints: BoxConstraints(minHeight: _minHeight.h),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.creditHistoryRowTitle.copyWith(
                        color: colors.settingsCardLabel,
                      ),
                    ),
                    SizedBox(height: _titleToDetailGap.h),
                    Text(
                      detail,
                      style: context.typo.creditHistoryRowDetail.copyWith(
                        color: colors.creditHistoryMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: _textToDeltaGap.w),
              Text(
                deltaText,
                textAlign: TextAlign.right,
                style: context.typo.creditHistoryRowTitle.copyWith(
                  color: isGain
                      ? colors.creditNumberText
                      : colors.creditHistoryMutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
