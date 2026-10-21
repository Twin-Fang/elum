import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 일과관리 격자 칸 자리 계산: 칸 상자, 좌표 > 칸 번호, 끄는 칸이 들어갈 자리 · 묶을 칸
///
/// 좌표는 모두 격자 내용(스크롤 안) 기준. 위젯 없이 계산만 한다.
class LibraryGridGeometry {
  const LibraryGridGeometry({
    required this.columns,
    required this.tileWidth,
    required this.tileHeight,
    required this.iconSize,
    required this.spacingX,
    required this.spacingY,
    required this.paddingLeft,
    required this.paddingTop,
  });

  final int columns;
  final double tileWidth;
  final double tileHeight;

  /// 칸 위쪽 가운데 그림 한 변 (묶기 판정 자리)
  final double iconSize;
  final double spacingX;
  final double spacingY;
  final double paddingLeft;
  final double paddingTop;

  /// 그림 가운데에서 이 비율(그림 한 변 기준) 안에 들어오면 묶기로 본다 (그 밖은 자리 옮기기)
  static const mergeRadiusFraction = 0.5;

  double get _strideX => tileWidth + spacingX;
  double get _strideY => tileHeight + spacingY;

  /// [index] 번째 자리의 칸 상자
  Rect slotRect(int index) {
    final row = index ~/ columns;
    final column = index % columns;
    return Rect.fromLTWH(
      paddingLeft + column * _strideX,
      paddingTop + row * _strideY,
      tileWidth,
      tileHeight,
    );
  }

  /// 칸 [count] 개를 다 그린 내용 높이 (아래 여백 [paddingBottom] 포함)
  double contentHeight(int count, double paddingBottom) {
    final rows = count == 0 ? 0 : (count - 1) ~/ columns + 1;
    final tilesHeight = rows == 0 ? 0.0 : rows * _strideY - spacingY;
    return paddingTop + tilesHeight + paddingBottom;
  }

  /// [point] 가 가장 가까이 있는 자리 번호 (0 ~ [slotCount]-1)
  int slotIndexAt(Offset point, int slotCount) {
    if (slotCount <= 0) return 0;
    final column = ((point.dx - paddingLeft + spacingX / 2) / _strideX)
        .floor()
        .clamp(0, columns - 1);
    final row = math.max(
      0,
      ((point.dy - paddingTop + spacingY / 2) / _strideY).floor(),
    );
    return math.min(row * columns + column, slotCount - 1);
  }

  /// [index] 자리 칸 그림의 가운데
  Offset iconCenterOf(int index) {
    final rect = slotRect(index);
    return Offset(rect.center.dx, rect.top + iconSize / 2);
  }

  /// 끄는 칸의 그림 가운데([draggedIconCenter])가 [index] 칸 그림 위에 겹쳤는가
  bool isOverIcon(Offset draggedIconCenter, int index) {
    final distance = (draggedIconCenter - iconCenterOf(index)).distance;
    return distance < iconSize * mergeRadiusFraction;
  }

  /// 끄는 동안 다음 상태: 빈자리 위 > 그대로, 칸 그림 위 > 묶기, 그 밖 > 빈자리를 그 칸 자리로
  /// (빈자리를 옮기면 손가락이 곧 빈자리 위라 깜빡이지 않음)
  LibraryGridHover resolveHover({
    required Offset draggedIconCenter,
    required int otherCount,
    required int gap,
    required bool canMerge,
  }) {
    final slot = slotIndexAt(draggedIconCenter, otherCount + 1);
    if (slot == gap) return LibraryGridHover(gap: gap);
    final otherIndex = slot < gap ? slot : slot - 1;
    if (canMerge && isOverIcon(draggedIconCenter, slot)) {
      return LibraryGridHover(gap: gap, mergeOtherIndex: otherIndex);
    }
    return LibraryGridHover(gap: slot);
  }
}

/// 끄는 동안의 자리 상태: 빈자리 번호 + (겹쳤으면) 묶을 칸의 나머지 목록 번호
class LibraryGridHover {
  const LibraryGridHover({required this.gap, this.mergeOtherIndex});

  final int gap;
  final int? mergeOtherIndex;

  @override
  bool operator ==(Object other) =>
      other is LibraryGridHover &&
      other.gap == gap &&
      other.mergeOtherIndex == mergeOtherIndex;

  @override
  int get hashCode => Object.hash(gap, mergeOtherIndex);
}
