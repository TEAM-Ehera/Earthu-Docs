---
title: "얼쑤 API 명세서"
aliases:
  - "얼쑤 API 명세서"
service: "얼쑤"
team: "에헤라디야"
type: "api-spec"
version: "0.9"
status: "심사 제거 · 등록 즉시 공개 · 세부 운영 검토 중"
created: "2026-09-29"
updated: "2026-10-01"
tags:
  - "얼쑤"
  - "문서/api-spec"
---

# API 명세서 — 얼쑤 v0.9

[← 얼쑤 문서 홈](README.md)

> [!abstract]- 문서 목차
> - [공통 계약](05-api-spec.md#공통-계약)
> - [인증·학교 확인·프로필](05-api-spec.md#인증·학교-확인·프로필)
> - [홈·검색·카드·상세](05-api-spec.md#홈·검색·카드·상세)
> - [신청·마이 이벤트·출석](05-api-spec.md#신청·마이-이벤트·출석)
> - [생성·즉시 공개](05-api-spec.md#생성·즉시-공개)
> - [공개·비공개 댓글](05-api-spec.md#공개·비공개-댓글)
> - [앱 공지방·호스트 개별 방](05-api-spec.md#앱-공지방·호스트-개별-방)
> - [리뷰](05-api-spec.md#리뷰)
> - [폐기·신고·운영 조치](05-api-spec.md#폐기·신고·운영-조치)
> - [마이·정보 패널·공지·지원](05-api-spec.md#마이·정보-패널·공지·지원)
> - [이미지 업로드와 공개](05-api-spec.md#이미지-업로드와-공개)
> - [계약 확인 항목](05-api-spec.md#계약-확인-항목)

> [!note] 제안 계약

## 공통 계약

개발·운영은 독립 API origin·DB·토큰 키·업로드 버킷을 사용한다. 계약과 경로는 공통이며 클라이언트가 임의로 요청 body의 env 값으로 운영 대상을 선택하게 하지 않는다. Java·Spring Boot 전환으로 기존 JSON snake_case·오류 형식·상태 코드를 바꾸지 않는다. Java 필드명/기본 직렬화 및 예외 응답을 명시적으로 매핑한다.

Gateway는 해당 환경의 API로만 라우팅한다. Gateway 도입으로 제품 경로를 변경하지 않으며 데이터 권한·정원·공개 권한 판정은 Spring Boot API가 담당한다. 운영/개발 origin 및 구체적인 Gateway 제품은 [기술 문서](07-tech-stack.md#Gateway와-서비스-분리)를 따른다.

Base path `/v1`, JSON·snake_case, UUID ID, UTC timestamp. 성공 `{data:...}`, 목록 `{data:[],page:{next_cursor:null,has_more:false}}`, 204는 body 없음. 목록 공통 query는 cursor·limit(기본 20, 최대 50)·locale(ko/en). 날짜·모집 상태는 서버 시각과 event.timezone 기준이다.

인증은 Bearer access token. 웹 refresh는 HttpOnly/Secure/SameSite cookie와 Origin/CSRF 검증, 앱 refresh는 OS 보안 저장소를 쓰는 안이다. 접근 토큰 15분·refresh 30일·학교 코드 10분 유효는 제안 수치다. 학교 코드 재전송 60초·5회 실패 제한과 이메일/IP별 제한을 제안한다. 정책 확정 전 기본 보안 설계값으로만 취급한다.

권한: 공개, 로그인(가입 미완료 포함), 회원(학교 인증+프로필 완료+active), 호스트(해당 event.host), 참가자(해당 event의 confirmed), 운영(별도 부여 역할). body의 user_id/role/quota_group을 권한 근거로 사용하지 않는다.

신청·폐기·메시지 전송은 `Idempotency-Key` 필수. 사용자+method+path+key로 24시간 응답 저장 제안. 같은 key/body는 같은 응답, 다른 body는 409. 이벤트·리뷰·광고 수정은 expected_revision으로 충돌 검사한다.

```json
{
  "error": {
    "code": "QUOTA_FULL",
    "message": "해당 모집 구분의 정원이 마감되었습니다.",
    "fields": {},
    "request_id": "req-example"
  }
}
```

400 요청 형식, 401 인증 실패, 403 권한/가입 미완료, 404 접근 불가 비공개 객체, 409 정원/상태/중복/버전 충돌, 422 필드 오류, 429 제한 초과(Retry-After). 알 수 없는 쓰기 필드는 422. 표시 message와 제어용 code를 분리한다.

## 인증·학교 확인·프로필

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| POST /auth/oauth/{provider}/exchange | 공개 | provider=apple/google, `{authorization_code,redirect_uri,code_verifier?,transaction_id}` | 200 Session |
| POST /auth/login | 공개 | `{school_email,password}` | 200 Session |
| POST /auth/school-email/challenges | 공개/로그인 | `{school_email,purpose:"signup"}` | 202 Challenge |
| POST /auth/school-email/challenges/{id}/verify | 공개/로그인 | `{code}` | 200 `{verification_proof,university_match,school_status}` |
| GET /universities | 공개 | q, 목록 query | 200 `{id,name}` 목록 |
| POST /auth/register | 공개/소셜 로그인 | `{verification_proof,university_id?,password?}` | 201 Session(가입 미완료 허용) |
| POST /auth/password-reset/challenges | 공개 | `{school_email}` | 202 동일 안내, 계정 존재 비공개 |
| POST /auth/password-reset/complete | 공개 | `{challenge_id,code,new_password}` | 204 세션 폐기·비밀번호 변경 |
| POST /auth/refresh | 세션 | 웹 cookie / 앱 `{refresh_token}` | 200 Session, refresh 회전 |
| POST /auth/logout | 로그인 | 현재 세션 refresh 증명 | 204 세션/해당 기기 토큰 폐기 |
| GET /me | 로그인 | 없음 | 200 Me |
| PUT /me/profile | 로그인 | ProfileInput | 200 Me, 완료 조건 충족 시 active |
| PATCH /me/profile | 회원 | ProfilePatch | 200 Me |
| DELETE /me | 회원 | `{confirmation:"DELETE"}` | 204, 주최 미해결이면 409 |
| GET /languages | 공개 | locale | 200 `{code,name}` 목록 |
| GET /nationalities | 공개 | locale | 200 `{code,name}` 목록 |

OAuth transaction은 서버 발급 state/nonce에 바인딩하고 provider issuer·audience·서명·redirect를 검증한다. provider_subject로 로그인하며 이메일만 같다는 이유로 계정 병합하지 않는다. 연결/해제 API는 정책 결정 전 제외한다. 이미 등록된 학교 이메일은 409 ACCOUNT_LINK_REQUIRED로 안내하되 기존 계정 접근 증명 없이 연결하지 않는다.

Challenge는 `{id,expires_in,resend_after}`. verification_proof는 검증한 이메일·요청 목적·세션 또는 가입 transaction에 묶인 일회용 불투명 토큰이다. register가 이메일 주소를 body에서 다시 신뢰하지 않는다. 소셜 가입은 현재 세션에 학교 증명을 연결하며 password를 요구하지 않는다. 메일 가입은 password가 필수다. 비밀번호 강도 정책은 추가 확정 대상이고 서버에 원문 저장하지 않는다.

메일 수신 성공과 대학 확인은 분리한다. 미등록 도메인은 pending_university이며 검색한 university_id를 접수한 뒤 운영 검증 전까지 참가·주최를 막는다. 알려진 비학교 도메인은 422 SCHOOL_EMAIL_REQUIRED. 매핑 대학과 다른 university_id는 422 UNIVERSITY_MISMATCH. 인증 proof 사용 후 학교 확인 대기여도 가입 이어하기 세션은 발급 가능하다.

`Session={access_token,expires_in,account_state,required_steps,user_id}`. 앱만 refresh_token body 제공, 웹은 cookie. required_steps는 school_verification/university_confirmation/profile 중 필요한 값이다.

`ProfileInput={name,university_id,nationality_code,primary_language,secondary_language,gender,interests?,ui_locale}`. secondary_language는 **키 필수, null 허용**. gender=male/female/others/none. ui_locale=ko/en. 프로필 국적은 선택형 필수로 해석한다. university_id는 검증된 학교 인증의 대학과 일치해야 하며, pending_university 상태에서는 프로필 저장만으로 active가 되지 않는다. 언어 코드 목록은 `/languages`로 관리하며 UI locale과 별도다.

`ProfilePatch`는 name·primary_language·secondary_language·gender·interests·ui_locale만 초기 허용한다. 대학·학교 메일 변경은 재인증 설계 후 추가, nationality_code 변경은 진행 중 참가 정원 정책 확정 전 409 NATIONALITY_CHANGE_REQUIRES_REVIEW 제안이다. 변경 경로가 필요하다는 점은 결정 로그에 남긴다.

`Me={id,account_state,required_steps,school_verification:{status,university_id,school_email},profile:null|ProfileInput}`. 완성 프로필은 PUT으로 저장하고 불완전 입력은 422. 가입 미완료 draft는 클라이언트에서 유지하는 안이다.

## 홈·검색·카드·상세

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| GET /home/info-cards | 공개 | locale | 200 InfoCard 목록 |
| GET /events/discovery | 공개 | locale, limit | 200 `{popular:EventCard[],recent:EventCard[],popular_available:boolean}` |
| GET /events | 공개 | `q?,city_code?,category_id?,sort?`+목록 query | 200 EventCard 목록 |
| GET /events/{id} | 공개/소유자 | locale | 200 EventDetail |
| GET /categories | 공개 | locale | 200 `{id,code,name}` 목록 |
| GET /cities | 공개 | q, locale | 200 `{code,name,official_name}` 목록 |
| GET /places/search | 회원 | q, city_code?, cursor? | 200 Place 목록 |
| PUT /events/{id}/bookmark | 회원 | body 없음 | 204, 중복도 동일 |
| DELETE /events/{id}/bookmark | 회원 | body 없음 | 204 |
| GET /me/bookmarks | 회원 | 목록 query | 200 EventCard 목록 |

q는 이벤트명만 검색, 최대 100자. 필터는 AND. sort=recent가 기본이며 최근은 published_at DESC,id DESC 제안. 인기 알고리즘 미정이므로 `popular_available=false,popular=[]`는 미구성 상태를 정직하게 나타내는 계약이다. 사용자에게 제공할 인기 영역은 알고리즘 확정 후 populated되어야 한다. 인기 요구사항을 최근 목록으로 대체하지 않는다. 최근 검색어는 기기 로컬 저장·최대 10개·중복 최신 이동·삭제 가능 제안이라 서버 API 없음.

`InfoCard={id,kind,title,body?,image_url?,target_url?,position}`. 예약/게시 상태는 서버에서 필터한다. target_url은 관리자에게도 허용 scheme·대상 검증을 적용한다.

`Host={id,name,university:{id,name},nationality:{code,name}}`. 학교 메일·성별·비밀번호는 절대 포함하지 않는다.

`EventCard={id,thumbnail_url,host:Host,category:{id,name},title,starts_at,ends_at,timezone,place:{name,city_code,city_name,latitude,longitude},quotas:[Quota],is_bookmarked,recruitment_status,can_report}`. 모집 정확한 마감 일시는 상세에서만 렌더링한다. Quota는 `{group:"korean"|"international",capacity,confirmed_count,remaining_count}`. 카드 상태는 recruiting/closed로 표시하고 내부 원인은 before_start/quota_full/deadline/ended/cancelled/removed 중 별도 `availability_reason`으로 전달하는 안이다.

`EventDetail`은 Card에 `{address,recruitment_start,recruitment_end,description_ko,description_en,resolved_description_locale,publication_status,lifecycle_status,revision,my_participation,review_action,my_review_id,can_join,can_cancel,can_edit,chat_available}`를 추가한다. chat_available은 플랫폼·참가 권한·운영 상태에 따라 계산한다. review_action=write/view/none. 미작성 언어 원문 fallback은 표시용이며 입력 원문을 덮어쓰지 않는다.

비공개 이벤트는 소유자/운영자만, 일반 요청은 404. 폐기 이벤트는 기존 참가자/호스트에 한해 EventUnavailable 응답을 반환하고 공개 목록에서 제외한다. 원문 열람은 운영자 조사 권한만 허용한다.

## 신청·마이 이벤트·출석

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| POST /events/{id}/participations | 회원 | body 없음, Idempotency-Key | 201 Participation |
| DELETE /events/{id}/participations/me | 회원 | 없음 | 204 취소, 반복도 동일 |
| GET /me/events | 회원 | `tab=past\|upcoming\|bookmarked\|hosted`+목록 query | 200 MyEventItem 목록 |
| GET /events/{id}/participants | 호스트/운영 | status?+목록 query | 200 `{participation,user:{id,name}}` 목록 |
| PUT /participations/{id}/attendance | 호스트/운영 | `{attendance:"attended"\|"no_show"\|"unknown"}` | 200 Participation |

`Participation={id,event_id,user_id,quota_group,status,attendance,confirmed_at,cancelled_at,cancellation_source}`. status=confirmed/cancelled. quota_group은 body에서 받지 않는다. 오류: QUOTA_FULL(409), RECRUITMENT_CLOSED(409), EVENT_UNAVAILABLE(409), ALREADY_PARTICIPATING(409), HOST_CANNOT_JOIN(422), ONBOARDING_INCOMPLETE(403).

`MyEventItem={event:EventCard|EventUnavailable,participation:null|Participation,publication_status?,rejection_reason?,submission_state?,review_action?,primary_action,secondary_actions}`. primary_action=event_detail/event_rooms/write_review/view_review/rewrite/view_host_reviews/view_unavailable. 웹 upcoming은 event_detail, 앱은 event_rooms. 폐기 안내가 우선한다. my events는 폐기된 이벤트를 inner join 공개 목록 조건 때문에 누락하면 안 된다.

참가 자동 확정·출석 입력 가능 기간은 제안 정책이다. 종료 후 실제 출석 확인 여부를 리뷰 자격에 사용할 경우 운영 화면에서 출석을 처리할 수 있어야 한다.

## 생성·즉시 공개

게시 전 심사, submit/start-review/decision/rewrite/moderation-history 계약은 제거한다. 수정·취소 API는 운영 정책 확정 후 별도 구현한다.

현재 구현 계약:

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| POST /v1/events | 학교 인증·프로필 완료 회원 | EventInput | 201 `{data:Event}`, status=published |
| GET /v1/events | 공개 | q?,city?,category?,sort=recent/popular | 200 `{data:Event[]}`, published만 반환 |
| GET /v1/events/{id} | 공개 | 없음 | 200 `{data:Event}`, 비공개는 404 |

현재 `EventInput={title,descriptionKo,descriptionEn?,startsAt,recruitmentEndsAt,city,venue,category,capacityKorean,capacityInternational,thumbnailId?}`. 호스트는 세션에서 서버가 설정한다. 공개 등록 후 즉시 참여 가능하며 참여 권한·정원·일정 검증은 유지한다. 과거 상태는 Flyway V2 또는 로컬 초기 변환으로 published로 전환한다. `/v1/local/events/{id}/approve`는 삭제했다.

사후 관리자 모임 숨김·신고 처리 API는 아래 운영 조치 설계로 유지한다. 승인 기능과 혼동하지 않는다.

## 공개·비공개 댓글

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| GET /events/{id}/comment-threads | 공개/회원 | visibility=public/private, 목록 query | 200 CommentThread 목록 |
| POST /events/{id}/comment-threads | 회원 | `{visibility,body}` | 201 CommentThread |
| GET /comment-threads/{id}/comments | 스레드 접근자 | 목록 query | 200 Comment 목록 |
| POST /comment-threads/{id}/comments | 회원/비공개 접근자 | `{body}` | 201 Comment |
| DELETE /comments/{id} | 작성자 | 없음 | 204 tombstone |

`CommentThread={id,event_id,author:{id,name},visibility,comments_count,created_at}`. `Comment={id,thread_id,author:{id,name},body,status,created_at}`. body 1~1000자 제안. private 목록은 작성자 본인 또는 event.host일 때만 자신의 허용 스레드를 반환하며 다른 스레드 수를 누출하지 않는다. 비회원 private 요청은 401. 임의 UUID 스레드 접근은 404. private 답변도 비공개를 상속한다. 댓글과 앱 채팅 간 자동 메시지 복사는 하지 않는다.

## 앱 공지방·호스트 개별 방

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| GET /me/chat-events | 회원 | 목록 query | 200 `{event:EventCard,unread_count}` 목록 |
| GET /events/{id}/conversations | 호스트/참가자 | 목록 query | 200 Conversation 목록 |
| GET /conversations/{id}/messages | 방 접근자 | before?,limit | 200 Message 목록 |
| POST /conversations/{id}/messages | 방 쓰기 권한자 | `{client_message_id,body}`, Idempotency-Key | 201 Message |
| PUT /conversations/{id}/read | 방 접근자 | `{last_read_message_id}` | 204 |
| DELETE /messages/{id} | 작성자 | 없음 | 204 tombstone |

`Conversation={id,event_id,kind,participant:null|{id,name},can_read,can_write,unread_count}`. kind=announcement/host_direct. 호스트는 모든 참가자의 개별 방, 참가자는 자신의 개별 방만 받는다. 공지방은 참가자의 can_write=false이며 직접 POST에도 403 ANNOUNCEMENT_WRITE_FORBIDDEN. host_direct는 쌍방 작성한다.

`Message={id,conversation_id,sender:{id,name},client_message_id,body,status,created_at}`. body 1~2000자 제안. client_message_id 중복+동일 내용은 기존 응답, 다른 내용 409. 조회는 최신부터 cursor를 사용하며 재접속 후 id로 중복 제거한다. 메시지 실시간 전달 방식은 미정이고 REST를 복구 기준으로 둔다. 웹 MVP에는 이 API의 UI를 연결하지 않는다. 역할 권한은 클라이언트 종류와 무관하게 서버에서 검사한다.

## 리뷰

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| GET /events/{id}/reviews | 공개/호스트 | 목록 query | 200 Review 목록 |
| GET /events/{id}/reviews/me | 회원 | 없음 | 200 Review, 없으면 404 |
| POST /events/{id}/reviews | 자격 참가자 | `{rating,body}` | 201 Review |
| PATCH /reviews/{id} | 작성자 | `{rating?,body?,expected_revision}` | 200 Review |
| DELETE /reviews/{id} | 작성자 | `{expected_revision}` | 204 |

`Review={id,event_id,author:{id,name},rating,body,status,revision,created_at,updated_at}`. rating 1~5, body 최대 1000자 제안. 최초 작성/삭제 후 복원은 자격을 재검사한다. 활성 중복 409 REVIEW_ALREADY_EXISTS, 비자격 403 REVIEW_NOT_ELIGIBLE, 운영자 숨김 후 자동 복원 409 REVIEW_MODERATED. 삭제 후 복원 허용은 미확정 제안이며 기능명세와 함께 변경한다.

## 폐기·신고·운영 조치

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| POST /reports | 회원 | `{target_type,target_id,reason_code,description?}` | 201 Report |
| GET /me/reports | 회원 | 목록 query | 200 Report 목록 |
| GET /admin/reports | 운영 | status?+목록 query | 200 ReportAdmin 목록 |
| PATCH /admin/reports/{id} | 운영 | `{status,resolution?}` | 200 ReportAdmin |
| POST /admin/events/{id}/remove | 운영 | `{public_reason,internal_reason?,expected_revision}`, Idempotency-Key | 201 Disposition |
| GET /events/{id}/unavailability | 기존 참가자/호스트 | 없음 | 200 EventUnavailable |
| GET /me/event-notices | 회원 | 목록 query | 200 EventUnavailable 목록 |
| PUT /me/event-notices/{disposition_id}/read | 안내 대상 | 없음 | 204 |
| GET /admin/event-dispositions/{id}/deliveries | 운영 | 목록 query | 200 `{recipient_id,status,attempts,last_error?}` 목록 |
| POST /admin/event-dispositions/{id}/retry-delivery | 운영 | `{recipient_ids?}` | 202 `{queued_count}` |
| PUT /admin/content/{type}/{id}/visibility | 운영 | `{visibility,reason}` | 204 |
| PUT /admin/users/{id}/status | 운영 | `{status,reason}` | 204 |

Report target_type=event/user/message/comment/review. Report=`{id,target_type,target_id,reason_code,status,created_at,resolved_at}`. ReportAdmin에만 reporter_id·description·증거·resolution을 추가한다. 신고된 내용은 제출자가 접근할 수 있는 대상으로 한정한다. status=open/in_progress/resolved/dismissed, 완료 시 resolution 필수. 채팅 호스트 신고는 user, 메시지 신고는 message 사용.

`Disposition={id,event_id,kind,public_reason,created_at}`. `EventUnavailable={id,title_snapshot,starts_at_snapshot,availability:"unavailable",kind,public_reason,disposed_at,disposition_id,contact_available:true}`. 일반 삭제 404와 달리 기존 참가자용 제한 DTO로 200을 반환하여 안내를 유지한다. internal_reason·신고자·증거를 포함하지 않는다.

삭제/폐기 API는 event의 상태와 참가자 기록·안내 outbox를 원자적으로 처리한다. 전달 실패는 폐기 결과를 되돌리지 않는다. 폐기 사유는 기존 참가자와 호스트에게 안내한다. type=message/comment/review 콘텐츠 숨김, user status=active/suspended. 신고 접수만으로 자동 이벤트 폐기 없음.

## 마이·정보 패널·공지·지원

| Method / path | 권한 | 요청 | 성공 |
|---|---|---|---|
| GET /me/notifications | 회원 | 목록 query | 200 Notification 목록 |
| PUT /me/notifications/{id}/read | 본인 | 없음 | 204 |
| GET /me/notification-settings | 회원 | 없음 | 200 Settings |
| PATCH /me/notification-settings | 회원 | `{push_enabled?,chat_enabled?}` | 200 Settings |
| PUT /me/device-tokens | 로그인 | `{token,platform}` | 200 `{id,enabled:true}` |
| DELETE /me/device-tokens/{id} | 본인 | 없음 | 204 |
| POST /support-tickets | 회원 | `{subject,body}` | 201 SupportTicket |
| GET /me/support-tickets | 회원 | 목록 query | 200 SupportTicket 목록 |
| GET /admin/support-tickets | 운영 | status?+목록 query | 200 SupportTicket 목록 |
| PATCH /admin/support-tickets/{id} | 운영 | `{status,reply?}` | 200 SupportTicket |
| GET /announcements | 공개 | 목록 query | 200 Announcement 목록 |
| GET /announcements/{id} | 공개 | locale | 200 Announcement |
| POST /admin/announcements | 운영 | AnnouncementInput | 201 Announcement |
| PATCH /admin/announcements/{id} | 운영 | AnnouncementInput 일부 | 200 Announcement |
| GET /policies | 공개 | document_type?,version?,locale | 200 Policy 목록 |
| POST /me/consents | 로그인 | `{policy_version_ids:[]}` | 204 |
| POST /admin/policy-versions | 운영 | PolicyInput | 201 Policy |
| GET /admin/info-cards | 운영 | status?+목록 query | 200 InfoCardAdmin 목록 |
| POST /admin/info-cards | 운영 | InfoCardInput | 201 InfoCardAdmin |
| PATCH /admin/info-cards/{id} | 운영 | InfoCardInput 일부+expected_revision | 200 InfoCardAdmin |
| POST /media | 회원/운영 | multipart: `purpose,file`, Idempotency-Key | 201 MediaAsset |
| GET /media/{id}/status | 소유자/운영 | 없음 | 200 MediaAsset |
| GET /media/{id}/preview | 소유자/운영 | variant=card/detail | 200 `{url,expires_at}` |
| GET /admin/student-verifications | 운영 | status?+목록 query | 200 대기 학교 인증 목록 |
| POST /admin/student-verifications/{id}/decision | 운영 | `{decision,university_id,reason?}` | 200 `{id,status,university_id}` |

학교 검증 운영 API는 알려지지 않은 학교 도메인을 처리하기 위한 제안이다. 대학명 검색·선택을 허용하면서 일반 메일 우회를 막기 위한 보완이며 운영 승인 여부는 추가 회의로 확정한다.

`Notification={id,type,target:{type,id},created_at,read_at}`. `Settings={push_enabled,chat_enabled}`. `SupportTicket={id,subject,body,status,reply,replied_at,created_at}`. subject 5~100자, body·reply 최대 3000자 제안. 해결 시 reply 필수.

`AnnouncementInput={title_ko,body_ko,title_en?,body_en?,published_at?}`. Announcement 응답은 `{id,title,body,resolved_locale,published_at}`. `PolicyInput={document_type,version,locale,body,effective_at,required}`. Policy 응답은 Input+id, 동일 (type,version,locale) 불변. 필수 정책 동의 누락은 참가·생성 403 CONSENT_REQUIRED, 문의·탈퇴는 차단하지 않는다.

`InfoCardInput={kind,title_ko,title_en?,body_ko?,body_en?,image_asset_id?,target_url?,position,status,starts_at?,ends_at?}`. kind=ad/information/other, status=draft/published/archived. InfoCardAdmin은 Input+id+revision. 게시 종료는 archive로 처리, 노출 시간은 서버 필터. ko 제목 필수·en fallback은 제안이며 광고 표기 규칙은 회의 대상이다.

## 이미지 업로드와 공개

초기 구현은 Spring Boot 업로드·검증·압축 → R2 비공개 저장이다. 기존 upload-tickets/브라우저 직접 업로드 안을 대체한다. 다른 제품 API는 JSON이지만 `POST /media`는 multipart/form-data 예외다. purpose=event_thumbnail/info_card이며 후자는 운영자만 허용한다.

JPEG/PNG/WebP 최대 5MB와 별도 픽셀 수 제한을 초기 제안으로 둔다. 헤더의 content_type만 신뢰하지 않고 실제 디코딩한다. 카드/상세 처리본을 WebP로 생성하며 처리 완료 후에만 201을 반환한다. 처음에는 작은 파일의 동기 처리로 시작하고 제한된 변환 동시성을 적용한다. 오래 걸리면 연결을 무제한 유지하지 않고 제한 시간·복구 가능한 실패를 반환한다.

`MediaAsset={id,purpose,status,publication_status,variants:[{kind,content_type,width,height,size_bytes}],created_at}`. status=processing/ready/failed, publication_status=private/publishing/public/revoking. 비공개 R2 경로·자격증명은 응답하지 않는다. `preview`는 권한 검사 후 짧은 유효기간의 읽기 URL을 발급한다. 미리보기 서명 URL은 업로드용 서명 URL과 다르다.

같은 Idempotency-Key와 같은 파일 해시·purpose는 같은 결과를 반환하며 다른 파일이면 409 IDEMPOTENCY_CONFLICT. 동일 키 작업 진행 중은 409 UPLOAD_IN_PROGRESS로 재시도 안내한다. 실패 후 생성된 부분 객체를 추적하여 정리한다.

413 FILE_TOO_LARGE, 422 INVALID_IMAGE/IMAGE_DIMENSIONS_EXCEEDED, 403 ASSET_ACCESS_DENIED, 409 ASSET_NOT_READY, 503 MEDIA_STORAGE_UNAVAILABLE를 정의한다. 이벤트/패널 저장 시 소유자·purpose·ready 상태를 검사한다. 임의 URL이나 타인 asset ID를 썸네일로 연결하지 않는다.

모임 등록/패널 게시 후 공개 복사 작업은 서버 outbox로 처리한다. `published`가 되었다고 이미지 준비 전에 공개 목록에 노출하지 않는다. 공개 작업은 해당 published_version과 최신 운영 상태를 확인하고, 완료 후 EventCard.thumbnail_url을 공개 주소로 반환한다. 호스트/운영자 DTO에는 `media_publication_status`를 추가하여 준비·실패를 확인하게 한다. 외부 공개에는 ready/public 자산만 제공한다.

게시 준비 중의 재시도는 동일 객체 키에 대해 멱등이며 폐기·취소 후 뒤늦게 실행된 공개 작업은 중단한다. 공개 객체만 생성되고 DB 확정이 실패한 경우에도 정리/재시도로 일치시킨다. 이미지 삭제가 필요한 신고 조치는 객체 접근 제거와 캐시 무효화를 함께 처리한다.


## 계약 확인 항목

권한 없는 private 댓글/타인 채팅 접근, 공지방 참가자 쓰기, 학교 미인증 신청, 그룹 정원 동시 신청, 수정·참여 경합, 리뷰 수정/삭제 충돌, 폐기 후 사유 DTO와 재전송 중복을 구현 후 검증한다. 이 절은 목표 계약의 검증 목록이다. 현재 로컬 구현의 학교 메일 코드 인증과 호스트 권한은 별도로 통합 확인했으며, 나머지 기능은 미구현이다.

---

## 연결 문서

- [얼쑤 문서 홈](README.md)
- [얼쑤 PRD](01-prd.md)
- [얼쑤 정보구조도](02-ia.md)
- [얼쑤 기능명세서](03-functional-spec.md)
- [얼쑤 ERD](04-erd.md)
- [얼쑤 결정 로그](06-decisions.md)
- [얼쑤 기술 스택·배포](07-tech-stack.md)

## 현재 로컬 API 구현 메모 (2026-09-30)

> [!warning] 목표 계약과 로컬 구현의 차이
> 위 `/auth/school-email/challenges`와 proof 기반 가입은 목표 설계다. 현재 로컬 시연은 아래 단순 계약을 사용한다. 앱·운영 배포 전에 통합 계약과 학교 검증 정책을 다시 확정한다.

| 메서드·경로 | 현재 로컬 동작 |
|---|---|
| `POST /v1/auth/register` | `{email,password}`. `.ac.kr`·`.edu`만 허용, 기본 Mailpit/선택 Gmail SMTP로 6자리 HTML·텍스트 코드 발송. 201, 발송 실패 503 |
| `GET /v1/auth/school-email?email=...` | 도메인 접미사 검증, 알려진 대학 도메인 매핑 반환 |
| `POST /v1/auth/resend` | `{email}`. 60초 간격 제한 |
| `POST /v1/auth/verify` | `{email,code}`. 10분/최대 5회, 성공 시 HttpOnly 세션 쿠키 |
| `POST /v1/auth/login` / `POST /v1/auth/logout` | 학교 인증 회원의 비밀번호 로그인/세션 폐기 |
| `GET /v1/me` | 인증 회원과 프로필 완료 상태 |
| `PATCH /v1/me/profile` | 이름·대학·국적·언어·성별·관심사 저장. 알려진 도메인만 대학 자동 매핑 |
| `GET /v1/me/events` | 본인이 호스트인 모임 목록 |
| `POST /v1/events` | 인증과 프로필 완료 필요, 호스트 ID/정보는 서버에서 설정. 등록 즉시 published 공개 |
| `POST /v1/media`, `GET /v1/media/{id}` | 인증 회원의 이미지 업로드 및 공개 조회. 현재는 로컬 파일/볼륨 저장 |

로컬 신고 처리 API는 아직 관리자 인증이 없으므로 외부 서버에 `local`·`docker` 프로필을 공개하지 않는다. Mailpit은 실제 대학 메일 발송 수단이 아니다. 미등록 `.ac.kr`·`.edu` 도메인을 한국 대학 소속으로 판정하는 기능도 아직 없다.

### 로컬 확장 구현 메모 (2026-09-30)

> [!info] 시연 계약
> 아래 경로는 위의 목표 계약을 모두 구현한 것이 아니라 로컬 웹에서 사용하는 현재 계약이다. 샘플 모임 6개 중 3개는 `demoJoinable=true`이며, 참가 기록은 데모 상태로만 사용한다. 등록 즉시 공개하며 실제 출석 확인과 사후 운영자 권한은 아직 없다.

| 메서드·경로 | 로컬 동작 |
|---|---|
| `GET /v1/events?sort=recent\|popular` | 공개 모임을 등록 시각 또는 관심 수로 정렬 |
| `GET /v1/events/{id}/activity` | 관심 여부·참여 여부·한/국제학생 신청 수·데모 여부 |
| `POST/DELETE /v1/events/{id}/favorite` | 인증 회원 관심 등록/해제 |
| `POST/DELETE /v1/events/{id}/participation` | 인증 회원 신청/취소. 모집 기간·호스트 제외·그룹 정원 검사, DB 잠금 |
| `GET/POST /v1/events/{id}/comments` | 공개 댓글과 작성자·호스트만 볼 수 있는 비공개 댓글, 답글 |
| `DELETE /v1/events/{id}/comments/{commentId}` | 작성자 삭제. 답글이 있으면 삭제 표시 유지 |
| `GET/POST /v1/events/{id}/reviews` | 후기 조회/작성. 시작 후 활성 참여 이력 1건 필요 |
| `PATCH/DELETE /v1/events/{id}/reviews/me` | 내 후기 수정/삭제 |
| `POST /v1/reports` | 모임·댓글 신고 접수, 동일 대상 중복 신고 방지 |
| `GET /v1/me/participations`, `/favorites`, `/reports` | 내 참여·관심·신고 목록 |
| `GET /v1/local/reports`, `PATCH /v1/local/reports/{id}` | 로컬 전용 신고 목록/처리. 관리자 인증 없음 |

로컬 `docker`/`local` 프로필의 무인증 신고 처리 API를 공개 서버에 배포하지 않는다. 데모 참여는 실제 예약·알림·호스트 연결이 없고, 후기 자격은 출석이 아니라 활성 참여 이력으로 판정한다. 정식 정책은 [결정 로그](06-decisions.md)에서 확정해야 한다.

> [!info] 실제 구현과 구조
> 설계와 현재 코드의 차이는 [작업 현황과 다음 개발](08-work-status.md), 실제 패키지·동작·런타임 DB는 [백엔드 아키텍처](09-backend-architecture.md)에서 확인한다.
