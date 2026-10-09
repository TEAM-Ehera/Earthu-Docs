---
title: 운영 서버 배포 및 API 연결
tags: [얼쑤, 운영, 배포]
status: 배포 완료
updated: 2026-10-08
---

# 운영 서버 배포 및 API 연결

## 404 원인과 수정

운영 Vercel 환경에는 API_ORIGIN이 없었다. develop Preview에만 값이 있어 운영 웹의 /v1 요청에 rewrite가 생성되지 않았다. Production API_ORIGIN을 아래 운영 API로 설정하고 웹 main을 develop의 검증된 코드로 갱신하여 재배포했다.

- 운영 웹: https://earthuu.vercel.app
- 운영 API: https://api.129.225.175.229.sslip.io
- Vercel 배포: HAm392tAahWHmswq9ifh4FvpEfeC / Production Ready.
- 웹 코드: 2160c4a. API 실행 이미지: f505ced의 기존 검증된 AMD64 이미지, Spring prod 프로필.

## 구성과 분리

현재 무료 Micro API VM을 개발·운영이 공유한다. 운영 Docker 프로젝트는 eolssu-prod, 컨테이너는 eolssu-prod-api-1, 환경 파일은 /home/ubuntu/eolssu-prod/.env.prod(600)다. 운영 compose는 compose.prod-shared.yaml이다. 개발 프로젝트는 유지한다.

DB VM의 기존 PostgreSQL 인스턴스 안에 운영 DB eolssu_prod와 별도 로그인 계정 eolssu_prod를 생성했다. 개발 DB eolssu_dev를 복사하지 않았다. 운영 미디어는 eolssu-prod_media_data 볼륨에 별도로 저장한다. 운영 환경 파일과 DB 비밀번호는 Git에서 제외한다.

Caddy는 기존 컨테이너를 공유한다. deploy/Caddyfile.shared를 API VM의 /home/ubuntu/eolssu-dev/deploy/Caddyfile에 설치했다. 개발 호스트는 api:8080, 운영 호스트는 prod-api:8080으로 연결하며 운영 API는 기존 eolssu-dev_default 네트워크의 prod-api 별칭을 사용한다. **개발 재배포 시 단일 호스트 Caddyfile로 덮어쓰면 운영 연결이 끊기므로 Caddyfile.shared를 유지해야 한다.**

기존 공인 IP·80/443·SSH·DB 접근 규칙을 그대로 사용한다. 운영 때문에 외부 포트를 추가하지 않았다. 개발·운영은 VM·프록시·Docker 네트워크·PostgreSQL 프로세스를 공유하므로 자원 부족과 서버 장애가 양쪽에 영향을 준다. 추후 A1 또는 별도 서버 확보 후 분리한다.

## 검증

운영 웹 주소를 통해 직접 요청하여 다음 응답을 확인했다.

| 요청 | 결과 |
| --- | --- |
| GET /v1/events?sort=recent | 200, 빈 목록 |
| GET /v1/auth/school-email, POSTECH 도메인 | 200, 포항공과대학교 자동 인식 |
| GET /v1/me, 미로그인 | 401 |
| POST /v1/auth/login, 빈 입력 | 400 |
| POST /v1/auth/register, 빈 입력 | 400 |

API HTTPS 인증서 발급 완료, health UP, 운영 DB Flyway V1/V2 적용 성공. 빈 입력 검증으로 경로 연결만 확인했으며 실제 계정 생성·인증 메일 발송은 하지 않았다. 학교 인증은 사용자가 진행한다. 운영 DB는 비어 있어 모임 0개가 정상이다.

## 남은 작업

- 실제 학교 메일 수신·코드 입력·프로필 생성·로그인·모임 생성·참여 검증.
- DB·미디어 백업 및 복구 검증, 서버 장애 알림.
- 안전한 CI 배포 접속 구성. 현재 백엔드 배포는 수동이며 GitHub runner SSH 자동 배포는 비활성화되어 있다.
- 별도 서버 확보 및 개발·운영 장애/자원 격리.

