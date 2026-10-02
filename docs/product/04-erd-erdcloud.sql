-- 얼쑤 / 에헤라디야 · 목표 ERD v0.7
-- ERDCloud의 DDL 가져오기에 이 파일 전체를 붙여 넣기 (PostgreSQL 문법).
-- 설계 시각화용 DDL이며 현재 Spring Boot DB의 마이그레이션이 아니다.
-- UUID는 애플리케이션에서 생성한다. 모든 시각은 timestamptz(UTC 저장)이다.

-- 1. 회원, 학교, 인증
CREATE TABLE users (
  id uuid PRIMARY KEY,
  status varchar(20) NOT NULL,
  role varchar(20) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE universities (
  id uuid PRIMARY KEY,
  name_ko varchar(150) NOT NULL,
  name_en varchar(150),
  active boolean NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE university_domains (
  domain varchar(255) PRIMARY KEY,
  university_id uuid NOT NULL REFERENCES universities(id),
  verified_by uuid REFERENCES users(id),
  verified_at timestamptz,
  created_at timestamptz NOT NULL
);

CREATE TABLE auth_identities (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  provider varchar(20) NOT NULL,
  provider_subject varchar(255) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  UNIQUE (provider, provider_subject)
);

CREATE TABLE password_credentials (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  login_email varchar(320) NOT NULL UNIQUE,
  password_hash varchar(255) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE sessions (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  refresh_hash varchar(255) NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE verification_challenges (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  purpose varchar(30) NOT NULL,
  email varchar(320) NOT NULL,
  code_hash varchar(255) NOT NULL,
  expires_at timestamptz NOT NULL,
  attempts integer NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE student_verifications (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  school_email varchar(320) NOT NULL,
  university_id uuid REFERENCES universities(id),
  status varchar(30) NOT NULL,
  email_verified_at timestamptz,
  domain_verified_by uuid REFERENCES users(id),
  verified_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  name varchar(80) NOT NULL,
  university_id uuid NOT NULL REFERENCES universities(id),
  nationality_code varchar(3) NOT NULL,
  primary_language varchar(20) NOT NULL,
  secondary_language varchar(20),
  gender varchar(20) NOT NULL,
  ui_locale varchar(5) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE profile_interests (
  user_id uuid NOT NULL REFERENCES users(id),
  interest_code varchar(50) NOT NULL,
  PRIMARY KEY (user_id, interest_code)
);

-- 2. 지역, 카테고리, 이미지
CREATE TABLE cities (
  code varchar(30) PRIMARY KEY,
  official_name varchar(100) NOT NULL,
  display_name_ko varchar(50) NOT NULL,
  display_name_en varchar(50) NOT NULL
);

CREATE TABLE categories (
  id uuid PRIMARY KEY,
  code varchar(50) NOT NULL UNIQUE,
  name_ko varchar(80) NOT NULL,
  name_en varchar(80) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE media_assets (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id),
  purpose varchar(30) NOT NULL,
  source_checksum varchar(128) NOT NULL,
  status varchar(20) NOT NULL,
  publication_status varchar(20) NOT NULL,
  failure_code varchar(80),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE media_variants (
  asset_id uuid NOT NULL REFERENCES media_assets(id),
  kind varchar(20) NOT NULL,
  private_bucket varchar(100) NOT NULL,
  private_key varchar(500) NOT NULL,
  public_bucket varchar(100),
  public_key varchar(500),
  content_type varchar(100) NOT NULL,
  width integer NOT NULL,
  height integer NOT NULL,
  size_bytes bigint NOT NULL,
  PRIMARY KEY (asset_id, kind)
);

-- 3. 이벤트, 공개, 수정 이력
CREATE TABLE events (
  id uuid PRIMARY KEY,
  host_id uuid NOT NULL REFERENCES users(id),
  current_version_id uuid,
  published_version_id uuid,
  publication_status varchar(30) NOT NULL,
  lifecycle_status varchar(30) NOT NULL,
  revision integer NOT NULL,
  published_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE event_versions (
  id uuid PRIMARY KEY,
  event_id uuid NOT NULL REFERENCES events(id),
  version_number integer NOT NULL,
  editing_state varchar(20) NOT NULL,
  title varchar(160),
  thumbnail_asset_id uuid REFERENCES media_assets(id),
  category_id uuid REFERENCES categories(id),
  city_code varchar(30) REFERENCES cities(code),
  venue_name varchar(200),
  address varchar(300),
  latitude numeric(10,7),
  longitude numeric(10,7),
  place_provider varchar(30),
  provider_place_id varchar(255),
  starts_at timestamptz,
  ends_at timestamptz,
  timezone varchar(64) NOT NULL,
  recruitment_start timestamptz,
  recruitment_end timestamptz,
  description_ko text,
  description_en text,
  saved_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  UNIQUE (event_id, version_number),
  UNIQUE (event_id, id),
  CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at),
  CHECK (starts_at IS NULL OR recruitment_end IS NULL OR recruitment_end < starts_at)
);

-- 복합 FK는 참조 버전이 동일 이벤트에 속함을 보장한다.
ALTER TABLE events ADD CONSTRAINT fk_events_current_version
  FOREIGN KEY (id, current_version_id) REFERENCES event_versions(event_id, id);
ALTER TABLE events ADD CONSTRAINT fk_events_published_version
  FOREIGN KEY (id, published_version_id) REFERENCES event_versions(event_id, id);

CREATE TABLE event_quotas (
  version_id uuid NOT NULL,
  quota_group varchar(20) NOT NULL,
  capacity integer NOT NULL,
  PRIMARY KEY (version_id, quota_group),
  CHECK (capacity >= 0)
);


-- 4. 신청, 관심, 후기
CREATE TABLE participations (
  id uuid PRIMARY KEY,
  event_id uuid NOT NULL REFERENCES events(id),
  user_id uuid NOT NULL REFERENCES users(id),
  quota_group varchar(20) NOT NULL,
  nationality_snapshot varchar(3) NOT NULL,
  status varchar(20) NOT NULL,
  attendance varchar(20) NOT NULL,
  confirmed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_source varchar(30),
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  UNIQUE (event_id, user_id),
  UNIQUE (event_id, id)
);

CREATE TABLE participation_history (
  id uuid PRIMARY KEY,
  participation_id uuid NOT NULL REFERENCES participations(id),
  actor_id uuid REFERENCES users(id),
  action varchar(30) NOT NULL,
  reason text,
  created_at timestamptz NOT NULL
);

CREATE TABLE bookmarks (
  user_id uuid NOT NULL REFERENCES users(id),
  event_id uuid NOT NULL REFERENCES events(id),
  created_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, event_id)
);

CREATE TABLE reviews (
  id uuid PRIMARY KEY,
  participation_id uuid NOT NULL UNIQUE REFERENCES participations(id),
  rating integer NOT NULL,
  body text NOT NULL,
  status varchar(20) NOT NULL,
  revision integer NOT NULL,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE review_history (
  id uuid PRIMARY KEY,
  review_id uuid NOT NULL REFERENCES reviews(id),
  actor_id uuid NOT NULL REFERENCES users(id),
  action varchar(20) NOT NULL,
  prior_body text,
  created_at timestamptz NOT NULL
);

-- 5. 댓글, 채팅
CREATE TABLE comment_threads (
  id uuid PRIMARY KEY,
  event_id uuid NOT NULL REFERENCES events(id),
  author_id uuid NOT NULL REFERENCES users(id),
  visibility varchar(20) NOT NULL,
  status varchar(20) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE comments (
  id uuid PRIMARY KEY,
  thread_id uuid NOT NULL REFERENCES comment_threads(id),
  author_id uuid NOT NULL REFERENCES users(id),
  body text NOT NULL,
  status varchar(20) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE conversations (
  id uuid PRIMARY KEY,
  event_id uuid NOT NULL REFERENCES events(id),
  kind varchar(20) NOT NULL,
  participation_id uuid UNIQUE,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  CHECK ((kind = 'announcement' AND participation_id IS NULL)
    OR (kind = 'host_direct' AND participation_id IS NOT NULL)),
  FOREIGN KEY (event_id, participation_id) REFERENCES participations(event_id, id)
);

CREATE TABLE messages (
  id uuid PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES conversations(id),
  sender_id uuid NOT NULL REFERENCES users(id),
  client_message_id uuid NOT NULL,
  body text NOT NULL,
  status varchar(20) NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  UNIQUE (sender_id, client_message_id),
  UNIQUE (conversation_id, id)
);

CREATE TABLE conversation_reads (
  conversation_id uuid NOT NULL REFERENCES conversations(id),
  user_id uuid NOT NULL REFERENCES users(id),
  last_read_message_id uuid,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (conversation_id, user_id),
  FOREIGN KEY (conversation_id, last_read_message_id) REFERENCES messages(conversation_id, id)
);

-- 6. 폐기, 신고, 알림
CREATE TABLE event_dispositions (
  id uuid PRIMARY KEY,
  event_id uuid NOT NULL REFERENCES events(id),
  actor_id uuid NOT NULL REFERENCES users(id),
  kind varchar(20) NOT NULL,
  public_reason text NOT NULL,
  internal_reason text,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE disposition_recipients (
  disposition_id uuid NOT NULL REFERENCES event_dispositions(id),
  user_id uuid NOT NULL REFERENCES users(id),
  event_title_snapshot varchar(160) NOT NULL,
  starts_at_snapshot timestamptz NOT NULL,
  delivered_at timestamptz,
  read_at timestamptz,
  PRIMARY KEY (disposition_id, user_id)
);

CREATE TABLE reports (
  id uuid PRIMARY KEY,
  reporter_id uuid NOT NULL REFERENCES users(id),
  event_id uuid NOT NULL REFERENCES events(id),
  target_type varchar(20) NOT NULL,
  target_id uuid NOT NULL,
  reason_code varchar(30) NOT NULL,
  description text,
  evidence_snapshot text,
  status varchar(20) NOT NULL,
  resolution text,
  resolved_by uuid REFERENCES users(id),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE notifications (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  type varchar(50) NOT NULL,
  target_type varchar(30),
  target_id uuid,
  dedupe_key varchar(255) NOT NULL UNIQUE,
  read_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE notification_settings (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  push_enabled boolean NOT NULL,
  chat_enabled boolean NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE device_tokens (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  session_id uuid NOT NULL REFERENCES sessions(id),
  token varchar(500) NOT NULL UNIQUE,
  platform varchar(20) NOT NULL,
  enabled boolean NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

-- 7. 운영 콘텐츠, 약관, 지원
CREATE TABLE info_cards (
  id uuid PRIMARY KEY,
  author_id uuid NOT NULL REFERENCES users(id),
  kind varchar(20) NOT NULL,
  title_ko varchar(160) NOT NULL,
  title_en varchar(160),
  body_ko text,
  body_en text,
  image_asset_id uuid REFERENCES media_assets(id),
  target_url varchar(1000),
  position integer NOT NULL,
  status varchar(20) NOT NULL,
  starts_at timestamptz,
  ends_at timestamptz,
  revision integer NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE support_tickets (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  subject varchar(200) NOT NULL,
  body text NOT NULL,
  status varchar(20) NOT NULL,
  reply text,
  replied_by uuid REFERENCES users(id),
  replied_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE announcements (
  id uuid PRIMARY KEY,
  author_id uuid NOT NULL REFERENCES users(id),
  title_ko varchar(160) NOT NULL,
  title_en varchar(160),
  body_ko text NOT NULL,
  body_en text,
  published_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE policy_versions (
  id uuid PRIMARY KEY,
  document_type varchar(30) NOT NULL,
  version varchar(30) NOT NULL,
  locale varchar(5) NOT NULL,
  body text NOT NULL,
  effective_at timestamptz NOT NULL,
  required boolean NOT NULL,
  created_at timestamptz NOT NULL,
  UNIQUE (document_type, version, locale)
);

CREATE TABLE consents (
  user_id uuid NOT NULL REFERENCES users(id),
  policy_version_id uuid NOT NULL REFERENCES policy_versions(id),
  accepted_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, policy_version_id)
);

-- 8. 비동기 전송, 멱등, 감사
CREATE TABLE outbox (
  id uuid PRIMARY KEY,
  topic varchar(100) NOT NULL,
  aggregate_id uuid NOT NULL,
  payload text NOT NULL,
  dedupe_key varchar(255) NOT NULL UNIQUE,
  status varchar(20) NOT NULL,
  attempts integer NOT NULL,
  next_attempt_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL
);

CREATE TABLE idempotency_records (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  method varchar(10) NOT NULL,
  path varchar(500) NOT NULL,
  idempotency_key varchar(255) NOT NULL,
  request_hash varchar(128) NOT NULL,
  response text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL,
  UNIQUE (user_id, method, path, idempotency_key)
);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY,
  actor_id uuid REFERENCES users(id),
  action varchar(100) NOT NULL,
  target_type varchar(50) NOT NULL,
  target_id uuid NOT NULL,
  reason text,
  created_at timestamptz NOT NULL
);

-- 조회 및 운영 경로 후보 인덱스
CREATE INDEX idx_events_status_published ON events (publication_status, lifecycle_status, published_at);
CREATE INDEX idx_event_versions_search ON event_versions (city_code, category_id, starts_at);
CREATE INDEX idx_participations_event_group ON participations (event_id, quota_group, status);
CREATE INDEX idx_participations_user_status ON participations (user_id, status);
CREATE INDEX idx_comments_thread_created ON comments (thread_id, created_at);
CREATE INDEX idx_messages_conversation_created ON messages (conversation_id, created_at);
CREATE INDEX idx_disposition_recipients_unread ON disposition_recipients (user_id, read_at);
CREATE INDEX idx_reports_status_created ON reports (status, created_at);
CREATE INDEX idx_outbox_retry ON outbox (status, next_attempt_at);
CREATE UNIQUE INDEX uq_conversations_announcement ON conversations (event_id) WHERE kind = 'announcement';
