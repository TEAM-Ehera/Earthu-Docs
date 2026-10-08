# 얼쑤 API 명세서

기준: **2026-10-08 · Asia/Seoul**, 현재 로컬 Java Controller 소스 구현. 운영 서버를 재검증한 문서가 아니며 미커밋 기능의 운영 제공 여부를 보장하지 않습니다. 계정 관리는 로컬 검증 완료이며 운영 배포·실제 메일 수신 검증 대기입니다. API prefix `/v1`. 시간은 ISO 8601 UTC, 식별자는 UUID입니다.

## Swagger

local/docker/dev 서버에서 `/swagger-ui/index.html`로 요청/응답 스키마와 Try it out을 확인합니다. 실제 Controller·DTO에서 자동 생성되는 명세는 `/v3/api-docs`, YAML은 `/v3/api-docs.yaml`입니다. UI는 서버에 포함되어 CDN이 필요 없습니다. prod에서는 UI와 명세를 모두 비활성화합니다. 실행·인증·재생성 절차는 [Swagger 사용 안내](SWAGGER.md)를 따릅니다.

## 인증과 응답

학교 이메일 확인 → 가입 → 이메일 코드 인증 → 프로필 작성 순서입니다. 인증·로그인 성공 시 HttpOnly `eolssu_session`(접근 JWT 15분) 및 `eolssu_refresh`(세션 7일) 쿠키를 발급합니다. 접근 쿠키 자체 Max-Age는 7일이며 JWT 만료 후 refresh 쿠키로 자동 재발급합니다. Bearer 인증은 지원하지 않습니다. Swagger에서 로그인 실행 후 같은 서버의 쿠키를 사용하세요. **모든 `/v1/**` 변경 요청은 `X-Eolssu-Request: 1` 헤더가 필수**입니다. 브라우저의 정확한 Origin을 `WEB_ORIGIN`에 허용해야 하며 Swagger API 출처도 개발 환경에 별도로 등록합니다. 외부 웹은 `credentials: "include"`가 필요하며 허용 origin과 SameSite=Lax 정책을 따릅니다.

일반 성공은 `{ "data": ... }`. 가입/재발송은 `message` 객체, activity/참여 신청은 Activity 객체 직접 반환. 204는 본문 없음. 로그아웃은 200·빈 본문. 이미지 조회는 image/jpeg입니다. 오류는 Spring Boot 기본 응답이며 고정된 커스텀 오류 스키마는 없습니다. 검증 실패 400, 로그인 필요 401, 권한 부족 403, 대상 없음 404, 상태 충돌 409, 업무 검증 422, 제한 429를 사용합니다. 각 API의 가능한 오류는 Swagger에 기재했습니다.

## 엔드포인트

