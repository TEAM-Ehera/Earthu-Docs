---
title: "얼쑤 백엔드 폴더 구조와 내부 아키텍처"
aliases: ["얼쑤 백엔드 구조", "얼쑤 API 아키텍처"]
service: "얼쑤"
team: "에헤라디야"
type: "architecture"
version: "1.1"
status: "기능별 패키지 정리 반영 · Service 분리 예정"
created: "2026-10-01"
updated: "2026-10-01"
tags: ["얼쑤", "개발/백엔드", "개발/아키텍처"]
---

# 얼쑤 백엔드 폴더 구조와 내부 아키텍처

관련: [구현 현황과 다음 개발](08-work-status.md) · [API 설계](05-api-spec.md) · [ERD 설계](04-erd.md) · [배포](07-tech-stack.md)

> [!important] 현재 아키텍처
> Java 21 / Spring Boot 4.1.1 기반 단일 애플리케이션이다. 기능별 패키지로 코드를 정리했지만 대부분의 업무 검증·JPA 호출은 아직 Controller에 있다. 현재 Service는 세션 처리이며, 전 기능이 Controller → Service → Repository로 분리된 구조는 아니다.

## 1. 실제 폴더 구조

```text
eolssu-api/
├── src/main/java/kr/eolssu/api/
│   ├── EolssuApiApplication.java       # 실행·하위 패키지 탐색 시작점
│   ├── config/
│   │   ├── ApiConfig.java             # 웹 origin·CORS
│   ├── auth/
│   │   ├── AuthController.java        # 가입·코드·로그인·프로필·내 목록
│   │   ├── SessionService.java        # JWT/refresh 쿠키 발급·조회·삭제
│   │   ├── MemberSession.java
│   │   └── MemberSessionRepository.java
│   ├── member/
│   │   ├── Member.java
│   │   └── MemberRepository.java
│   ├── event/
│   │   ├── Event.java
│   │   ├── EventRepository.java
│   │   ├── EventController.java        # 작성·공개 목록·상세
│   │   └── EventInteractionController.java # 관심·참여·댓글·후기
│   ├── participation/
│   │   ├── EventParticipation.java
│   │   └── EventParticipationRepository.java
│   ├── favorite/
│   │   ├── EventFavorite.java
│   │   └── EventFavoriteRepository.java
│   ├── comment/
│   │   ├── EventComment.java
│   │   └── EventCommentRepository.java
│   ├── review/
│   │   ├── EventReview.java
│   │   └── EventReviewRepository.java
│   ├── report/
│   │   ├── ContentReport.java
│   │   ├── ContentReportRepository.java
│   │   └── ReportController.java
│   ├── media/
│   │   └── MediaController.java        # 로컬 이미지 저장·조회
│   └── demo/
│       ├── DemoEvents.java            # 샘플 데이터
│       └── LocalReportReviewController.java
├── src/main/resources/
│   ├── application.properties
│   ├── application-{local,docker,dev,prod}.properties
│   ├── db/migration/V1__initial_schema.sql
│   ├── db/migration/V2__publish_events_without_review.sql
│   └── mail/school-verification.html
├── src/test/java/kr/eolssu/api/
│   ├── EolssuApiApplicationTests.java
│   └── ProductionPackageIsolationTests.java
├── Dockerfile
├── compose.yaml
├── compose.deploy.yaml
├── compose.dev.yaml
├── compose.deploy-api.yaml
├── compose.deploy-db.yaml
├── deploy/
│   ├── README.md
│   ├── deployment.env.example
│   └── Caddyfile
├── ARCHITECTURE.md
└── pom.xml
```

기능별 패키지 11개, Java 파일 27개다. 시연 승인 Controller를 삭제하고 local/docker의 기존 상태 변환 컴포넌트를 config에 추가했다. 패키지 이동은 DB 스키마 변경이 아니다. 최상위 실행 클래스가 하위 패키지를 탐색하므로 별도의 컴포넌트·엔티티 탐색 경로 지정은 필요하지 않다.

## 2. 책임과 현재 의존 관계

