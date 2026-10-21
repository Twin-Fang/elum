package com.chuseok22.elumserver.routine.infrastructure.constant;

import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.HOUSE_SELF;
import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.MORNING_EVENING;
import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.OUTSIDE;
import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.SCHOOL_STUDY;

import java.time.LocalTime;
import java.util.List;

/**
 * 온보딩 예시 일과 원본 (#803): 분류 4개 × 2개, 문장 ko·en, 카드 이미지 id + 대체 픽토그램
 * AI·크레딧 없이 그대로 일과가 된다. 순서 = 분류 순서 > 예시 순서 (홈 표시 순서)
 */
public final class RoutineExampleCatalog {

  public static final List<RoutineExample> ALL = List.of(
    new RoutineExample(MORNING_EVENING, "아침 준비", "Morning routine", LocalTime.of(7, 30), List.of(
      step("이불을 개요", "Fold the blanket", "make_the_bed_,_to", "fold_blanket"),
      step("화장실에 가요", "Go to the toilet", "toilet_,_go_to_the", "go_to_toilet"),
      step("이를 닦아요", "Brush your teeth", "brush_teeth_,_to", "brush_teeth"),
      step("세수해요", "Wash your face", "wash_face_,_to", "wash_face"),
      step("옷을 입어요", "Get dressed", "get_dressed_,_to", "get_dressed"))),
    new RoutineExample(MORNING_EVENING, "잠자리 준비", "Bedtime routine", LocalTime.of(21, 0), List.of(
      step("잠옷을 입어요", "Put on your pajamas", "pyjamas", "put_on_pajamas"),
      step("이를 닦아요", "Brush your teeth", "brush_teeth_,_to", "brush_teeth"),
      step("화장실에 가요", "Go to the toilet", "toilet_,_go_to_the", "go_to_toilet"),
      step("불 끄고 누워요", "Turn off the light and lie down", "bed_time", "lie_down_lights_off"))),
    new RoutineExample(SCHOOL_STUDY, "등교 준비", "Getting ready for school", LocalTime.of(8, 0), List.of(
      step("책을 챙겨요", "Pack your books", "carry_books_,_to", "gather_books"),
      step("가방을 메요", "Put on your bag", "school_bag", "wear_backpack"),
      step("겉옷을 입어요", "Put on your coat", "put_on_coat_,_to", "put_on_coat"),
      step("신발을 신어요", "Put on your shoes", "shoe_-_mans", "put_on_shoes"))),
    new RoutineExample(SCHOOL_STUDY, "숙제하기", "Doing homework", LocalTime.of(16, 0), List.of(
      step("책상에 앉아요", "Sit at your desk", "desk", "sit_at_desk"),
      step("책을 펴요", "Open your book", "read_book_,_to", "open_book"),
      step("숙제를 써요", "Write your homework", "write_,_to", "write_homework"),
      step("가방에 넣어요", "Put it in your bag", "school_bag", "put_book_in_bag"))),
    new RoutineExample(HOUSE_SELF, "장난감 정리", "Tidying up toys", LocalTime.of(18, 0), List.of(
      step("장난감을 모아요", "Gather your toys", "tidy_up_,_to", "gather_toys"),
      step("상자에 넣어요", "Put them in the box", "box_,_to", "put_toys_in_box"),
      // 바닥 닦기 픽토그램이 없어 닦기 그림을 빌려 씀 (구 앱 대체용, 새 앱은 예시 이미지)
      step("바닥을 닦아요", "Wipe the floor", "wipe_table_,_to", "wipe_floor"))),
    new RoutineExample(HOUSE_SELF, "식탁 차리기", "Setting the table", LocalTime.of(18, 30), List.of(
      step("식탁을 닦아요", "Wipe the table", "wipe_table_,_to", "wipe_table"),
      step("수저를 놓아요", "Set the spoons and chopsticks", "set_the_table_,_to", "set_utensils"),
      step("앉아서 먹어요", "Sit down and eat", "sit_,_to", "sit_and_eat"),
      step("그릇을 갖다 놓아요", "Take your dishes to the sink", "wash_up_,_to", "take_dishes_to_sink"))),
    new RoutineExample(OUTSIDE, "버스 타기", "Taking the bus", LocalTime.of(10, 0), List.of(
      step("정류장에 가요", "Walk to the bus stop", "walk_,_to", "walk_to_bus_stop"),
      step("버스를 기다려요", "Wait for the bus", "wait_,_to", "wait_for_bus"),
      step("버스에 타요", "Get on the bus", "get_on_bus_,_to", "board_bus"),
      step("자리에 앉아요", "Sit in a seat", "sit_,_to", "sit_on_bus"),
      step("버스에서 내려요", "Get off the bus", "get_off_bus_,_to", "exit_bus"))),
    new RoutineExample(OUTSIDE, "가게에서 사기", "Shopping at a store", LocalTime.of(15, 0), List.of(
      step("가게에 들어가요", "Go into the store", "shop", "enter_store"),
      step("물건을 담아요", "Put items in the basket", "basket", "put_item_in_basket"),
      step("줄을 서요", "Wait in line", "queue_,_to", "wait_in_line"),
      step("돈을 내요", "Pay with money", "purse", "pay_money")))
  );

  private RoutineExampleCatalog() {
  }

  /** 분류 > 그 분류의 예시 (카탈로그 순서 유지) */
  public static List<RoutineExample> of(RoutineExampleCategory category) {
    return ALL.stream().filter(example -> example.category() == category).toList();
  }

  private static RoutineExampleStep step(String textKo, String textEn, String pictogramId, String exampleImageId) {
    return new RoutineExampleStep(textKo, textEn, pictogramId, exampleImageId);
  }
}