|Method|경로|기능|접근|성공|
|---|---|---|---|---|
|GET|`/v1/local/reports`|로컬 신고 목록|로컬 전용|200|
|PATCH|`/v1/local/reports/{id}`|로컬 신고 처리|로컬 전용|200|
|GET|`/v1/auth/school-email`|학교 이메일 확인|공개|200|
|POST|`/v1/auth/register`|회원가입 및 인증 메일 발송|공개|201|
|POST|`/v1/auth/resend`|인증 코드 재발송|공개|200|
|POST|`/v1/auth/verify`|학교 이메일 인증 및 로그인|공개|200|
|POST|`/v1/auth/login`|로그인|공개|200|
|POST|`/v1/auth/logout`|로그아웃|공개|200|
|POST|`/v1/auth/password-reset/request`|비밀번호 재설정 코드 요청|공개|200|
|POST|`/v1/auth/password-reset/confirm`|비밀번호 재설정·전체 세션 폐기|공개|204|
|POST|`/v1/auth/logout-all`|전체 기기 로그아웃|로그인|204|
|GET|`/v1/me/account/data-policy`|탈퇴 데이터 처리 안내|로그인|200|
|DELETE|`/v1/me/account`|회원 탈퇴·데이터 처리|로그인|204|
|GET|`/v1/me`|내 프로필 조회|로그인|200|
|PATCH|`/v1/me/profile`|프로필 저장|로그인|200|
|GET|`/v1/me/events`|내가 주최한 모임|로그인|200|
|GET|`/v1/me/favorites`|내 관심 모임|로그인|200|
|GET|`/v1/me/participations`|내 참여 모임|로그인|200|
|POST|`/v1/reports`|신고 접수|로그인|201|
|GET|`/v1/me/reports`|내 신고 목록|로그인|200|
|GET|`/v1/places`|장소 키워드 검색|로그인|200|
|GET|`/v1/places/region`|좌표의 행정 지역 조회|로그인|200|
|POST|`/v1/events`|모임 등록 (즉시 공개)|로그인|201|
|GET|`/v1/events`|공개 모임 검색|공개|200|
|GET|`/v1/events/{id}`|모임 상세|공개|200|
|GET|`/v1/events/{id}/activity`|관심·참여 상태 및 인원|공개|200|
|POST|`/v1/events/{id}/favorite`|관심 등록|로그인|204|
|DELETE|`/v1/events/{id}/favorite`|관심 해제|로그인|204|
|POST|`/v1/events/{id}/participation`|참여 신청|로그인|200|
|DELETE|`/v1/events/{id}/participation`|참여 취소|로그인|204|
|GET|`/v1/events/{id}/comments`|댓글 목록|공개|200|
|POST|`/v1/events/{id}/comments`|댓글 작성|로그인|201|
|DELETE|`/v1/events/{id}/comments/{commentId}`|내 댓글 삭제|로그인|204|
|GET|`/v1/events/{id}/reviews`|후기 목록|공개|200|
|POST|`/v1/events/{id}/reviews`|후기 작성|로그인|201|
|PATCH|`/v1/events/{id}/reviews/me`|내 후기 수정|로그인|200|
|DELETE|`/v1/events/{id}/reviews/me`|내 후기 삭제|로그인|204|
|GET|`/v1/events/{id}/host`|주최자용 모임 조회|로그인|200|
|GET|`/v1/events/{id}/applicants`|신청자 목록|로그인|200|
|PATCH|`/v1/events/{id}`|주최자 모임 수정|로그인|200|
|DELETE|`/v1/events/{id}`|주최자 모임 취소|로그인|204|
|DELETE|`/v1/events/{id}/host`|주최한 모임 삭제 (`deleted`)|주최자|204|
|POST|`/v1/media`|이미지 업로드|로그인|201|
|GET|`/v1/media/{id}`|이미지 조회|공개|200|

## 업무 규칙