| 구성 | 역할 | 현재 의존 |
|---|---|---|
| Controller | HTTP 입력·검증·상태 코드·응답, 현재 업무 로직도 담당 | SessionService, 여러 Repository, SMTP 또는 파일 시스템 |
| SessionService | 세션 토큰 발급/검증/회수 | MemberSessionRepository |
| Repository | JPA 조회·저장·삭제·참여 잠금 | Entity / DB |
| Entity | 실제 8개 테이블 매핑 | 대부분 공개 필드. UUID 관계 중심 |
| config | CORS | 환경 설정 |
| demo | 시연 데이터·검토 경로 | EventController, Event/Report Repository. local/docker 한정 |

실제 흐름은 `웹 → Controller → Repository → DB`, 인증은 `Controller → SessionService → MemberSessionRepository`다. 메일은 `AuthController → JavaMailSender`, 이미지는 `MediaController → 파일 시스템`으로 처리한다.

현재 결합이 큰 지점:

- `AuthController`: 인증 외에 프로필과 내 모임/관심/참여 조회까지 처리한다.
- `EventInteractionController`: 관심·참여·댓글·후기 네 기능이 하나에 있다.
- `ReportController`: 신고 대상·댓글 접근 권한을 직접 검사한다. 댓글 권한과 중복될 여지가 있다.
- 요청/응답 DTO는 Controller 안의 `record`다. 모임 응답은 Entity를 직접 반환한다. `Map.of("data", ...)`와 직접 반환 응답이 혼재한다.

## 3. 주요 동작 흐름

### 학교 메일 가입과 세션

1. 주소를 trim/lowercase로 정규화하고 `.ac.kr`·`.edu` 접미사를 검사한다. 알려진 학교 도메인은 대학명을 매핑한다.
2. 이메일 중복·비밀번호 길이를 검사하고 BCrypt 해시를 생성한다.
3. 6자리 코드를 HTML/텍스트 메일로 전송한다. SMTP 오류는 503이다. 성공 후 코드 해시·유효 시간·시도 횟수를 저장한다.
4. 인증 시 10분 만료·5회 제한을 검사하고 학교 인증 상태를 갱신한다.
5. SessionService가 refresh용 무작위 32바이트 토큰과 JwtService의 15분 HS256 접근 JWT를 발급한다. DB에는 refresh의 SHA-256 해시를 저장한다.
6. eolssu_session JWT와 eolssu_refresh 쿠키는 HttpOnly·SameSite=Lax이며 dev/prod에서 Secure=true다. DB 세션은 7일 절대 만료, JWT는 15분 만료 후 refresh 쿠키로 자동 재발급한다.
7. 프로필 작성 후 참여/생성을 허용한다. 로그인 시 프로필 미완료 회원은 웹에서 프로필 페이지로 이동한다.

JWT 서명·issuer·audience·만료와 DB 세션을 함께 검사한다. 로그아웃 시 DB 세션을 폐기한다. 자세한 동작은 [13-host-auth-monitoring](13-host-auth-monitoring.md)를 따른다. Spring Security 인증 필터 체인은 없으며 각 Controller가 세션과 권한을 검사한다. BCrypt 라이브러리 사용만으로 경로 전체가 보호되는 것은 아니다. CSRF·인증 요청 제한은 2026-10-03 소스에 구현했으며 운영 배포·프록시 IP 검증은 대기 중이다. 전체 세션 회수는 별도 계정 관리 작업에서 다룬다.

### 모임 작성과 공개

`인증·프로필 검사 → 일정/설명/정원 검증 → 호스트 정보 서버 설정 → published 저장·즉시 공개`

공개 목록과 상세는 `published`만 반환한다. 호스트 이름·대학·국적은 이벤트에 스냅샷으로 저장한다. 심사와 승인 API는 제거했다. 기존 승인·대기 상태는 Flyway V2 또는 local/docker 초기 변환으로 공개한다.

### 참여와 정원

`인증·프로필 → 트랜잭션 → 이벤트 PESSIMISTIC_WRITE 잠금 → 공개/기한/호스트/정원 검사 → active 참여 저장`

