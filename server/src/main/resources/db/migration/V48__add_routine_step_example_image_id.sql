-- 예시 일과 카드 이미지 id (이슈 #866). 추가 전용: 기존 컬럼·행의 값은 바꾸지 않는다.
--
-- example_image_id: 앱에 번들된 예시 카드 이미지 id. 온보딩 예시 일과 단계만 값이 있고 나머지는 NULL.
-- 옛 서버로 롤백해도 INSERT 가 깨지지 않게 NOT NULL 을 걸지 않는다 (V29 pictogram_id 와 같은 사정).
--
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine_step ADD COLUMN IF NOT EXISTS example_image_id VARCHAR(100);

-- 이미 만들어진 예시 일과 채우기: 예시 일과 제목(ko·en) + 단계 순서 + 단계 문장(ko·en)이 카탈로그와 같은 단계만.
-- 보호자가 제목·문장을 고친 단계는 건드리지 않는다 (값이 NULL 이면 앱은 기존 픽토그램을 그대로 보여준다).
UPDATE routine_step AS step
SET example_image_id = example.image_id
FROM routine AS routine,
  (VALUES
  ('아침 준비', 'Morning routine', 1, '이불을 개요', 'Fold the blanket', 'fold_blanket'),
  ('아침 준비', 'Morning routine', 2, '화장실에 가요', 'Go to the toilet', 'go_to_toilet'),
  ('아침 준비', 'Morning routine', 3, '이를 닦아요', 'Brush your teeth', 'brush_teeth'),
  ('아침 준비', 'Morning routine', 4, '세수해요', 'Wash your face', 'wash_face'),
  ('아침 준비', 'Morning routine', 5, '옷을 입어요', 'Get dressed', 'get_dressed'),
  ('잠자리 준비', 'Bedtime routine', 1, '잠옷을 입어요', 'Put on your pajamas', 'put_on_pajamas'),
  ('잠자리 준비', 'Bedtime routine', 2, '이를 닦아요', 'Brush your teeth', 'brush_teeth'),
  ('잠자리 준비', 'Bedtime routine', 3, '화장실에 가요', 'Go to the toilet', 'go_to_toilet'),
  ('잠자리 준비', 'Bedtime routine', 4, '불 끄고 누워요', 'Turn off the light and lie down', 'lie_down_lights_off'),
  ('등교 준비', 'Getting ready for school', 1, '책을 챙겨요', 'Pack your books', 'gather_books'),
  ('등교 준비', 'Getting ready for school', 2, '가방을 메요', 'Put on your bag', 'wear_backpack'),
  ('등교 준비', 'Getting ready for school', 3, '겉옷을 입어요', 'Put on your coat', 'put_on_coat'),
  ('등교 준비', 'Getting ready for school', 4, '신발을 신어요', 'Put on your shoes', 'put_on_shoes'),
  ('숙제하기', 'Doing homework', 1, '책상에 앉아요', 'Sit at your desk', 'sit_at_desk'),
  ('숙제하기', 'Doing homework', 2, '책을 펴요', 'Open your book', 'open_book'),
  ('숙제하기', 'Doing homework', 3, '숙제를 써요', 'Write your homework', 'write_homework'),
  ('숙제하기', 'Doing homework', 4, '가방에 넣어요', 'Put it in your bag', 'put_book_in_bag'),
  ('장난감 정리', 'Tidying up toys', 1, '장난감을 모아요', 'Gather your toys', 'gather_toys'),
  ('장난감 정리', 'Tidying up toys', 2, '상자에 넣어요', 'Put them in the box', 'put_toys_in_box'),
  ('장난감 정리', 'Tidying up toys', 3, '바닥을 닦아요', 'Wipe the floor', 'wipe_floor'),
  ('식탁 차리기', 'Setting the table', 1, '식탁을 닦아요', 'Wipe the table', 'wipe_table'),
  ('식탁 차리기', 'Setting the table', 2, '수저를 놓아요', 'Set the spoons and chopsticks', 'set_utensils'),
  ('식탁 차리기', 'Setting the table', 3, '앉아서 먹어요', 'Sit down and eat', 'sit_and_eat'),
  ('식탁 차리기', 'Setting the table', 4, '그릇을 갖다 놓아요', 'Take your dishes to the sink', 'take_dishes_to_sink'),
  ('버스 타기', 'Taking the bus', 1, '정류장에 가요', 'Walk to the bus stop', 'walk_to_bus_stop'),
  ('버스 타기', 'Taking the bus', 2, '버스를 기다려요', 'Wait for the bus', 'wait_for_bus'),
  ('버스 타기', 'Taking the bus', 3, '버스에 타요', 'Get on the bus', 'board_bus'),
  ('버스 타기', 'Taking the bus', 4, '자리에 앉아요', 'Sit in a seat', 'sit_on_bus'),
  ('버스 타기', 'Taking the bus', 5, '버스에서 내려요', 'Get off the bus', 'exit_bus'),
  ('가게에서 사기', 'Shopping at a store', 1, '가게에 들어가요', 'Go into the store', 'enter_store'),
  ('가게에서 사기', 'Shopping at a store', 2, '물건을 담아요', 'Put items in the basket', 'put_item_in_basket'),
  ('가게에서 사기', 'Shopping at a store', 3, '줄을 서요', 'Wait in line', 'wait_in_line'),
  ('가게에서 사기', 'Shopping at a store', 4, '돈을 내요', 'Pay with money', 'pay_money')
  ) AS example(title_ko, title_en, step_order, text_ko, text_en, image_id)
WHERE step.routine_id = routine.id
  AND routine.is_example = TRUE
  AND routine.title IN (example.title_ko, example.title_en)
  AND step.step_order = example.step_order
  AND step.title IN (example.text_ko, example.text_en)
  AND step.example_image_id IS NULL;