- **GET /v1/local/reports**:  local/docker 프로필에서만 활성. 관리자 인증 없는 시연 API. 운영에서는 사용 불가.
- **PATCH /v1/local/reports/{id}**:  local/docker 프로필에서만 활성. 관리자 인증 없는 시연 API. 운영에서는 사용 불가.
- **POST /v1/auth/register**: 학교 이메일 .ac.kr/.edu만 허용. 비밀번호 8자 이상, UTF-8 기준 72바이트 이하. 6자리 인증 코드 유효기간 10분.
- **POST /v1/auth/resend**: 재발송 간격 60초. 이미 인증된 회원은 409.
- **POST /v1/auth/verify**: 최대 5회 오입력. 성공 시 eolssu_session과 eolssu_refresh HttpOnly 쿠키 발급.
- **POST /v1/auth/login**: 인증 완료 계정만 로그인 가능. 성공 시 두 인증 쿠키 발급.
- **PATCH /v1/me/profile**: 학교 인증 필요. 두 언어는 달라야 함. 참여 중 국적 변경은 409. PATCH지만 필수 프로필 필드 전체 전송.
- **POST /v1/events**: 학교 인증 및 프로필 완료 필요. 모집 마감은 현재 이후, 시작 이전. 총 정원 1 이상.
- **GET /v1/events/{id}**: published 또는 cancelled 모임만 조회 가능.
- **GET /v1/events/{id}/activity**: 로그인 선택 사항. Activity를 data 래퍼 없이 반환. published 모임에서만 사용 가능.
- **POST /v1/events/{id}/favorite**:  published 모임에서만 사용 가능.
- **DELETE /v1/events/{id}/favorite**:  published 모임에서만 사용 가능.
- **POST /v1/events/{id}/participation**: 인증·프로필 완료 필요. 주최자 신청 불가. 모집 기간과 국적별 정원 검사. 중복 신청은 현재 Activity 반환. 정원은 DB 잠금으로 검사. published 모임에서만 사용 가능.
- **DELETE /v1/events/{id}/participation**: 시작 전 취소 가능. cancelled 모임에서는 404. published 모임에서만 사용 가능.
- **GET /v1/events/{id}/comments**:  published 모임에서만 사용 가능.
- **POST /v1/events/{id}/comments**: 인증·프로필 완료 필요. 답글은 1단계만 가능하고 부모 공개 범위 상속. host_only는 작성자·주최자에게 표시. published 모임에서만 사용 가능.
- **DELETE /v1/events/{id}/comments/{commentId}**: 작성자만 삭제. 답글이 있으면 본문·작성자 정보가 비워진 삭제 표시로 남음. published 모임에서만 사용 가능.
- **GET /v1/events/{id}/reviews**:  published 모임에서만 사용 가능.
- **POST /v1/events/{id}/reviews**: 모임 시작 이후 active 참여 이력 필요. 실제 출석 검증 없음. 중복 후기 409. published 모임에서만 사용 가능.
- **PATCH /v1/events/{id}/reviews/me**:  published 모임에서만 사용 가능.
- **DELETE /v1/events/{id}/reviews/me**:  published 모임에서만 사용 가능.
- **PATCH /v1/events/{id}**: 본인 주최, 시작 전 published 모임만 가능. 현재 참여 인원보다 정원을 줄일 수 없음. 모집 마감은 시작 이전 (등록과 달리 현재 이후 검사 없음). 필수 필드 전체 전송.
- **DELETE /v1/events/{id}**: 본인 주최 및 시작 전 모임만 가능. JSON reason 필수. 물리 삭제 대신 cancelled로 변경. 상세 조회와 내 참여 목록에 유지.
- **POST /v1/media**: 인증·프로필 완료 필요. multipart file 필수. JPEG/PNG, 최대 20 MiB·48MP. 긴 변 1600px 이하로 샘플링 후 JPEG 저장. 처리 중 429, 저장 한도 507.

## 계정 관리

실제 요청 필드·오류·처리 범위는 [계정 관리 상세](ACCOUNT_MANAGEMENT.md)를 따릅니다. 재설정 요청 `{email}`, 완료 `{email,code,password}`, 탈퇴 `{password,confirmed:true}`를 보냅니다. 모든 변경 요청은 `X-Eolssu-Request: 1` 헤더가 필요합니다. 재설정 완료·전체 기기 로그아웃·탈퇴는 204이며 전체 세션과 현재 쿠키를 폐기합니다.

탈퇴 시 계정·프로필·관심·참여·후기·본인 신고를 삭제하고 댓글 내용·작성자 연결 및 주최자 정보를 제거합니다. 주최한 모임의 내용·이미지와 다른 회원의 활동은 유지합니다. 예정된 공개 주최 모임이 있으면 먼저 취소해야 합니다. 백업·외부 로그 보관/삭제 정책과 이미지 소유권·정리는 별도입니다.

## 요청 예시

