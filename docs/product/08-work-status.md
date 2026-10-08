---
title: "얼쑤 작업 현황과 다음 개발"
aliases: ["얼쑤 개발 현황", "얼쑤 다음 할 일"]
service: "얼쑤"
team: "에헤라디야"
type: "implementation-status"
version: "1.2"
status: "개발·운영 연결 완료 · 실제 사용자 흐름 검증 대기"
created: "2026-10-01"
updated: "2026-10-03"
tags: ["얼쑤", "개발/현황", "개발/로드맵"]
---

# 얼쑤 작업 현황과 다음 개발

> [!abstract] 현재 위치
> Vercel 개발·운영 웹과 Oracle 개발·운영 API가 연결됐다. 운영 웹의 API_ORIGIN 누락으로 발생한 404를 수정하고 main 운영 배포를 완료했다.
> 2026-10-01 원격 서버와 운영 웹을 통해 HTTPS·DB 마이그레이션·목록/학교 메일 조회를 확인했다. 실제 학교 인증·가입·프로필·작성·참여는 사용자가 검증할 예정이다.

관련: [문서 홈](README.md) · [백엔드 구조와 동작](09-backend-architecture.md) · [기술 스택·배포](07-tech-stack.md) · [결정 로그](06-decisions.md)

## 1. 서비스와 개발 방향

- 서비스 **얼쑤**, 팀 **에헤라디야**: 애셔·루디·바우·피비·주드·곤.
- 한국 소재 대학교의 국제학생과 한국 학생이 인증된 대학생의 대면 모임에 참여한다. 일반 회원이 인증·프로필을 완료하면 모임을 개설할 수 있다.
- 웹은 MVP 검증, 앱은 향후 채팅 등 깊이 있는 경험을 제공한다.
- 웹: Next.js 16 / React 19 / TypeScript / Lucide 아이콘.
- API: Java 21 / Spring Boot 4.1.1 / Spring Data JPA / PostgreSQL 17 / Docker.
- 프론트와 백엔드 저장소는 별개다. 현재 백엔드는 **단일 Spring Boot 애플리케이션**이다. Caddy와 Docker DNS로 HTTP Gateway 라우팅을 구성했다. 전용 Spring Cloud Gateway·마이크로서비스는 아직 없다.

## 2. 구현 현황

여기서 ‘구현’은 소스에 기능이 있다는 뜻이다. 운영 서비스에서 검증을 끝냈다는 뜻은 아니다.