- `(event_id, member_id)` 유일 제약으로 계정당 참여 1행을 유지한다.
- 이미 active면 중복 생성하지 않는다. 취소 후 재참여는 기존 행을 active로 되돌린다.
- 현재 한국 국적 별칭 문자열은 korean, 나머지는 international로 분류한다. 국제학생 자격의 운영 검증은 아니다.
- 취소는 시작 전 가능하며 cancelled로 기록한다. 취소 트랜잭션에는 참여와 같은 이벤트 행 잠금이 없으므로 동시 취소/재참여 검증을 추가해야 한다.

### 댓글·후기·신고

- 공개 댓글은 공개 조회 가능하다. host_only는 작성자·호스트와 해당 답글 문맥의 원글 작성자만 읽을 수 있다.
- 답글은 한 단계이며 원글 공개 범위를 따른다. 작성자 삭제 시 답글이 있으면 삭제 표식을 남긴다.
- 후기는 시작 시간이 지났고 active 참여 이력이 있는 회원이 작성한다. 실제 출석 여부는 검사하지 않는다.
- 신고는 event/comment 대상, 사유 코드와 중복 여부를 검사한다. 로컬 처리의 resolved/dismissed가 모임을 자동 비공개 처리하거나 참여자에게 알림을 보내지는 않는다.

### 이미지

`인증·프로필 → 20MiB/48MP 사전 검증 → 제한된 동시 처리·subsampling → 최대 1600px JPEG 저장 → id/url 반환`

환경별 미디어 10GiB와 디스크 여유 2GiB 보호, 브라우저 자동 압축·캐시를 적용한다. 상세 한계는 [13-host-auth-monitoring](13-host-auth-monitoring.md)를 따른다.

디코딩 뒤 픽셀 수를 검사하므로 큰 이미지의 디코딩 메모리는 별도 개선이 필요하다. 크기 리사이즈는 하지 않는다. Event에는 thumbnailId/thumbnailUrl이 들어가며 실제 파일 소유권이나 존재 여부를 확인하는 미디어 테이블은 없다.

## 4. 실제 데이터 모델

| 테이블 | 주요 책임 | 제약·관계 |
|---|---|---|
| members | 계정·학교 인증·프로필 | email unique |
| member_sessions | 세션 해시·만료 | token_hash unique, member_id FK |
| events | 호스트 스냅샷·모집·일정·설명·이미지 | host_id는 회원 UUID 참조값 |
| event_participations | 그룹·active/cancelled | event_id + member_id unique |
| event_favorites | 관심 | event_id + member_id unique |
| event_comments | 공개 범위·답글·삭제 표식 | event_id·author_id·reply_to_id UUID |
| event_reviews | 별점·본문 | event_id + member_id unique |
| content_reports | 대상·사유·open/resolved/dismissed | reporter_id + target_type + target_id unique |

실제 V1 SQL의 외래키는 세션→회원 연결이다. 나머지는 코드의 논리적 UUID 참조이며 물리 FK로 무결성을 보장하지 않는다. 상태는 문자열이고 enum/DB check 제약은 아직 없다. 필요한 FK·인덱스·상태 제약은 기존 데이터 정리 후 새 마이그레이션으로 추가한다.

## 5. 실행 환경과 배포 경계

| 프로필 | DB/스키마 | 메일·세션 | 시연 기능 |
|---|---|---|---|
| local | 파일 H2, Hibernate update, Flyway off | localhost Mailpit 1025, Secure=false | 포함 |
| docker | PostgreSQL, Hibernate update, Flyway off | Docker Mailpit, Secure=false | 포함 |
| dev | PostgreSQL, validate, Flyway | SMTP 설정, Secure=true | 제외 |
| prod | PostgreSQL, validate, Flyway | SMTP 설정, Secure=true | 제외 |

프로필 이름 dev와 로컬 개발은 다르다. dev는 HTTPS 서버 환경 설정이며 개발 VM 구축 여부와 별개다. `local`/`docker`는 관리자 인증 없는 시연 경로와 샘플 데이터가 있어 외부 운영 배포에 사용하지 않는다.

현재 배포 요청 경로:

`브라우저 → Vercel Next.js /v1 전달 → Oracle API VM Caddy HTTPS → Spring Boot → Oracle DB VM 내부 5432`

