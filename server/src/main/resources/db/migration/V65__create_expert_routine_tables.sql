-- 전문가 일과 표 두 개 + 시드 초안 5개 (이슈 #1076). 추가 전용: 기존 표는 건드리지 않는다.
--
-- member·routine 에 외래키를 걸지 않는다 — 가져간 일과는 사본이라 원본과 묶이지 않는다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS · ON CONFLICT DO NOTHING 으로 쓴다.

-- 전문가 일과: 관리자가 검수해 올린 일과 원본. 앱 노출 = is_published + review_status 'REVIEWED'
CREATE TABLE IF NOT EXISTS expert_routine (
  id                VARCHAR(255) NOT NULL PRIMARY KEY,
  title             VARCHAR(100) NOT NULL,
  summary           VARCHAR(200),
  category          VARCHAR(20)  NOT NULL,
  language          VARCHAR(8)   NOT NULL DEFAULT 'ko',
  reward_text       VARCHAR(100),
  reward_preset_key VARCHAR(30),
  review_status     VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
  review_note       TEXT,
  is_published      BOOLEAN      NOT NULL DEFAULT FALSE,
  sort_order        INTEGER      NOT NULL DEFAULT 0,
  step_count        INTEGER      NOT NULL DEFAULT 0,
  import_count      INTEGER      NOT NULL DEFAULT 0,
  updated_by        VARCHAR(100),
  created_at        TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT now()
);
-- 앱 목록: 공개된 일과를 언어별 순서대로
CREATE INDEX IF NOT EXISTS idx_expert_routine_published_language
  ON expert_routine (is_published, language, sort_order);

-- 전문가 일과의 카드: 문장 + 번들 그림 id (픽토그램·예시 이미지)
CREATE TABLE IF NOT EXISTS expert_routine_step (
  id                VARCHAR(255) NOT NULL PRIMARY KEY,
  expert_routine_id VARCHAR(255) NOT NULL,
  step_order        INTEGER      NOT NULL,
  text              VARCHAR(200) NOT NULL,
  pictogram_id      VARCHAR(100),
  example_image_id  VARCHAR(100),
  created_at        TIMESTAMP    NOT NULL DEFAULT now(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_expert_routine_step_routine_order
  ON expert_routine_step (expert_routine_id, step_order);

-- 시드 초안 5개: 픽토그램만 쓴다(앱·서버 pictograms/catalog.json 에 있는 Mulberry id). 검수 전이라 숨김.

INSERT INTO expert_routine (id, title, summary, category, language, reward_text, reward_preset_key, review_status, review_note, is_published, sort_order, step_count)
VALUES ('a1076000-0000-4000-8000-000000000001', '등교 준비', '집에서 나가기 전 준비를 한 장씩 해요', 'DAILY_FLOW', 'ko', '칭찬 스티커', NULL, 'DRAFT', '초안, 전문가 검수 필요. 시드 콘텐츠(#1076): 특수교사·행동분석 전문가가 문장·순서·그림을 검수하기 전에는 공개하지 않아요.', FALSE, 0, 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO expert_routine_step (id, expert_routine_id, step_order, text, pictogram_id)
VALUES
  ('27952609-38e4-5534-89c5-f41ccb2b834d', 'a1076000-0000-4000-8000-000000000001', 0, '옷을 입어요', 'get_dressed_,_to'),
  ('faa03d87-d978-51c6-9c03-84049cc95a09', 'a1076000-0000-4000-8000-000000000001', 1, '가방을 메요', 'school_bag'),
  ('4eee592d-1928-5e8c-9494-f80b716edc71', 'a1076000-0000-4000-8000-000000000001', 2, '겉옷을 입어요', 'put_on_coat_,_to'),
  ('1d6e5927-e682-5da8-a955-0bf621e43f59', 'a1076000-0000-4000-8000-000000000001', 3, '신발을 신어요', 'shoe_-_mans'),
  ('84663104-7b4c-5e02-a32a-3b5732877b53', 'a1076000-0000-4000-8000-000000000001', 4, '문을 열고 나가요', 'exit_door_,_to')
ON CONFLICT (id) DO NOTHING;

INSERT INTO expert_routine (id, title, summary, category, language, reward_text, reward_preset_key, review_status, review_note, is_published, sort_order, step_count)
VALUES ('a1076000-0000-4000-8000-000000000002', '병원 가기', '처음 가는 병원도 순서를 알면 덜 낯설어요', 'COMMUNITY', 'ko', '좋아하는 간식', 'SNACK', 'DRAFT', '초안, 전문가 검수 필요. 시드 콘텐츠(#1076): 특수교사·행동분석 전문가가 문장·순서·그림을 검수하기 전에는 공개하지 않아요.', FALSE, 10, 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO expert_routine_step (id, expert_routine_id, step_order, text, pictogram_id)
VALUES
  ('cb20a971-fe2c-524f-95b4-761023f9d2fa', 'a1076000-0000-4000-8000-000000000002', 0, '차를 타고 병원에 가요', 'car'),
  ('b2be9620-2a2a-5bd4-8837-e0de37a90638', 'a1076000-0000-4000-8000-000000000002', 1, '병원에 들어가요', 'enter_door_,_to'),
  ('660c7119-a5d7-508d-899c-b3e7abebf5ee', 'a1076000-0000-4000-8000-000000000002', 2, '의자에 앉아 기다려요', 'wait_,_to'),
  ('a055201c-1a3d-5e94-9b3d-5cce083ac85b', 'a1076000-0000-4000-8000-000000000002', 3, '선생님을 만나요', 'sit_,_to'),
  ('79100b92-03bf-55ca-8308-0739566303bc', 'a1076000-0000-4000-8000-000000000002', 4, '약을 받아요', 'medicine'),
  ('c67f4907-4a71-5460-ae13-7d545ca1638b', 'a1076000-0000-4000-8000-000000000002', 5, '손을 씻어요', 'wash_hands_,_to')
ON CONFLICT (id) DO NOTHING;

INSERT INTO expert_routine (id, title, summary, category, language, reward_text, reward_preset_key, review_status, review_note, is_published, sort_order, step_count)
VALUES ('a1076000-0000-4000-8000-000000000003', '미용실 가기', '머리 자르는 동안 할 일을 미리 봐요', 'COMMUNITY', 'ko', '좋아하는 놀이', 'PLAY', 'DRAFT', '초안, 전문가 검수 필요. 시드 콘텐츠(#1076): 특수교사·행동분석 전문가가 문장·순서·그림을 검수하기 전에는 공개하지 않아요.', FALSE, 20, 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO expert_routine_step (id, expert_routine_id, step_order, text, pictogram_id)
VALUES
  ('d506a979-a166-5d99-b344-77ae703d45bf', 'a1076000-0000-4000-8000-000000000003', 0, '미용실에 들어가요', 'enter_door_,_to'),
  ('6306e629-4cb2-5a77-973f-faf7e4083a68', 'a1076000-0000-4000-8000-000000000003', 1, '의자에 앉아요', 'chair'),
  ('288c57d9-932d-5a8f-94f3-a3411d565515', 'a1076000-0000-4000-8000-000000000003', 2, '거울을 봐요', 'look_in_mirror_,_to'),
  ('f3c8fd16-01ad-5289-87ec-5de311abbb88', 'a1076000-0000-4000-8000-000000000003', 3, '머리를 잘라요', 'haircut'),
  ('7bdc5cc9-2501-57ef-a408-4245ec42a190', 'a1076000-0000-4000-8000-000000000003', 4, '머리를 빗어요', 'brush_hair_,_to')
ON CONFLICT (id) DO NOTHING;

INSERT INTO expert_routine (id, title, summary, category, language, reward_text, reward_preset_key, review_status, review_note, is_published, sort_order, step_count)
VALUES ('a1076000-0000-4000-8000-000000000004', '손 씻기', '밖에 다녀오면 손을 씻어요', 'SELF_CARE', 'ko', '칭찬 스티커', NULL, 'DRAFT', '초안, 전문가 검수 필요. 시드 콘텐츠(#1076): 특수교사·행동분석 전문가가 문장·순서·그림을 검수하기 전에는 공개하지 않아요.', FALSE, 30, 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO expert_routine_step (id, expert_routine_id, step_order, text, pictogram_id)
VALUES
  ('97d70924-135e-5de7-a7ef-663f3fa2e0c6', 'a1076000-0000-4000-8000-000000000004', 0, '손을 씻어요', 'wash_hands_,_to'),
  ('2b2f7ed8-f82a-553f-8690-1e4f85c77b11', 'a1076000-0000-4000-8000-000000000004', 1, '손을 깨끗이 닦아요', 'dry_hands_,_to'),
  ('df2614fa-10c1-569a-96b2-fdc4e4d39743', 'a1076000-0000-4000-8000-000000000004', 2, '박수를 쳐요', 'clap_hands_,_to')
ON CONFLICT (id) DO NOTHING;

INSERT INTO expert_routine (id, title, summary, category, language, reward_text, reward_preset_key, review_status, review_note, is_published, sort_order, step_count)
VALUES ('a1076000-0000-4000-8000-000000000005', '잠자리 준비', '잠들기 전 순서를 매일 같게 해요', 'DAILY_FLOW', 'ko', '좋아하는 놀이', 'PLAY', 'DRAFT', '초안, 전문가 검수 필요. 시드 콘텐츠(#1076): 특수교사·행동분석 전문가가 문장·순서·그림을 검수하기 전에는 공개하지 않아요.', FALSE, 40, 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO expert_routine_step (id, expert_routine_id, step_order, text, pictogram_id)
VALUES
  ('907a965f-a6f0-51d0-af63-321e987b55bf', 'a1076000-0000-4000-8000-000000000005', 0, '잠옷을 입어요', 'pyjamas'),
  ('fe1eb5fd-61f9-54eb-9f10-3432a3f0f05e', 'a1076000-0000-4000-8000-000000000005', 1, '이를 닦아요', 'brush_teeth_,_to'),
  ('5995a389-fd43-541f-a1c0-03a76f478806', 'a1076000-0000-4000-8000-000000000005', 2, '화장실에 가요', 'toilet_,_go_to_the'),
  ('67ad4c2c-082e-521f-b325-4648d302d24b', 'a1076000-0000-4000-8000-000000000005', 3, '불 끄고 누워요', 'bed_time')
ON CONFLICT (id) DO NOTHING;