| 영역 | 현재 구현 | 남은 내용·제한 |
|---|---|---|
| 탐색·검색 | 공개 모임 조회, 이벤트명 검색, 시·카테고리 필터, 최근/인기 정렬, 최근 검색어 | 목록은 서버 전체 조회 후 메모리 필터링. 페이지네이션·검색 최적화 필요. 최근 검색어는 브라우저 저장 |
| 홈 | 샘플 모임 6개, 정보·광고 패널 표시 | 패널은 정적 구성. 운영자 편집·노출 기간 관리 없음 |
| 가입·학교 메일 | `.ac.kr`·`.edu` 접미사 검사, 6자리 코드, HTML/텍스트 메일, 재발송 | 실제 한국 대학 소속을 보장하는 대학·도메인 허용 목록은 없음 |
| 인증 정책 | 코드 10분 유효·입력 5회 제한, 로그인/메일/코드 확인 IP·이메일별 요청 제한, Redis 원자적 재발송 간격 60초, 변경 요청 CSRF 헤더·Origin 검사 구현 | 운영 배포·실제 프록시 IP 전달 검증 대기. Vercel/Caddy IP로 합산될 수 있음. 비밀번호 재설정은 별도 계정 관리 작업 |
| 로그인 | 학교 이메일+비밀번호, BCrypt, 15분 서명 JWT·7일 refresh 쿠키, 자동 접근 갱신·로그아웃 | Apple·Google은 준비 중 버튼. 소셜 계정 연결 미구현 |
| 프로필 | 인증 후 별도 `/auth/profile`, 이름·대학·국적·언어·성별·관심사, 수정 | 알려진 6개 도메인 자동 대학 매핑. 미인식 대학은 직접 입력으로 실제 대학 검색 기능 없음 |
| 언어·테마 | 한국어/영어 UI, 라이트/다크, 제2언어 없음 | 언어·테마는 브라우저 저장. 계정 간 동기화 없음 |
| 호스트·모임 작성 | 인증·프로필 완료 검사, 서버가 호스트 설정, 한/국제학생 정원, 한/영 설명, 장소 텍스트, 썸네일 | 지도 검색 없음. 등록 즉시 `published` 공개. 사용자 작성 영어 제목 입력 미지원 |
| 이미지 | 인증 업로드, 파일 크기·이미지 형식·픽셀 수 검사, JPEG 저장/조회, Docker volume | 현재 로컬 파일 저장. 1600px JPEG 압축·원본 20MiB/48MP·환경별 10GiB 적용. R2·소유자 메타데이터·미사용 파일 정리는 미구현 |
| 관심 | 계정별 추가·해제·목록, 관심 수 기반 인기 정렬 | 정렬 시 반복 집계 쿼리 개선 필요 |
| 참여 | 공개 모임 참여·취소·내 참여 목록, 그룹별 정원, 참여 시 DB 행 잠금 | 샘플 3개 데모 참여 가능. 국적 문자열로 그룹 분류. 출석 확인 없음 |
| 댓글 | 공개·호스트 전용, 1단계 답글, 작성자 삭제, 비공개 읽기 권한 | 댓글 수정·운영자 삭제·페이지네이션 없음 |
| 후기 | 시작 시간이 지난 모임의 참여 이력으로 작성, 내 후기 수정·삭제, 공개 조회 | 종료 시간·실제 참석 검증 없이 작성 가능. 운영 정책 확정 필요 |
| 신고 | 모임·댓글 신고, 중복 검사, 내 신고 목록 | 로컬 처리 화면만 존재. 운영 관리자 권한·제재·이의신청·안내 없음 |
| 마이 이벤트 | 참여 예정·지난 모임·관심·주최·신고 목록 | 호스트 관리에서 수정·취소·신청자 조회, 취소 사유 표시. 별도 이메일/푸시 변경 안내 없음 |
| 관리자 | `/reports-demo`와 `/v1/local/reports` 신고 처리 시연 | 운영 대시보드가 아니다. 관리자 인증·감사 로그 없음. dev/prod에는 시연 API 없음 |
| 채팅 | 미구현 | 웹 제외 방향. 앱 공지방은 호스트 작성/참여자 읽기, 호스트-참여자 개별 방 예정 |
| 계정 관리 | 학교 메일 코드로 비밀번호 재설정, 전체 기기 로그아웃, 비밀번호·동의 확인 후 탈퇴 및 데이터 삭제·익명화 | 로컬 검증 완료. 실제 메일 수신·운영 배포·V5 적용 확인 대기. 백업·외부 로그 보관/삭제 정책과 이미지 소유권·정리는 별도 |
| 마이 기타 | 프로필·브라우저 설정·신고 목록 | 알림 설정/전송, Contact 접수, 약관 동의 기록, 공지 관리 필요 |

### 웹 화면과 API 연결

| 화면 | 경로 | 주로 연결되는 API |
|---|---|---|
| 홈·탐색 | `/` | `GET /v1/events` |
| 로그인·가입·코드 | `/auth` | `/v1/auth/school-email`, `register`, `resend`, `verify`, `login` |
| 비밀번호 재설정 | `/auth/reset-password` | `POST /v1/auth/password-reset/request`, `POST /v1/auth/password-reset/confirm` |
| 프로필 작성 | `/auth/profile` | `GET /v1/me`, `PATCH /v1/me/profile` |
| 모임 작성 | `/events/new` | `POST /v1/media`, `POST /v1/events` |
| 모임 상세 | `/events/[id]` | 상세·activity·favorite·participation·comments·reviews·신고 |
| 마이 이벤트 | `/my-events` | `/v1/me/events`, `participations`, `favorites`, `reports` |
| 마이 | `/my` | `/v1/me`, `/v1/me/profile`, `POST /v1/auth/logout-all`, `DELETE /v1/me/account` |
| 로컬 신고 관리 | `/reports-demo` | `/v1/local/reports` |

## 3. 저장소·데이터·배포

