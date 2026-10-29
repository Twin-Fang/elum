-- 이야기 글 공개 범위: PUBLIC(피드에 보임) / LINK_ONLY(링크를 가진 사람만) (이슈 #1002).
--
-- 기존 글은 DEFAULT 'PUBLIC' 으로 모두 공개 글이 된다.
-- 링크 글은 분류를 받지 않아 category 를 NULL 허용으로 푼다.
-- 유니크: 보이는 글은 원본 일과당 하나 -> (원본 일과, 공개 범위)당 하나. 같은 일과에 공개 글 하나 + 링크 글 하나가 함께 있을 수 있다.
--
-- 옛 서버 이미지로 되돌려도 피드·인기는 category IN (...) 으로 읽어 분류가 NULL 인 링크 글이 빠진다.
-- 되돌린 동안 같은 일과의 공개 글 올리기는 링크 글 때문에 TALK_ALREADY_SHARED 가 날 수 있다.
ALTER TABLE talk_post ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) NOT NULL DEFAULT 'PUBLIC';
ALTER TABLE talk_post ALTER COLUMN category DROP NOT NULL;

DROP INDEX IF EXISTS uk_talk_post_visible_source;
CREATE UNIQUE INDEX IF NOT EXISTS uk_talk_post_visible_source
  ON talk_post (source_routine_id, visibility) WHERE status = 'VISIBLE';