```sh
# 쿠키 저장 (인증 완료 계정)
curl -c cookies.txt -H "X-Eolssu-Request: 1" -H "Content-Type: application/json" -d '{"email":"student@postech.ac.kr","password":"example-password"}' http://localhost:8080/v1/auth/login
curl -b cookies.txt -c cookies.txt http://localhost:8080/v1/me
curl -b cookies.txt -H "X-Eolssu-Request: 1" -F file=@photo.png http://localhost:8080/v1/media
```

요청 필드·타입·필수 여부·길이·수치 범위·응답 필드는 실행 서버의 `/v3/api-docs`를 기준으로 확인합니다. [저장된 OpenAPI 원본](openapi.json)은 2026-10-08 H2 개발 프로필의 현재 로컬 소스에서 재생성한 스냅샷으로 계정 관리·장소·주최 모임 삭제를 포함합니다. 배포 서버와 다를 수 있습니다. DTO의 선택 필드는 생략할 수 있습니다. 프로필과 모임 PATCH는 필수 필드를 모두 보내는 방식입니다. 모임 취소 DELETE는 JSON reason 본문을 보냅니다.

관리용 actuator는 업무 API 명세에서 제외했습니다. 로컬 신고 처리 경로는 local/docker에서만 존재하며 dev/prod에는 없습니다.


## 요청·응답 필드

필드명은 실제 JSON의 **camelCase**입니다. 제품 설계 문서의 snake_case, cursor, revision, Idempotency-Key, Bearer 인증은 현재 계약에 포함되지 않습니다. 현재 모임·댓글·후기·내 목록은 페이지네이션 없이 `data` 배열을 반환합니다.

| 요청 DTO | 필수 필드 | 선택 필드·검증 |
| --- | --- | --- |
| Credentials | `email`, `password` | 가입 비밀번호 8자 이상·UTF-8 72바이트 이하. 학교 이메일 검사 |
| Verification | `email`, `code` | 인증 코드는 6자리 숫자, 만료 10분 |
| ProfileInput | `name`, `university`, `nationality`, `primaryLanguage`, `gender` | `name` 최대 50자. `secondaryLanguage`, `interests` 선택. `gender`: male/female/others/none |
| EventInput | `title`, `descriptionKo`, `startsAt`, `recruitmentEndsAt`, `city`, `venue`, `category` | `title` 5–80자, 한국어 본문 20–5000자. `descriptionEn` 최대 5000자, `thumbnailId`, `place` 선택. 두 정원은 0 이상이며 합계 1 이상. primitive 정원 생략 시 0 |
| CommentInput | `body` | 최대 1000자. `visibility`: public/host_only (미입력 기본 public), `replyToId` 선택 |
| ReviewInput | `body`, `rating` | 본문 최대 1000자, 별점 1–5 |
| ReportInput | `eventId`, `targetType`, `targetId`, `reason` | `targetType`: event/comment. `reason`: safety/spam/harassment/misleading/other. `detail` 최대 1000자 |
| Cancellation | `reason` | 공백 불가, 최대 1000자 |
| ResetPassword | `email`, `code`, `password` | 새 비밀번호 8자 이상·UTF-8 72바이트 이하. 잘못된/만료 코드 400 |
| Withdrawal | `password`, `confirmed` | `confirmed: true` 필요, 비밀번호 재확인 |

`EventInput.startsAt`은 미래여야 합니다. 프로필·모임 PATCH는 부분 필드 변경이 아닌 필수 필드를 모두 보내는 방식입니다. 정원은 `capacityKorean`, `capacityInternational`입니다. `titleEn`은 조회 필드지만 현재 등록·수정 DTO에서는 받지 않습니다. 관심사·국적·언어·카테고리의 목표 코드 체계와 현재 문자열 입력을 혼동하지 않습니다.