| 항목 | 상태 |
|---|---|
| GitHub | 비공개 [eolssu-web](https://github.com/TheSoftBelly/eolssu-web), [eolssu-api](https://github.com/TheSoftBelly/eolssu-api) |
| Vercel | `thesoftbellys-projects/eolssu-web`, [웹 주소](https://earthuu.vercel.app/). 운영 main 배포 HAm392tAahWHmswq9ifh4FvpEfeC Ready, develop Preview 별도 |
| Vercel 환경 변수 | `NEXT_PUBLIC_API_URL=same-origin`. Production API_ORIGIN은 운영 API, Preview develop 범위 값은 개발 API로 설정·재배포 완료 |
| Oracle 지역 | Osaka `ap-osaka-1`. A1 용량 부족 후 E2.1.Micro 2대 생성 |
| API VM | `eolssu-prod-api`, Ubuntu 24.04, 1/8 OCPU 기본·버스트 / 1 GB, 내부 IP `[접속 IP 비공개]` |
| DB VM | `eolssu-prod-db`, Ubuntu 24.04 Minimal, 1/8 OCPU 기본·버스트 / 1 GB, 내부 IP `[접속 IP 비공개]` |
| 네트워크 | `eolssu-vcn` / `eolssu-public`, `[접속 IP 비공개]`. API 공인 IP `[접속 IP 비공개]`, DB 공인 IP 없음. SSH 관리자 IP 제한, DB 5432는 API 내부 IP만 허용 |
| 운영 설치 | Docker·개발/운영 API·DB·Gmail 설정·HTTPS·Vercel 전달 연결 완료 |
| 환경 분리 | API VM과 DB VM 두 대를 개발/운영이 공유한다. dev/prod API 컨테이너·DB·계정·미디어 볼륨 분리. 별도 VM 분리 미완료 |
| 이미지 저장 | 현재 파일 volume. Cloudflare R2는 선택한 향후 방향 |
| 자동 배포 | Vercel main→Production, develop→Preview 자동 배포. API develop CI 테스트·이미지 빌드 성공, SSH 자동 배포 비활성화, 서버 배포는 수동 |
| DB | 런타임 8개 테이블. 개발·운영 DB 모두 Flyway V1/V2/V3/V4 적용 성공, JPA validate 통과 |

> [!warning] 설계 ERD와 실제 DB 구분
> [04-erd](04-erd.md)와 ERDCloud용 SQL은 확장 서비스 설계다. 현재 코드의 8개 테이블과 일치하지 않는다. 운영 DB에 설계 SQL을 그대로 실행하지 않는다. 변경은 실제 스키마를 기준으로 새 Flyway 마이그레이션으로 적용한다.

배포 파일:

- `compose.yaml`: 로컬 API + PostgreSQL + Mailpit.
- `compose.deploy-api.yaml`: 소형 API VM용 사전 빌드 이미지 + Caddy, 메모리 제한.
- `compose.deploy-db.yaml`: 별도 DB VM, DB 내부 IP에만 5432 바인딩.
- `compose.deploy.yaml`: 기존 한 VM 배포 구성. 자원이 충분한 경우 검토.
- `compose.dev.yaml`: 개발 프로필 설정 오버라이드.
- `compose.prod-shared.yaml`: 공유 API VM에 운영 API 추가, 별도 운영 DB 계정·미디어 볼륨 사용.
- `deploy/Caddyfile.shared`: 개발·운영 두 호스트를 각각 API에 연결. 단일 호스트 설정으로 덮어쓰지 않는다.
- `deploy/deployment.env.example`, `deploy/README.md`: 배포 입력값과 순서. 예시 IP는 실제 설정 시 재확인.

운영·개발 주소와 실제 배포 식별값은 [12-production-deployment](12-production-deployment.md)·[11-development-deployment](11-development-deployment.md)를 확인한다.

## 4. 이번 정리에서 변경한 코드

- 하나의 `kr.eolssu.api`에 있던 파일을 기능별 11개 패키지로 이동했다.
- 심사 제거 결정에 따라 시연 승인 Controller를 삭제했다. 신고 처리 Controller는 유지한다.
- 패키지 간 참조를 명시적 import로 연결했다. 신고 응답 생성 메서드는 시연 패키지에서도 사용할 수 있도록 공개했다.
- 엔트리포인트는 최상위 패키지에 유지했다. API URL·DB 테이블·업무 정책은 유지했다.
- Controller의 업무 로직을 Service로 모두 옮긴 것은 아니다. 다음 단계의 책임 분리는 [백엔드 구조 문서](09-backend-architecture.md#6.-다음-구조-개선)에 기록했다.

## 5. 앞으로 할 일

### P0 — 운영에서 가입·참여까지 연결

- [ ] **사후 운영 권한**: 관리자 계정·신고 처리·공개 모임 숨김·사유 전달·감사 기록. 게시 전 심사는 제거했다.
- [ ] **공개 후 수정/취소 정책**: 참가자가 있는 모임의 변경 범위·기한·안내를 합의한다.

- [x] **Oracle 접속·네트워크**: 로그인 갱신, API 공인 IP, SSH를 관리자 IP `/32`로 제한, API 80/443, DB 5432는 API 내부 IP `/32`만 허용. DB 공인 공개는 필요 없다.
- [x] **API/DB 초기 배포**: 배포 이미지 빌드·전달, 비밀 환경 변수, DB 초기화·볼륨, 메모리·swap·재시작 설정 확인. 초기 메모리를 확인했으며 실제 동시 사용자 부하 검증은 별도 남은 작업이다.
- [x] **HTTPS와 Vercel 연결**: 사용 가능한 API HTTPS 호스트 결정 → 인증서 → `API_ORIGIN` 입력 → 웹 재배포. Vercel 기본 웹 도메인만으로 Oracle API 인증서 문제가 해결되지는 않는다.
- [ ] **Gmail SMTP 실제 수신**: 발신 환경 설정과 SMTP 인증은 완료했다. 실제 학교 메일 수신/스팸함·만료·재발송·오류 확인은 남아 있다. 비밀값은 `.env`/서버 환경/비밀 저장소에만 입력한다.
- [x] **인증 요청 보호 소스 구현**: 로그인/메일/코드 확인 IP·이메일별 요청 제한, Redis 원자적 메일 60초 간격, 변경 요청의 전용 헤더·Origin 검사, 웹 요청 연결. 운영 적용 완료를 의미하지 않는다.
- [ ] **인증 요청 보호 운영 적용**: 웹 선배포, Redis·WEB_ORIGIN 확인, Vercel/Caddy의 실제 사용자 IP 신뢰 경계 확정, 개발·운영 배포 및 실제 흐름 검증.
- [ ] **운영 기본 방어·복구**: 비밀값 제외 로그, DB·이미지 백업과 복구 검증.
- [ ] **운영 흐름 검증**: 실제 학교 메일 가입 → 프로필 → 작성·즉시 공개 → 다른 계정 참여/취소 → 비공개 댓글 → 재로그인. 동시 마지막 자리 신청에서 초과 모집이 없어야 한다.

### P1 — 웹 MVP 운영 완성

- [ ] 대학·메일 도메인 데이터와 미인식 학교 확인 절차. `.edu`만으로 한국 소재 대학을 보장할 수 없다.
- [ ] 대학 검색, 국적/언어 코드 정규화, 공백 프로필 방지, 참여 그룹 분류 정책 확정.
- [x] 카카오 장소 검색·선택·지도 미리보기·좌표·주소·시군구 코드 저장 및 개발·운영 배포.
- [ ] 사용자 작성 한/영 제목 입력, 운영에서 새 모임 생성 후 장소 저장·재조회 확인.
- [x] 공개 모임 수정·취소·신청자 조회·취소 사유 표시 구현. 모집 마감/중단 상태와 변경 알림은 후속 작업.
- [ ] 이벤트 목록/댓글/후기 페이지네이션, DB 조건 검색·정렬, 집계 쿼리·인덱스 개선.
- [ ] 이미지 리사이즈·압축·변환 동시 제한은 구현. 소유권/메타데이터/미사용 이미지 정리·R2 이관은 남은 작업.
- [x] 비밀번호 재설정, 전체 기기 세션 회수, 탈퇴·데이터 삭제/익명화 및 처리 범위 안내: 소스 구현·로컬 검증 완료.
- [ ] 계정 관리 운영 배포, PostgreSQL Flyway V5 적용, 실제 학교 메일 재설정·탈퇴 흐름 검증.
- [ ] 백업·외부 로그·신고 증거 보관/삭제 정책과 업로드 소유권·파일 정리.
- [ ] Apple·Google 로그인 및 계정 연결.
- [ ] 실제 참석·후기 작성 자격·취소 기한 합의와 구현.
- [ ] 운영 신고 처리·제재·알림, 광고/정보 패널·공지·Contact·약관 동의 관리.
- [ ] 백엔드 원격 자동 배포 접속·권한, 장애 알림·롤백. 이미지 CI 빌드와 개발/운영 DB·환경 파일 분리는 완료했다.

### P2 — 앱 확장과 구조 확장

- [ ] 앱 온보딩, 호스트 공지방, 참여자별 호스트 개별 채팅, 채팅 신고·알림.
- [ ] 기능별 Service/DTO/정책 분리, 도메인 테스트와 PostgreSQL 통합 테스트 확대.
- [ ] 실제 트래픽과 운영 부담을 확인한 뒤 Gateway·서비스 분리 여부 결정. API VM과 DB VM을 나눈 것만으로 마이크로서비스가 되지는 않는다.

## 6. 회의·사용자 입력·검증 기록

회의 필요: 공개 후 수정/취소 정책, 한국/국제학생 분류, 출석·후기 자격, 운영자 역할, 인기 계산, 서비스 가설·측정 계획. 가설·측정의 상세는 PRD에 추가하지 않고 별도 회의로 유지한다.

서버 접속·발신 Gmail 환경 설정·API HTTPS 주소는 적용했다. 다음 사용자 작업은 운영 웹에서 실제 학교 메일 인증과 프로필·모임·참여 흐름 확인이다. SSH 관리자 IP가 바뀌면 허용 규칙을 갱신한다. 비밀번호·인증키를 문서나 대화창에 남기지 않는다.

과거 로컬 수동 확인 기록은 Mailpit 가입·코드 인증·로그인·모임 등록·다른 계정 참여/취소다. 이번 패키지 정리는 `./mvnw clean test`의 자동 테스트 3개를 통과했다. 로컬/운영 프로필의 Bean·JPA 탐색, 기존 주요 경로 등록, 운영 프로필에서 시연 API 제외를 확인했다. 이 테스트는 실제 Gmail 송신, PostgreSQL 마이그레이션, 운영 접속이나 동시 참여 부하를 검증하지 않는다.

## 2026-10-01 Gmail 설정 반영

팀 계정의 Google 앱 비밀번호를 Git 제외 로컬 `.env`에 입력했다. Gmail STARTTLS 연결·SMTP 계정 인증을 확인했고 API 컨테이너를 재빌드·재시작했다. 실제 학교 메일 수신·코드 입력 검증은 남아 있다. 당시에는 Oracle/Vercel 연결 전이었다. 이후 개발·운영 연결을 완료했으며 현재 상태는 [12-production-deployment](12-production-deployment.md)를 따른다. 자세한 설정·확인 방법은 [10-gmail-setup](10-gmail-setup.md)을 따른다.

## 2026-10-01 즉시 공개와 develop 배포

게시 전 심사를 제거하고 새 모임의 기본 상태를 published로 변경했다. 승인 API·심사 UI를 삭제하고 로컬 신고 관리만 유지한다. Flyway V2와 local/docker 초기 변환으로 기존 approved/submitted/reviewing을 공개한다. removed/rejected/cancelled는 유지한다. 두 저장소의 develop 브랜치에 변경을 올리고 API 이미지 빌드/조건부 SSH 개발 배포와 웹 검증 워크플로를 구성한다. 이후 원격 개발 배포와 웹 통신을 확인했다. [11-development-deployment](11-development-deployment.md)를 따른다.

## 2026-10-01 Oracle 개발 배포 완료

사용자 합의에 따라 기존 두 Micro VM을 개발 환경으로 사용했다. 개발 API HTTPS health UP, 개발 PostgreSQL 및 Flyway V1/V2, Gmail SMTP 인증을 확인했다. Vercel develop Preview에만 API_ORIGIN을 설정했다. 상세 구성·검증 범위·남은 작업은 [11-development-deployment](11-development-deployment.md)을 따른다. 이후 같은 VM에 분리된 운영 API·DB·미디어를 추가했다. 현재 상태는 [12-production-deployment](12-production-deployment.md)를 따른다.

## 운영 연결 완료 (2026-10-01)

운영 API·별도 DB를 추가하고 Production API_ORIGIN 설정 및 웹 main 배포를 완료했다. 운영 웹의 모임/학교 메일 조회 200, 빈 로그인·가입 입력 400을 확인했다. 최신 상태는 [12-production-deployment](12-production-deployment.md)를 따른다.

## 2026-10-02 주최자 관리와 서버 관측

수정·취소·신청자 조회, JWT 자동 갱신, 이미지 압축·한도 완화, Caddy Gateway와 Grafana/Prometheus를 개발·운영에 적용했다. 네 대상의 지표 수집과 웹 API 연결을 확인했다. 실제 한도·성능 표본·확인 범위와 접속 방법은 [13-host-auth-monitoring](13-host-auth-monitoring.md)를 따른다.

## 2026-10-02 카카오 장소 검색

장소 검색·선택·지도 미리보기·주소/좌표 저장과 Redis 캐시를 구현했다. 개발·운영 API와 각각의 Redis를 배포했다. 설정·검증·롤백 기록은 [[15-kakao-place-deployment]]를 따른다.

## 2026-10-02 최신 작업 정리

- 카카오 장소 검색·Redis는 개발·운영에 배포했고 운영 웹에서 검색·선택·지도 표시를 확인했다. 새 모임 생성·저장·재조회 전체 흐름과 부하 검증은 남아 있다.
- API 장소 기능 PR #1은 병합 완료, 웹 장소 기능 PR #1은 열려 있다(이번 GitHub 조회 기준). 배포와 기본 브랜치 반영 여부를 구분한다.
- 개발 Swagger UI/명세 200, 운영 404는 배포 기록으로 확인했다. Swagger 설정·API 명세·관리자 인수인계 문서는 로컬 미커밋 작업이므로 소스 공유 완료로 처리하지 않는다.
- 관리자 개발을 위한 전용 개발 DB 계정·SSH 터널 접근 준비 기록이 있다. 네트워크 허용 규칙 및 팀원 실제 접속 검증은 남아 있으며 운영 관리자 기능은 미구현이다. 접속 상세는 공개 문서에 포함하지 않는다.
- 웹 모임 상세 화면·스타일 수정은 로컬 미커밋 상태다. 이번 문서 갱신에서는 코드 배포나 검증 완료로 처리하지 않는다.
- 이번 갱신은 코드·커밋·기존 배포 기록과 GitHub PR 상태를 대조했다. 운영 서버 재검증·새 테스트 실행은 하지 않았다.

## 2026-10-03 인증 요청 보호

로그인은 IP 30회/이메일 10회(15분), 가입·재발송은 합산 IP 20회/이메일 5회(1시간), 코드 확인은 IP 60회/이메일 10회(15분) 기본 제한을 구현했다. 메일은 이메일당 60초 간격을 원자적으로 적용한다. 개발·운영은 Redis, local/docker는 제한된 메모리 저장소를 사용한다. 초과 시 429와 Retry-After, 제한 저장소 장애 시 503을 반환한다.

모든 `/v1/**` 변경 요청은 `X-Eolssu-Request: 1`과 허용된 브라우저 Origin을 검사하며 웹은 공통 apiFetch로 헤더를 전송한다. 기존 인증 쿠키와 자동 갱신 흐름은 유지한다. 출처 차단·정상 로그인·CORS·제한 횟수·Redis 동시성/만료를 검증했고 프론트 타입 검사·lint·빌드를 통과했다.

운영 배포는 아직 하지 않았다. 현재 Vercel→Caddy 경로는 사용자별 IP 대신 프록시 IP에 합산될 수 있으므로, 실제 IP 전달의 신뢰 경계를 확인한 뒤 적용해야 한다. 상세 계약·설정·배포 순서는 백엔드 `docs/api/AUTH_REQUEST_PROTECTION.md`를 따른다.

## 2026-10-03 계정 관리 구현·로컬 검증

로그인 화면에 비밀번호 재설정 진입점을, 마이 페이지에 계정 관리 영역을 추가했다. 학교 메일 코드로 비밀번호를 재설정하면 모든 세션을 폐기한다. 전체 기기 로그아웃은 현재 기기를 포함한다. 탈퇴는 현재 비밀번호와 데이터 처리 동의를 확인하고 하나의 DB 트랜잭션으로 처리한다. 예정된 공개 주최 모임이 있으면 먼저 취소하도록 안내한다.

계정·프로필·세션·관심·참여·후기·본인 신고 내역은 삭제한다. 본인 댓글은 내용과 작성자 연결을 제거하고 삭제 표시하며 답글 구조와 공개 범위는 유지한다. 주최자 이름·학교·국적 및 회원 연결은 제거한다. 주최한 모임의 내용·이미지와 다른 회원의 활동은 유지한다. 백업·외부 로그 보관 및 삭제 기간, 업로드 소유권과 파일 정리는 별도 검토 대상이다.

`AccountManagementTests` 8개가 통과했다. 코드 만료·일회성·5회 오입력 영속화, 전체 세션 폐기·다른 회원 세션 유지, 탈퇴 제한·DB 삭제/익명화, HTTP 인증·CSRF·탈퇴 동의를 확인했다. 웹 lint·타입 검사·프로덕션 빌드도 통과했다. H2와 모의 SMTP 검증이며 실제 학교 메일 수신, 운영 PostgreSQL의 Flyway V5 적용 및 운영 배포는 아직 검증하지 않았다.

상세: [계정 관리·탈퇴 데이터 처리](16-account-management.md)
