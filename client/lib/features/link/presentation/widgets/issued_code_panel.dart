import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../domain/link_status.dart';
import 'link_code_text.dart';

/// 발급된 코드를 보여 주는 덩어리: 만드는 중 > 코드 > 코드 복사하기 > `09:59 뒤에 코드가 바껴요`
///
/// 연결 암호 만들기와 초대 코드 만들기가 같은 배치를 쓴다. 발급·타이머·폴링 같은
/// 화면별 로직은 각 화면이 들고, 이 위젯은 받은 값을 그리기만 한다.
/// 시간이 다 된 코드는 `만료`라 말하지 않는다. 화면이 새 코드로 조용히 바꾸고([isRenewing]),
/// 새로 못 받았을 때만 복사하기 자리에 `다시 만들기`가 선다.
/// 부모가 `crossAxisAlignment.stretch` 인 Column 이고 높이가 정해지지 않은 스크롤 안이라는
/// 전제다: 그 자리에서 [ElumStateBody.loading] 은 스피너를 가운데에 그대로 둔다.
class IssuedCodePanel extends StatelessWidget {
  const IssuedCodePanel({
    super.key,
    required this.loading,
    required this.issued,
    required this.onRetry,
    required this.onCopy,
    this.isRenewing = false,
    this.showStatus = true,
    this.replacement,
  });

  /// 코드를 만드는 중. 스피너만 보인다.
  final bool loading;

  /// 발급된 코드. null 이면 코드 자리가 비어 있다.
  final IssuedLinkCode? issued;

  /// 새로 못 받았을 때 복사하기 자리에 서는 `다시 만들기` 칩의 동작.
  final VoidCallback? onRetry;

  /// `코드 복사하기` 알약의 동작 (Figma 1532:6798).
  final VoidCallback? onCopy;

  /// 시간이 다 된 코드를 새 코드로 바꾸는 중. 이 동안은 옛 코드를 그대로 두고 칩을 바꾸지 않는다.
  final bool isRenewing;

  /// 복사하기·남은 시간을 보일지. 연결되면 더 기다릴 이유가 없어 끈다.
  final bool showStatus;

  /// 있으면 코드 대신 이것을 보인다 (실패·빈 상태). 로딩이 우선한다.
  final Widget? replacement;

  /// 설명 하단(227) → 코드 상단(299). 시안 `732:5656` 실측.
  static const descriptionToCode = 72.0;
  static const codeToTimer = 24.0;
  static const timerToRetry = 16.0;

  /// 남은 시간 `09:59` 와 안내 글 사이 (Figma 1532:6795 gap 4).
  static const timerToSuffix = 4.0;

  /// 암호 여섯 글자 사이 간격. 시안은 3-3으로 묶고 가운데를 더 벌린다
  /// (글자 좌표 0·47·100 | 164·211·258).
  static const codeLetterGap = 20.0;
  static const codeGroupGap = 40.0;

  /// 남은 시간 `MM:SS`. 올림이 아니라 **내림**이다: 실제보다 길게 말하면 믿고 기다리다 바뀐다.
  static String remainingLabel(IssuedLinkCode issued) {
    final total = issued.remaining().inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// 남은 시간 한 줄: `09:59`(빨강) + `뒤에 코드가 바껴요`(회색)
  Widget _remainingRow(BuildContext context, IssuedLinkCode issued) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          remainingLabel(issued),
          style: context.typo.linkTimer.copyWith(color: colors.linkTimer),
        ),
        SizedBox(width: timerToSuffix.w),
        Text(
          context.l10n.linkCodeChangesAfter,
          style: context.typo.linkTimer.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  /// 시간이 다 됐는데 새 코드를 받는 중도 아니다: 새로 못 받은 상태
  bool _isStale(IssuedLinkCode issued) => issued.isExpired && !isRenewing;

  @override
  Widget build(BuildContext context) {
    final issued = this.issued;
    final replacement = this.replacement;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: descriptionToCode.h),
        if (loading)
          const ElumStateBody.loading()
        else if (replacement != null)
          replacement
        else if (issued != null) ...[
          LinkCodeText(
            code: issued.code,
            // 새로 못 받아 시간이 다 된 코드만 흐리다 (바꾸는 중에는 그대로)
            dimmed: _isStale(issued),
            letterGap: codeLetterGap,
            groupGap: codeGroupGap,
          ),
          if (showStatus) ...[
            SizedBox(height: codeToTimer.h),
            Center(
              child: _isStale(issued)
                  ? LinkActionChip(onTap: onRetry)
                  : LinkActionChip(label: context.l10n.issuedCodeCopyButton, onTap: onCopy),
            ),
            if (!_isStale(issued)) ...[
              SizedBox(height: timerToRetry.h),
              _remainingRow(context, issued),
            ],
          ],
        ],
      ],
    );
  }
}