Gmail SMTP는 API가 연결하고 이미지는 현재 API의 파일 volume에 저장한다. Vercel rewrites는 API 전달 설정이며 별도 인증·정책 Gateway가 아니다. 개발·운영 연결을 완료했다. 개발 API는 dev 프로필, 운영 API는 prod 프로필이며, 같은 API VM과 Caddy를 공유한다. Caddyfile.shared에서 두 호스트를 api/prod-api에 각각 연결한다. DB VM의 PostgreSQL 프로세스는 공유하지만 eolssu_dev와 eolssu_prod DB 및 계정을 분리한다. 운영 미디어는 eolssu-prod_media_data 볼륨이다. 자세한 배포 경계와 검증 범위는 [11-development-deployment](11-development-deployment.md)·[12-production-deployment](12-production-deployment.md)를 따른다.

## 6. 다음 구조 개선

> [!note] 아래는 다음 단계의 구조
> 이번에 적용한 것은 기능별 패키지 이동과 시연 Controller 분리다. 아래 Service/DTO/정책 파일은 아직 만들지 않았다.

작은 기능에 불필요한 계층을 늘리지 않고, 로직이 큰 기능부터 같은 기능 패키지 안에서 책임을 나눈다.

```text
auth/           AuthController, AuthService, SchoolVerificationService,
                SessionService, dto/, MemberSession, MemberSessionRepository
member/         MemberController, MemberService, dto/, Member, MemberRepository
event/          EventController, EventService, EventQueryService, dto/, Event, EventRepository
participation/  ParticipationController, ParticipationService, QuotaPolicy, dto/, Entity/Repository
comment/        CommentController, CommentService, CommentVisibilityPolicy, dto/, Entity/Repository
favorite/       FavoriteController, FavoriteService, Entity/Repository
review/         ReviewController, ReviewService, dto/, Entity/Repository
report/         ReportController, ReportService, dto/, Entity/Repository
media/          MediaController, MediaService, ImageProcessor, MediaStorage
                LocalMediaStorage, 이후 R2MediaStorage
admin/          사후 신고·숨김 권한 Controller/Service
common/         실제 공유되는 오류 응답·인증 처리만 배치
```

| 순서 | 변경 | 확인할 기준 |
|---|---|---|
| 1 | AuthController의 프로필·내 목록을 MemberController/Service로 분리 | `/v1/me/*` 계약 유지, 인증·프로필 검증 테스트 |
| 2 | 가입·메일 검증을 AuthService/SchoolVerificationService로 분리 | SMTP 실패·코드 만료·재발송·시도 제한·중복 가입. SMTP를 오래 열린 DB 트랜잭션 안에 넣지 않기 |
| 3 | 관심·참여·댓글·후기 각각 Controller/Service로 분리 | 기존 HTTP 계약 유지, 참여 잠금·트랜잭션이 공개 Service 진입점에 적용되도록 확인 |
| 4 | 댓글 읽기 정책과 모집 그룹 정책을 작은 정책 객체로 추출 | 작성자/호스트/다른 회원/비회원 접근 행렬, 그룹별 정원 테스트 |
| 5 | DTO와 오류 응답 정리, Entity 직접 노출 제거 | 화면 필드 유지, 비밀 필드 노출 없음, API 문서와 일치 |
| 6 | 미디어 저장 인터페이스와 R2 구현 | 파일 검증·소유권·실패 정리·로컬 대체 가능 |
| 7 | Entity 캡슐화·상태 enum·FK·인덱스 | 기존 데이터 마이그레이션, 참여 동시성·삭제/취소 무결성 |

원칙: Controller는 HTTP 변환, Service는 유스케이스·권한·트랜잭션, Repository는 DB 접근, 정책 객체는 순수 규칙, 외부 연결은 메일/저장 구현이 담당한다. Service 인터페이스는 구현이 여러 개거나 외부 연결을 교체해야 할 때 도입한다. 기능을 나눴다는 이유만으로 서버를 나누지는 않는다.

## 7. 코드를 읽는 순서와 변경 규칙

