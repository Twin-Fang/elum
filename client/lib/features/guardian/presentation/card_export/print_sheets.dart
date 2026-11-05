import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../../../shared/models/routine.dart';
import '../../application/card_export_pictures.dart';
import '../../domain/card_export_options.dart';
import 'print_card.dart';
import 'print_page.dart';

/// 구울 지면 한 장: 크기 · 해상도 · 내용 (미리 보기와 파일이 같은 위젯을 쓴다)
@immutable
class PrintSheet {
  const PrintSheet({required this.size, required this.pixelRatio, required this.page, this.cardId});

  final Size size;
  final double pixelRatio;
  final Widget page;

  /// 카드 한 장씩일 때 그 카드 id (미리 보기에서 빼고 넣기)
  final String? cardId;
}

/// 설정 > 지면 목록: 일과 한 장 1장 · 오려 쓰는 카드 N쪽 · 카드 한 장씩 N장 (뺀 카드도 만듦 — 미리 보기에서 다시 넣게)
List<PrintSheet> buildPrintSheets({
  required Routine routine,
  required CardExportOptions options,
  required CardExportPictures pictures,
  required bool hasWatermark,
}) {
  final cards = [...routine.steps]..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
  if (cards.isEmpty) return const [];
  final hasPictogramCredit = pictures.hasPictogram;

  PrintCard cardAt(ActionCard card, {bool shouldShowNumber = true, bool shouldShowDescription = false}) =>
      PrintCard(
        card: card,
        index: cards.indexOf(card),
        picture: pictures.of(card),
        options: options,
        language: routine.language,
        shouldShowNumber: shouldShowNumber,
        shouldShowDescription: shouldShowDescription,
      );

  switch (options.format) {
    case CardExportFormat.routineSheet:
      return [
        PrintSheet(
          size: PrintPageSize.a4,
          pixelRatio: PrintPageSize.a4PixelRatio,
          page: PrintPage(
            size: PrintPageSize.a4,
            hasWatermark: hasWatermark,
            shouldShowPictogramCredit: hasPictogramCredit,
            child: _RoutineSheetBody(
              title: routine.title,
              language: routine.language,
              cards: [for (final card in cards) cardAt(card)],
            ),
          ),
        ),
      ];
    case CardExportFormat.cutCards:
      final perPage = options.cutCardsPerPage;
      return [
        for (final pageCards in chunkIntoPages(cards, perPage.count))
          PrintSheet(
            size: PrintPageSize.a4,
            pixelRatio: PrintPageSize.a4PixelRatio,
            page: PrintPage(
              size: PrintPageSize.a4,
              hasWatermark: hasWatermark,
              shouldShowPictogramCredit: hasPictogramCredit,
              child: _CutCardsBody(
                perPage: perPage,
                cards: [for (final card in pageCards) cardAt(card, shouldShowNumber: false)],
              ),
            ),
          ),
      ];
    case CardExportFormat.cardImages:
      return [
        for (final card in cards)
            PrintSheet(
              cardId: card.id,
              size: PrintPageSize.cardImage,
              pixelRatio: PrintPageSize.cardImagePixelRatio,
              page: PrintPage(
                size: PrintPageSize.cardImage,
                margin: 12,
                hasWatermark: hasWatermark,
                shouldShowPictogramCredit: hasPictogramCredit && pictures.of(card).pictogramId != null,
                child: cardAt(card, shouldShowDescription: true),
              ),
            ),
      ];
  }
}

/// 일과 한 장: 제목 + 카드 격자 (열 수는 카드 수로 정함)
class _RoutineSheetBody extends StatelessWidget {
  const _RoutineSheetBody({required this.title, required this.language, required this.cards});

  final String title;
  final String language;
  final List<Widget> cards;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final columns = routineSheetColumnsFor(cards.length);
    final rows = (cards.length / columns).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.typo.printPageTitle.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _Grid(columns: columns, rows: rows, gap: _gap, children: cards),
        ),
      ],
    );
  }
}

/// 오려 쓰는 카드: 칸마다 점선 자를 선 + 안쪽 카드
class _CutCardsBody extends StatelessWidget {
  const _CutCardsBody({required this.perPage, required this.cards});

  final CutCardsPerPage perPage;
  final List<Widget> cards;

  /// 자를 선 ↔ 카드 여백 (가위 들어갈 자리)
  static const _cutInset = 8.0;

  @override
  Widget build(BuildContext context) {
    final cutColor = context.colors.textPlaceholder;
    return _Grid(
      columns: perPage.columns,
      rows: perPage.rows,
      gap: 0,
      children: [
        for (final card in cards)
          CustomPaint(
            painter: _DashedRectPainter(color: cutColor),
            child: Padding(padding: const EdgeInsets.all(_cutInset), child: card),
          ),
      ],
    );
  }
}

/// 열 × 줄 고정 격자 (빈 칸은 비워 둠 — 마지막 쪽이 덜 차도 카드 크기가 같게)
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.rows, required this.gap, required this.children});

  final int columns;
  final int rows;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) SizedBox(width: gap),
                  Expanded(
                    child: row * columns + column < children.length
                        ? children[row * columns + column]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 자를 선: 칸 테두리 점선 (그림이 아니라 안내선이라 코드로 그림)
class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  static const _dash = 6.0;
  static const _space = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    void dashedLine(Offset from, Offset to) {
      final length = (to - from).distance;
      final direction = (to - from) / length;
      for (var start = 0.0; start < length; start += _dash + _space) {
        final end = (start + _dash).clamp(0, length).toDouble();
        canvas.drawLine(from + direction * start, from + direction * end, paint);
      }
    }

    dashedLine(Offset.zero, Offset(size.width, 0));
    dashedLine(Offset(size.width, 0), Offset(size.width, size.height));
    dashedLine(Offset(size.width, size.height), Offset(0, size.height));
    dashedLine(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) => oldDelegate.color != color;
}