| 성공 응답 | 구조 |
| --- | --- |
| 가입·인증 메일 재발송 | `{message,email}` |
| 비밀번호 재설정 요청 | `{message}` (계정 존재 여부 비공개) |
| 프로필·인증·로그인 | `{data: MemberView}` |
| 모임 목록/등록/상세/수정/주최자 조회 | `{data: Event[]}` 또는 `{data: Event}` |
| 참여 상태 조회·참여 신청 | `Activity` 직접 반환, `data` 없음 |
| 내 참여 목록 | `{data: [{event,quotaGroup,demo}]}` |
| 댓글·후기·신고·신청자 목록 | `{data: [...]}` |
| 이미지 업로드 | `{data: {id,url}}` |
| 이미지 조회 | `image/jpeg` 바이너리 |
| 탈퇴 처리 안내 | `{data: {deleted,anonymized,retained,requirement}}`, `Cache-Control: no-store` |
| 204 응답·200 로그아웃 | 빈 본문, JSON 파싱하지 않음 |

### 공개 모임 검색

`GET /v1/events?q=문화&city=포항&category=culture&sort=recent`

- `q`: 한글/영문 제목 부분 일치, 대소문자 무시.
- `city`, `category`: 실제 저장 문자열 정확 일치. 선택하지 않은 필터는 생략.
- `sort`: recent (기본, 생성 시각 내림차순), popular (관심 수 내림차순·동률 시 생성 시각). 다른 값 400.
- `published`만 반환. pagination/총 건수/cursor 없음.

## 장소 검색·선택

| API | 파라미터 | 성공·오류 |
| --- | --- | --- |
| GET `/v1/places` | 필수 `q`: 공백 정규화 후 2–100자. `page`: 기본 1, 1–45 | 200 `{data:{places:[{providerPlaceId,name,address,latitude,longitude}],hasMore}}`. 페이지당 최대 15개 |
| GET `/v1/places/region` | 필수 `latitude`: 33–39, `longitude`: 124–132. 유한한 수 | 200 `{data:{cityCode,city}}`. 행정 지역 없으면 422 |

두 API는 로그인 필요(401)입니다. 잘못된 입력 400, 분당 회원 30회·공급자 120회 또는 같은 검색 진행 중 429, 카카오 오류 502, Redis 장애·키 미설정 503입니다. 장소 제한의 429는 `Retry-After` 헤더를 보장하지 않습니다. 인증용 요청 제한과 별도입니다.

모임 등록·수정의 선택 필드 `place`는 `{providerPlaceId,name,address,latitude,longitude,cityCode,city,detail?}`입니다. ID는 숫자 1–30자리, 이름 최대 200자, 주소 최대 500자, cityCode는 숫자 5자리, city 최대 40자, detail 최대 200자입니다. 좌표 범위는 위와 같습니다. `place`가 있으면 `city`·`venue`는 장소의 `city`·`name`으로 덮어쓰지만 DTO 필수 필드인 `city`·`venue`도 보내야 합니다. 검색 결과를 선택한 후 region 조회로 cityCode·city를 가져옵니다. 서버는 입력 형식을 검증하며 선택 장소를 카카오에서 재조회해 진위를 보장하지는 않습니다.

## 취소와 삭제

| 동작 | 경로·본문 | 시점·조회·보관 |
| --- | --- | --- |
| 모임 취소 | DELETE `/v1/events/{id}`, `{reason}` | 주최자·시작 전. `cancelled`로 저장, 상세·내 참여 목록 유지 |
| 주최 모임 삭제 | DELETE `/v1/events/{id}/host`, 본문 없음 | 주최자·시작 시각 무관. `deleted`로 저장, 공개·내 목록·상세·주최자 조회 제외. 관련 이력 보존 |

두 동작 모두 성공 204, 미로그인 401, 타 주최자 403, 없는/삭제된 모임 404입니다. 취소 시 시작 후 409, 잘못된 취소 본문 400입니다. 삭제 반복 요청은 404이며 물리 삭제·이미지 파일 정리는 수행하지 않습니다. 상세 계약은 [주최 모임 삭제](EVENT_DELETION.md)를 참조합니다.

## 오류와 요청 제한

