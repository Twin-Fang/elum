-- member.nickname_changed_at: 보호자가 닉네임을 직접 바꾼 마지막 시각. null 이면 바꾼 적 없음(첫 변경은 제한 없음)
ALTER TABLE member ADD COLUMN IF NOT EXISTS nickname_changed_at TIMESTAMP NULL;