관련: [[11-development-deployment]], [[08-work-status]], [[10-gmail-setup]].

## 2026-10-07 earthuu 영문 브랜드·대표 주소 전환

Vercel의 기존 `eolssu-web` 프로젝트에 `earthuu.vercel.app`을 등록하고 Production `NEXT_PUBLIC_SITE_URL=https://earthuu.vercel.app`, `NEXT_PUBLIC_API_URL=same-origin`으로 배포했습니다. 웹 배포는 `dpl_ABGmbb2UMVXEUhWHTwZGJVbVB7Un`(Ready)입니다. 영문 화면 표기는 `earthuu`, 한글 표기는 `얼쑤`입니다. API는 기존 HEAD `e606bcc`에 인증 메일 영문 브랜드와 CORS 쉼표 구분 주소 지원만 적용한 `eolssu-api:earthuu-20261007` 이미지입니다. 운영 `WEB_ORIGIN`에 새 주소와 기존 주소를 함께 유지하며 DB 마이그레이션은 변경하지 않았습니다. 카카오 지도는 앱의 JavaScript SDK 도메인에 새 주소를 추가해야 합니다.

새 웹 주소에서 모임 조회 200(2개), 미로그인 `/v1/me` 401, 학교 이메일 조회 200, 빈 로그인 입력 400을 확인했습니다. 새 주소와 기존 주소의 API CORS 응답 모두 정상입니다. 카카오 지도 SDK는 새 주소에서 `401 domain mismatched`를 반환하므로 별도 도메인 등록이 남아 있습니다.

## 2026-10-08 기존 웹 주소 폐쇄

서버 SSH 연결과 운영 API readiness 200을 확인했습니다. 새 주소에서 카카오 지도 SDK 200을 확인한 뒤 Vercel 프로젝트에서 `eolssu-web.vercel.app` 도메인을 제거했습니다. 운영 도메인은 `earthuu.vercel.app`입니다. 기존 웹 주소는 더 이상 서비스를 제공하지 않습니다.


## 2026-10-08 개발 검증 코드 운영 배포

사용자의 운영 배포 요청에 따라 개발 환경에서 검증한 현재 로컬 변경을 운영 프론트·백엔드에도 배포했다. Vercel Production 빌드 `dpl_E3hJZ1YCYnNj3JF5DRih41QUByXj`(Ready)를 promote하여 https://earthuu.vercel.app 에 연결했다. API_ORIGIN은 운영 API, NEXT_PUBLIC_API_URL은 same-origin, NEXT_PUBLIC_SITE_URL은 운영 대표 주소다. 홈 HTML의 canonical과 index/follow를 확인했다.

API 이미지 `eolssu-api:prod-20261008`은 개발에서 테스트한 `dev-20261008`과 동일한 이미지(sha256:754e757a57e8a2996b8ab2901096f992fdb66f970730c5b22359fbea60137a47)이며 prod 프로필로 실행한다. 개발과 별도 운영 DB eolssu_prod·계정 eolssu_prod·Redis·미디어를 유지했다. 기존 JWT_SECRET/JWT_ISSUER를 유지하고 현재 Caddy 내부 IP를 AUTH_TRUSTED_PROXIES에 지정했다. Flyway V5 계정 관리 마이그레이션이 정상 적용됐다.

최초 운영 확인에서 인증 제한용 Redis 요청이 503을 반환했다. Redis 네트워크 접근과 API/Redis 비밀번호 일치, API 컨테이너에서 AUTH/PING 성공을 확인했다. 운영 Redis 연결 제한을 5초, 명령 제한을 2초로 조정한 compose.prod-runtime.yaml을 적용하고 재기동한 후 로그인·비밀번호 재설정 요청은 정상이다. 운영 API 재배포에는 다음 세 파일을 함께 적용한다:

```sh
sudo docker compose --project-name eolssu-prod --env-file .env.prod -f compose.prod-shared.yaml -f compose.places.yaml -f compose.prod-runtime.yaml up -d --no-deps api
```