응답 본문의 고정 `error.code`/`message` 계약은 없습니다. HTTP 상태를 먼저 확인하고 환경에 따라 달라지는 Spring Boot 기본 오류 본문에 의존하지 않습니다.

| 상태 | 현재 의미 |
| --- | --- |
| 400 | JSON/파라미터/DTO 검증, 잘못된 인증·재설정 코드 |
| 401 / 403 | 로그인 필요 / 요청 보호 헤더·Origin 거부·권한·프로필 미완료 |
| 404 / 409 | 없거나 접근 불가·삭제된 대상 / 중복·상태·정원 변경·탈퇴 제약 |
| 413 / 422 | multipart 크기 초과 / 업무 검증·이미지·지역 오류 |
| 429 | 요청 횟수·재발송·코드 시도·장소·이미지 동시 처리 제한 |
| 502 / 503 / 507 | 장소 공급자 오류 / 메일·Redis 등 의존 서비스 불가 / 이미지 저장 한도 |

로그인 IP 30회·이메일 10회/15분, 가입·재발송·재설정 메일 IP 20회·이메일 5회/1시간, 인증·재설정 확인 IP 60회·이메일 10회/15분이 기본값입니다. IP·이메일 횟수 초과는 429와 `Retry-After`(초)를 반환합니다. 코드 오입력·재발송 간격 등 모든 429에 이 헤더가 있는 것은 아닙니다. 제한값은 환경 설정에 따라 변경될 수 있습니다. [인증 요청 보호](AUTH_REQUEST_PROTECTION.md)를 참조합니다.

## 연동 예시

```sh
# 검색어 URL 인코딩, 같은 API 서버의 쿠키 사용
curl --get --data-urlencode 'q=포항 공대' --data-urlencode 'page=1' -b cookies.txt http://localhost:8080/v1/places
curl --get --data-urlencode 'latitude=36.012' --data-urlencode 'longitude=129.323' -b cookies.txt http://localhost:8080/v1/places/region
# 테스트 모임 취소: eventId를 실제 테스트 모임 UUID로 대체
curl -X DELETE -b cookies.txt -H 'X-Eolssu-Request: 1' -H 'Content-Type: application/json' -d '{"reason":"일정 변경"}' http://localhost:8080/v1/events/eventId
```

모임 등록·수정 본문 예시입니다. 아래 시각은 예시이므로 실행 시 미래 시각으로 바꿉니다. `thumbnailId`는 업로드 응답의 ID, `place`는 장소 검색·region 조회 결과로 구성합니다.

```json
{
  "title": "포항 문화 산책 모임",
  "descriptionKo": "한국 학생과 국제학생이 함께 포항의 문화와 대학 생활을 이야기합니다.",
  "startsAt": "2026-11-01T05:00:00Z",
  "recruitmentEndsAt": "2026-10-31T05:00:00Z",
  "city": "포항",
  "venue": "대학 정문",
  "category": "culture",
  "capacityKorean": 3,
  "capacityInternational": 3
}
```

Activity 응답은 `{favorite,participating,quotaGroup,favorites,koreanJoined,internationalJoined,demo,demoJoinable}`입니다. quotaGroup은 신청 이력이 없으면 null일 수 있습니다. 한국 그룹은 현재 국적 문자열을 trim·소문자화해 `대한민국`, `한국`, `south korea`, `republic of korea`, `kr`, `korea` 중 하나인지 검사합니다. 그 외는 international이며 정식 국적 분류 정책은 별도 합의 대상입니다.

```ts
const response = await fetch(`${apiBase}/v1/events/${eventId}/participation`, {
  method: "POST",
  credentials: "include",
  headers: { "X-Eolssu-Request": "1" },
});
if (!response.ok) throw new Error(`HTTP ${response.status}`);
const activity = await response.json(); // Activity 직접 반환
// DELETE 성공은 204이므로 response.json()을 호출하지 않습니다.
```
