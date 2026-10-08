import 'package:flutter/material.dart';

/// 작은 인라인 로딩 스피너.
///
/// [size] 는 호출한 쪽이 화면 비율을 적용한 최종 값이다(`.w` 포함). null 이면 부모가 정한 크기를
/// 따른다. 화면 한 장을 채우는 로딩은 [ElumStateBody.loading] 을 쓴다.
class ElumSpinner extends StatelessWidget {
  const ElumSpinner({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 2,
  });

  final double? size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final spinner = CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
    );
    final size = this.size;
    if (size == null) return spinner;
    return SizedBox(width: size, height: size, child: spinner);
  }
}
