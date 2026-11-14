package com.chuseok22.elumserver.routine.infrastructure.constant;

import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.HOUSE_SELF;
import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.MORNING_EVENING;
import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.OUTSIDE;
import static com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory.SCHOOL_STUDY;

import java.time.LocalTime;
import java.util.List;

/**
 * 온보딩 예시 일과 원본 (#803): 분류 4개 × 2개, 문장 ko·en·ja·zh·es, 카드 이미지 id + 대체 픽토그램
 * AI·크레딧 없이 그대로 일과가 된다. 순서 = 분류 순서 > 예시 순서 (홈 표시 순서)
 */
public final class RoutineExampleCatalog {

  public static final List<RoutineExample> ALL = List.of(
    new RoutineExample(MORNING_EVENING, text("아침 준비", "Morning routine", "朝の準備", "早上的准备", "Rutina de la mañana"), LocalTime.of(7, 30), List.of(
      step(text("이불을 개요", "Fold the blanket", "ふとんをたたみます", "叠好被子", "Dobla la manta"), "make_the_bed_,_to", "fold_blanket"),
      step(text("화장실에 가요", "Go to the toilet", "トイレに行きます", "去上厕所", "Ve al baño"), "toilet_,_go_to_the", "go_to_toilet"),
      step(text("이를 닦아요", "Brush your teeth", "歯をみがきます", "刷牙", "Cepíllate los dientes"), "brush_teeth_,_to", "brush_teeth"),
      step(text("세수해요", "Wash your face", "顔を洗います", "洗脸", "Lávate la cara"), "wash_face_,_to", "wash_face"),
      step(text("옷을 입어요", "Get dressed", "服を着ます", "穿衣服", "Vístete"), "get_dressed_,_to", "get_dressed"))),
    new RoutineExample(MORNING_EVENING, text("잠자리 준비", "Bedtime routine", "寝る準備", "睡前准备", "Rutina para dormir"), LocalTime.of(21, 0), List.of(
      step(text("잠옷을 입어요", "Put on your pajamas", "パジャマを着ます", "穿睡衣", "Ponte la pijama"), "pyjamas", "put_on_pajamas"),
      step(text("이를 닦아요", "Brush your teeth", "歯をみがきます", "刷牙", "Cepíllate los dientes"), "brush_teeth_,_to", "brush_teeth"),
      step(text("화장실에 가요", "Go to the toilet", "トイレに行きます", "去上厕所", "Ve al baño"), "toilet_,_go_to_the", "go_to_toilet"),
      step(text("불 끄고 누워요", "Turn off the light and lie down", "電気を消して横になります", "关灯躺下", "Apaga la luz y acuéstate"), "bed_time", "lie_down_lights_off"))),
    new RoutineExample(SCHOOL_STUDY, text("등교 준비", "Getting ready for school", "登校の準備", "上学准备", "Prepararse para la escuela"), LocalTime.of(8, 0), List.of(
      step(text("책을 챙겨요", "Pack your books", "本を用意します", "收拾好书", "Guarda tus libros"), "carry_books_,_to", "gather_books"),
      step(text("가방을 메요", "Put on your bag", "かばんを背負います", "背上书包", "Ponte la mochila"), "school_bag", "wear_backpack"),
      step(text("겉옷을 입어요", "Put on your coat", "上着を着ます", "穿外套", "Ponte el abrigo"), "put_on_coat_,_to", "put_on_coat"),
      step(text("신발을 신어요", "Put on your shoes", "くつをはきます", "穿鞋", "Ponte los zapatos"), "shoe_-_mans", "put_on_shoes"))),
    new RoutineExample(SCHOOL_STUDY, text("숙제하기", "Doing homework", "宿題", "写作业", "Hacer la tarea"), LocalTime.of(16, 0), List.of(
      step(text("책상에 앉아요", "Sit at your desk", "机にすわります", "坐到书桌前", "Siéntate en tu escritorio"), "desk", "sit_at_desk"),
      step(text("책을 펴요", "Open your book", "本を開きます", "打开书", "Abre tu libro"), "read_book_,_to", "open_book"),
      step(text("숙제를 써요", "Write your homework", "宿題を書きます", "写作业", "Escribe tu tarea"), "write_,_to", "write_homework"),
      step(text("가방에 넣어요", "Put it in your bag", "かばんに入れます", "放进书包", "Guárdalo en tu mochila"), "school_bag", "put_book_in_bag"))),
    new RoutineExample(HOUSE_SELF, text("장난감 정리", "Tidying up toys", "おもちゃの片づけ", "整理玩具", "Ordenar los juguetes"), LocalTime.of(18, 0), List.of(
      step(text("장난감을 모아요", "Gather your toys", "おもちゃを集めます", "把玩具收在一起", "Junta tus juguetes"), "tidy_up_,_to", "gather_toys"),
      step(text("상자에 넣어요", "Put them in the box", "箱に入れます", "放进箱子", "Guárdalos en la caja"), "box_,_to", "put_toys_in_box"),
      // 바닥 닦기 픽토그램이 없어 닦기 그림을 빌려 씀 (구 앱 대체용, 새 앱은 예시 이미지)
      step(text("바닥을 닦아요", "Wipe the floor", "床をふきます", "擦地板", "Limpia el piso"), "wipe_table_,_to", "wipe_floor"))),
    new RoutineExample(HOUSE_SELF, text("식탁 차리기", "Setting the table", "食卓の準備", "摆餐桌", "Poner la mesa"), LocalTime.of(18, 30), List.of(
      step(text("식탁을 닦아요", "Wipe the table", "テーブルをふきます", "擦桌子", "Limpia la mesa"), "wipe_table_,_to", "wipe_table"),
      step(text("수저를 놓아요", "Set the spoons and chopsticks", "スプーンとはしを置きます", "摆好勺子和筷子", "Pon los cubiertos"), "set_the_table_,_to", "set_utensils"),
      step(text("앉아서 먹어요", "Sit down and eat", "すわって食べます", "坐下吃饭", "Siéntate y come"), "sit_,_to", "sit_and_eat"),
      step(text("그릇을 갖다 놓아요", "Take your dishes to the sink", "食器を流しに運びます", "把碗送到水池", "Lleva tus platos al fregadero"), "wash_up_,_to", "take_dishes_to_sink"))),
    new RoutineExample(OUTSIDE, text("버스 타기", "Taking the bus", "バスに乗る", "坐公交车", "Tomar el autobús"), LocalTime.of(10, 0), List.of(
      step(text("정류장에 가요", "Walk to the bus stop", "バス停に行きます", "走到车站", "Camina a la parada"), "walk_,_to", "walk_to_bus_stop"),
      step(text("버스를 기다려요", "Wait for the bus", "バスを待ちます", "等公交车", "Espera el autobús"), "wait_,_to", "wait_for_bus"),
      step(text("버스에 타요", "Get on the bus", "バスに乗ります", "上车", "Súbete al autobús"), "get_on_bus_,_to", "board_bus"),
      step(text("자리에 앉아요", "Sit in a seat", "席にすわります", "找座位坐下", "Siéntate en un asiento"), "sit_,_to", "sit_on_bus"),
      step(text("버스에서 내려요", "Get off the bus", "バスを降ります", "下车", "Bájate del autobús"), "get_off_bus_,_to", "exit_bus"))),
    new RoutineExample(OUTSIDE, text("가게에서 사기", "Shopping at a store", "お店で買う", "在商店买东西", "Comprar en la tienda"), LocalTime.of(15, 0), List.of(
      step(text("가게에 들어가요", "Go into the store", "お店に入ります", "走进商店", "Entra a la tienda"), "shop", "enter_store"),
      step(text("물건을 담아요", "Put items in the basket", "品物をかごに入れます", "把东西放进篮子", "Pon las cosas en la canasta"), "basket", "put_item_in_basket"),
      step(text("줄을 서요", "Wait in line", "列にならびます", "排队", "Haz fila"), "queue_,_to", "wait_in_line"),
      step(text("돈을 내요", "Pay with money", "お金をはらいます", "付钱", "Paga con dinero"), "purse", "pay_money")))
  );

  private RoutineExampleCatalog() {
  }

  /** 분류 > 그 분류의 예시 (카탈로그 순서 유지) */
  public static List<RoutineExample> of(RoutineExampleCategory category) {
    return ALL.stream().filter(example -> example.category() == category).toList();
  }

  private static RoutineExampleStep step(LocalizedText text, String pictogramId, String exampleImageId) {
    return new RoutineExampleStep(text, pictogramId, exampleImageId);
  }

  /** 문장 다섯 언어 (ko, en, ja, zh, es) */
  private static LocalizedText text(String ko, String en, String ja, String zh, String es) {
    return new LocalizedText(ko, en, ja, zh, es);
  }
}
