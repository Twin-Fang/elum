/// 서버가 예시 일과 카드마다 내려주는 `exampleImageId` 의 허용 목록.
///
/// 파일은 `assets/images/example_routines/{id}.webp` 31장이다. 서버가 앞서 새 id 를 내려줘도
/// (앱 업데이트 전) **없는 자산을 그리려다 깨지지 않게** 여기서 걸러 null 로 돌린다 —
/// 그러면 카드는 픽토그램·기본 카드로 나온다.
abstract final class ExampleCardImageCatalog {
  static const _ids = <String>{
    'board_bus',
    'brush_teeth',
    'enter_store',
    'exit_bus',
    'fold_blanket',
    'gather_books',
    'gather_toys',
    'get_dressed',
    'go_to_toilet',
    'lie_down_lights_off',
    'open_book',
    'pay_money',
    'put_book_in_bag',
    'put_item_in_basket',
    'put_on_coat',
    'put_on_pajamas',
    'put_on_shoes',
    'put_toys_in_box',
    'set_utensils',
    'sit_and_eat',
    'sit_at_desk',
    'sit_on_bus',
    'take_dishes_to_sink',
    'wait_for_bus',
    'wait_in_line',
    'walk_to_bus_stop',
    'wash_face',
    'wear_backpack',
    'wipe_floor',
    'wipe_table',
    'write_homework',
  };

  /// 번들에 있는 id 인가.
  static bool contains(String id) => _ids.contains(id);

  /// 서버 JSON 값을 id 로 읽는다. 없거나 문자열이 아니거나 목록에 없으면 null.
  ///
  /// 이 앱은 응답이 어떻게 오든 죽지 않아야 하므로 예외를 던지지 않는다.
  static String? parse(Object? raw) {
    if (raw is! String) return null;
    final id = raw.trim();
    return contains(id) ? id : null;
  }
}
