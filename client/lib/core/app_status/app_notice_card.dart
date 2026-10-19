import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 앱 전체를 막는 안내(강제 업데이트, 점검): 어두운 막 위의 흰색 카드 (이미지, 문구, 설명, 버튼 하나)
/// 이룸이도 보는 화면이라 빨강·경고 아이콘 없이 누를 것은 버튼 하나만 둔다.
class AppNoticeCard extends StatelessWidget {
  const AppNoticeCard({
    super.key,
    required this.imageAsset,
    required this.title,
    this.body,
    required this.actionLabel,
    required this.onAction,
  });

  /// 카드 최대 너비: 태블릿에서 카드가 화면 폭만큼 늘어나지 않게 한다
  static const maxCardWidth = 420.0;

  final String imageAsset;
  final String title;

  /// 없으면 문구만 둔다 (강제 업데이트), 있으면 문구 아래 설명 (점검)
  final String? body;
  final String actionLabel;

  /// 카드 안쪽 context 를 받는다: 실패 팝업을 이 화면의 Navigator 위에 띄워야 한다
  final void Function(BuildContext context) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Scaffold(
      backgroundColor: colors.background,
      body: ColoredBox(
        color: colors.dialogScrim,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxCardWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22.w, 28.h, 22.w, 22.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          imageAsset,
                          width: 240.w,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: typo.cardTitle.copyWith(
                            color: colors.textPrimary,
                            height: 1.4, // 두 줄이라 줄 사이를 띄운다
                          ),
                        ),
                        if (body != null) ...[
                          SizedBox(height: 10.h),
                          Text(
                            body!,
                            textAlign: TextAlign.center,
                            style: typo.promptBody.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        SizedBox(height: 28.h),
                        SizedBox(
                          width: double.infinity,
                          height: 66.h, // 이룸이 화면 최소 터치 규칙
                          // 이 MaterialApp 안쪽 context 가 있어야 실패 팝업을 띄울 수 있다
                          child: Builder(
                            builder: (innerContext) => FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.updateNoticeButton,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18.r),
                                ),
                              ),
                              onPressed: () => onAction(innerContext),
                              child: Text(
                                actionLabel,
                                style: typo.button.copyWith(
                                  color: colors.surface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