공유 Micro VM의 각 API 기동에 약 2분이 걸렸으며 기동과 프록시 상태 갱신 사이 일시적 502/503이 발생했다. 최종 개발·운영 readiness 모두 200/UP. 개발 API 컨테이너와 Caddyfile은 유지했다.

운영 대표 주소에서 홈 200, 모임 조회 200(3개), 미로그인 /v1/me 401, 빈 로그인·비밀번호 재설정 입력 400, 비밀번호 재설정 화면 200을 확인했다. 운영 OpenAPI는 404로 유지된다. 실제 가입·메일 발송·비밀번호 변경·회원 탈퇴 및 모임 삭제는 수행하지 않았다. 카카오 지도 키는 직전 확인에서 운영 earthuu.vercel.app SDK 요청 200이며 개발 도메인 등록 문제는 운영 도메인에 해당하지 않는다.

배포 전 운영 DB pg_dump(custom format)는 DB VM `/home/ubuntu/eolssu-prod/deploy-backups/20261008/eolssu_prod-before.dump`에 보관하고 pg_restore --list로 읽기 가능함을 확인했다. API VM `/home/ubuntu/eolssu-prod/deploy-backups/20261008/`에는 .env.prod, Compose, 이전 이미지명, Caddy 체크섬, 개발 컨테이너 ID와 media-before.tar.gz를 보관했다. API 롤백은 백업한 환경 파일·Compose와 이전 이미지 eolssu-api:earthuu-20261007로 운영 API만 재생성하고, 웹 롤백은 이전 Vercel 배포 dpl_ABGmbb2UMVXEUhWHTwZGJVbVB7Un을 promote한다. V5는 추가형 스키마이며 DB 볼륨을 삭제하거나 자동 복구하지 않는다.

배포는 미커밋 로컬 소스를 포함한다. 이후 Git 기반 배포 전 변경사항을 해당 배포 브랜치에 반영해야 한다.

## 2026-10-09 배포 소스 Git 정합성 검증

현재 Vercel 운영 대상은 `dpl_HxRTwdxjKSWponpyCMgdoYSFCpiA`이며 배포 소스 파일 69개의 SHA-1이 웹 로컬 소스와 모두 일치한다. 웹의 CSRF 전송, 계정 관리, 주최 모임 삭제, SEO/서버 렌더링 및 EarthUU 디자인 변경을 기능별 커밋으로 분리한다. 개발·운영 배포 브랜치는 각각 develop·main이다.

API는 10월 8일 운영 기록과 동일한 로컬 보관 이미지 `sha256:754e757a57e8a2996b8ab2901096f992fdb66f970730c5b22359fbea60137a47`에서 JAR를 추출했다. 실제 배포된 `eolssu_session`·`eolssu_refresh` 쿠키 이름을 유지해 빌드한 소스의 클래스·리소스 83개가 이미지 내용과 바이트 단위로 모두 일치한다. 로컬의 미배포 `earthuu_*` 쿠키 변경은 별도 후속 PR로 분리하고 배포 브랜치에는 포함하지 않는다. 쿠키 이름 변경을 배포하려면 기존 로그인 유지 정책을 검토하고 API 배포와 함께 적용해야 한다.

Java 21 컨테이너의 Maven verify는 49건 중 47건 통과·2건 제외, 웹 lint/build와 격리 DB/미디어 복원·손상 dump 거부·실패 후 API 재시작 드릴은 통과했다. 운영·개발 readiness는 모두 UP이었다. 이 날짜의 SSH 접속은 시간 초과이므로 원격 실행 이미지·Compose를 다시 검사한 것으로 표현하지 않는다. 원격 이미지 비교 근거는 직전 배포 기록과 보관 이미지이며, 상세 해시 보고서는 로컬 `docs/deployment/*source-reconciliation-2026-10-09.json`에 보관하고 Git 추적에서 제외한다.