1. `EolssuApiApplication`과 `application-*.properties`: 탐색 범위·환경 차이.
2. `auth/SessionService`, `member/Member`: 인증과 프로필 완료 기준.
3. `auth/AuthController`: 메일→인증→로그인→프로필 흐름.
4. `event/EventController`, `event/EventRepository`: 작성·공개·잠금 조회.
5. `event/EventInteractionController`: 참여부터 댓글·후기로 읽는다.
6. `report/ReportController`, `media/MediaController`, `demo/`: 운영자 권한·이미지 처리의 미구현 범위와 시연 기능의 환경 경계 확인.
7. Flyway V1과 테스트: 실제 테이블과 환경 격리 기준.

변경 규칙:

- 기능 파일은 해당 패키지에 둔다. 실행 클래스는 `kr.eolssu.api`에 유지한다.
- 권한은 화면 숨김에만 의존하지 않고 서버에서 확인한다.
- 향후 HTTP 응답은 DTO로 정의한다. 서비스에서 Controller DTO를 참조하는 역방향 의존을 만들지 않는다.
- 금전·정원·상태 전환 등 경쟁 상황이 있는 변경은 트랜잭션·DB 제약·잠금을 함께 검토한다.
- 스키마 변경은 이미 적용한 V1 수정 대신 V2 이상을 추가한다.
- `.env`, 발신 비밀번호, DB 비밀번호, 세션 토큰, SSH 개인키는 Git과 로그에 남기지 않는다.
- 주석은 처리 의도·권한·경쟁 조건을 설명한다. 코드와 동일한 동작을 반복 설명하지 않는다.

## 8. 검증 범위

2026-10-01 `./mvnw clean test` 실행 결과 테스트 3개가 통과했다. 오래된 클래스 산출물을 제거한 상태에서 새 패키지를 검증했다. 테스트는 별도 메모리 H2를 사용하여 기존 로컬 파일 DB를 건드리지 않는다.

- local: Repository 8개 탐색, 샘플 구성과 시연 Controller 등록, 기존 주요 API 경로 유지.
- prod: Repository 8개 탐색, 시연 데이터·Controller 제외, `/v1/local` 경로 없음.

운영 프로필 테스트는 H2와 테스트 설정을 사용하므로 PostgreSQL V1 실행·실제 SMTP·클라우드 배포 성공을 뜻하지 않는다. 다음 단계에는 메일 실패·권한·참여 동시성·비공개 댓글·후기 자격의 동작 테스트와 PostgreSQL 통합 테스트를 추가한다.

이번 변경 검증에는 모임 생성 즉시 공개 목록·상세 조회, 다른 회원 참여, 기존 submitted 변환, removed 상태 보존을 추가했다.

## 2026-10-02 확장

EventHostController가 수정·취소·신청자 조회와 호스트 권한을 담당한다. JwtService가 JWT 서명·검증을 담당한다. V3가 취소 사유 필드를 추가하며 Micrometer·Grafana/Prometheus·node-exporter로 서버를 관측한다. 현재 Gateway는 Docker DNS와 Caddy 기반이다. [13-host-auth-monitoring](13-host-auth-monitoring.md)를 따른다.

## 2026-10-03 인증 요청 보호

`security/RequestProtection`을 `/v1/**` MVC 인터셉터로 등록했다. 변경 요청의 전용 헤더·Origin을 검사하고 인증 엔드포인트의 IP 제한을 Controller 진입 전에 적용한다. `AuthRateLimiter`는 Controller에서 정규화된 이메일 제한도 적용한다. dev/prod의 `RedisRateLimitStore`는 원자적 카운트·TTL, local/docker의 `LocalRateLimitStore`는 최대 10,000개 키의 메모리 대체 구현이다.

CORS는 명시적인 웹 출처와 Content-Type/X-Eolssu-Request만 허용한다. 전달 IP 헤더는 명시적으로 신뢰한 직접 프록시에서만 사용한다. 웹은 `apiFetch`로 JSON·multipart·본문 없는 변경 요청에 같은 헤더를 전송한다. 소스 구현·테스트 완료와 운영 적용은 구분하며, 운영 사용자별 IP 전달 확인이 남아 있다. 상세는 백엔드 `docs/api/AUTH_REQUEST_PROTECTION.md`를 따른다.
