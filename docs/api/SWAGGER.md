# Swagger · OpenAPI 사용 안내

기준: 2026-10-08. 실제 Controller·DTO로 생성하는 개발 문서이며 배포/운영 검증과 구분합니다.

## 접속과 환경

| 환경 | UI·명세 | 로컬 신고 처리 |
| --- | --- | --- |
| local / docker | `/swagger-ui/index.html`, `/swagger-ui.html`, `/v3/api-docs`, `/v3/api-docs.yaml` | 있음 (관리자 인증 없는 시연 기능) |
| dev | 위 UI·명세 제공 | 없음 |
| prod / 기타 프로필 | 기본 비활성 | 없음 |

로컬 UI: [Swagger](http://localhost:8080/swagger-ui/index.html). 로컬 JSON: [OpenAPI](http://localhost:8080/v3/api-docs). UI 리소스는 springdoc 패키지에 포함되어 CDN 없이 실행됩니다. 서버 URL은 `/`이며 현재 API 출처를 사용합니다. 운영 서버에는 문서를 활성화하지 않습니다.

[API 명세서](API_SPEC.md)는 업무 계약, [openapi.json](openapi.json)은 다운로드·도구 가져오기용 스냅샷입니다. 스냅샷은 현재 로컬 소스의 dev 프로필에서 생성하므로 local/docker 신고 경로는 포함하지 않습니다. 계정 관리·주최 모임 삭제는 로컬 구현을 포함하며 원격 코드·배포 서버의 제공 여부를 의미하지 않습니다.

## Try it out

1. 개발 환경의 `WEB_ORIGIN`에 웹 출처와 **Swagger를 여는 API 출처**를 등록합니다. 로컬 예: `http://localhost:3000,http://localhost:8080`. 경로·끝 슬래시·와일드카드를 넣지 않습니다. Docker는 설정 변경 후 API 컨테이너를 재생성합니다.
2. 학교 이메일 가입 → Mailpit/테스트 수신함 코드 확인 → 인증 또는 기존 인증 계정의 로그인 API를 실행합니다.
3. 변경 API의 `X-Eolssu-Request` 입력을 `1`로 둡니다. 브라우저가 같은 API 출처의 HttpOnly 쿠키를 자동 전송합니다.
4. `/v1/me`로 로그인 상태를 확인합니다. 프로필 작성 후 모임 등록·참여·업로드를 실행합니다.
5. 테스트용 계정과 모임을 사용하고, 취소·삭제·탈퇴 전에 해당 API의 설명을 확인합니다.

`Authorize`에 JWT를 복사할 필요가 없습니다. Bearer 인증은 지원하지 않으며 쿠키를 JavaScript로 직접 설정하는 흐름도 사용하지 않습니다. 접근 JWT는 15분, refresh 세션은 7일이며 refresh 시 접근 쿠키를 다시 발급합니다. JSON 변경 요청뿐 아니라 multipart·본문 없는 POST/DELETE에도 보호 헤더가 필요합니다.

## 생성·검증

Java 21로 API 저장소에서 실행합니다. 외부 DB/메일에 연결하지 않는 H2 dev 프로필 테스트에서 실제 `/v3/api-docs`를 받아 저장합니다.

```sh
./mvnw -Dtest=OpenApiDevelopmentTests -Deolssu.openapi.output=docs/api/openapi.json test
./mvnw -Dtest=OpenApiDevelopmentTests,ProductionPackageIsolationTests test
```

첫 명령은 Swagger 리소스, 실행 프로필별 경로, 보호 헤더, 장소 API, 응답 스키마 및 모든 로컬 `$ref` 해석을 검증합니다. 두 번째 명령은 운영 프로필에서 UI·JSON 문서·시연 API가 노출되지 않는지 추가 확인합니다. 정적 JSON을 손으로 수정하지 않고 Controller·DTO·OpenApiConfig 수정 후 재생성합니다. 테스트 결과를 확인한 뒤 갱신본을 커밋합니다.

실행 중인 개발 서버 스냅샷을 받으려면 `curl --fail http://localhost:8080/v3/api-docs -o docs/api/openapi.json`을 사용할 수 있습니다. 이 경우 해당 프로필과 생성 날짜를 함께 기록하고, 로컬 시연 경로 포함 여부를 확인합니다.

## 문제 확인

| 증상 | 확인 |
| --- | --- |
| UI/JSON 404 | prod에서는 정상. local/docker/dev 프로필·springdoc 설정·재기동 확인 |
| 변경 요청 403 | `X-Eolssu-Request: 1`, 정확한 API Origin의 WEB_ORIGIN 등록, 업무 권한 확인 |
| 로그인 후 401 | 동일한 호스트/스킴에서 UI 사용, 쿠키·Secure·만료·브라우저 정책 확인 |
| 인증 요청 429 | `Retry-After`가 있으면 해당 초 이후 재시도. 재발송은 최소 60초 |
| 장소 503 | Redis 연결 및 카카오 REST 키 설정 확인. 키를 명세·브라우저에 노출하지 않음 |
| 응답을 JSON으로 읽다가 실패 | 204·로그아웃 빈 본문 또는 이미지 바이너리 여부 확인 |

운영 재설정 메일 수신, PostgreSQL V5 적용, 프록시 IP 신뢰 경계, 두 계정 전체 흐름은 이 문서 테스트의 검증 범위 밖입니다.
