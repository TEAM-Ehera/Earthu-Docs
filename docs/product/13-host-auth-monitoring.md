---
title: 주최자 관리·이미지 한도·인증·서버 모니터링
tags: [얼쑤, 개발, 운영, 모니터링]
status: 운영·개발 적용 완료 · 모니터링 수집 확인
updated: 2026-10-03
---

# 주최자 관리·이미지 한도·인증·서버 모니터링

## 주최자 기능

마이 이벤트의 주최한 탭과 상세의 관리 링크에서 `/events/{id}/manage`로 이동한다.

| API | 역할 | 권한·제약 |
| --- | --- | --- |
| GET /v1/events/{id}/host | 수정용 기존 정보 | 해당 호스트만 |
| PATCH /v1/events/{id} | 제목·설명·일정·장소·정원·썸네일 수정 | 시작 전 공개 모임, 현재 신청자보다 작은 정원 불가 |
| GET /v1/events/{id}/applicants | 신청자 조회 | 해당 호스트만, active 신청자 |
| DELETE /v1/events/{id} | 모임 취소, 모집 목록에서 내림 | 해당 호스트만, 시작 전, reason 필수 |

신청자 응답은 이름·대학·국적·사용 언어·모집 그룹·신청 시각이다. 이메일·비밀번호·인증 코드를 노출하지 않는다. 신청자를 일괄 조회해 회원별 추가 쿼리를 피한다.

삭제는 물리 삭제가 아니다. cancelled 상태와 dispositionReason을 저장해 기존 신청 이력과 취소 사유를 남긴다. 공개 목록에서 제외되고 기존 참여자의 내 모임에서 상세를 확인할 수 있다. 모임 수정/취소는 참여 신청과 같은 이벤트 행 잠금으로 정원 변경 충돌을 막는다. V3__event_cancellation_reason.sql이 필드를 추가한다. 이메일/푸시 변경 안내·취소 복구 UI는 별도 미구현이다.

## 이미지 처리와 한계

현재 별도 이미지 서버/R2는 없고 API VM의 환경별 미디어 볼륨을 사용한다.

| 항목 | 변경 전 | 현재 구현 |
| --- | --- | --- |
| 원본 선택·API 파일 한도 | 약 5MB | 20MiB |
| Multipart 요청 한도 | 5MB | 21MiB |
| 원본 픽셀 한도 | 1,200만, 전체 디코딩 후 검사 | 4,800만, 서버 디코딩 전 검사 |
| 저장 이미지 | 원본 크기 JPEG | 최대 긴 변 1600px, JPEG 품질 82% |
| 브라우저 전송 | 원본 그대로 | 자동 압축, 전송 파일 3MiB 이하 |
| 서버 동시 변환 | 별도 제한 없음 | API별 1개, 동시 요청은 429 후 재시도 |
| 환경별 미디어 한도 | 별도 제한 없음 | 10GiB, 도달 시 507 |
| 디스크 보호 | 없음 | 여유 2GiB 미만이면 업로드 중단 |
| 조회 | byte 배열 전체 메모리 로딩 | 파일 Resource 응답, UUID ETag·1년 캐시 |

JPEG/PNG만 지원한다. 프론트는 createImageBitmap·Canvas로 변환하고 서버는 ImageIO 헤더 확인·subsampling·JPEG 재인코딩을 수행한다. 브라우저 원본 픽셀 검사는 이미지 해석 후이며 서버처럼 디코딩 전 검사를 보장하지 않는다. 업로드를 무제한 허용하지 않으면서 휴대폰 고화소 사진을 수용한다.

20MiB 원본 허용이 프록시의 모든 요청 제한을 없앤다는 뜻은 아니다. Vercel Function의 요청/응답 제한은 4.5MB다. 현재는 외부 rewrite를 쓰며 Function 경유 여부에 따라 동작이 다를 수 있으므로 브라우저 전송을 3MiB 이하로 유지한다. [Vercel 제한 문서](https://vercel.com/docs/errors/function_payload_too_large)

사전 측정 API 디스크는 약 45GiB 중 39GiB 여유였다. 두 환경의 10GiB는 동일 디스크를 공유하는 앱 설정이며 Oracle 추가 저장소를 확보한 값이 아니다. 평균 300KiB 저장 이미지라면 환경당 약 3.5만 장, 1MiB라면 약 1만 장이라는 단순 계산이다. 실제 압축 크기·기존 이미지·미사용 업로드·Docker 이미지·로그에 따라 달라진다. 디스크 용량으로 동시 사용자 수를 추정할 수는 없다. 미사용 이미지 자동 정리와 R2 이관은 다음 작업이다.

## JWT 로그인 유지

- Nimbus 기반 HS256 서명 JWT, 접근 토큰 15분.
- `earthuu_session`은 JWT, `earthuu_refresh`는 무작위 32바이트 토큰. 둘 다 HttpOnly·SameSite=Lax, 서버 dev/prod에서는 Secure.
- DB member_sessions에는 refresh의 SHA-256 해시·회원·7일 절대 만료를 보존한다. 접근 JWT에도 session id를 넣고 DB 세션을 확인하므로 로그아웃을 즉시 반영한다.
- 접근 JWT가 만료되면 요청의 refresh 쿠키를 검증하고 새 접근 JWT를 발급한다. refresh 자체의 만료를 매번 연장하거나 회전하는 구현은 아니다.
- 환경마다 별도 256비트 이상 키와 issuer를 사용한다. 키는 Git 제외 환경 파일에 보존한다. 키가 없으면 dev/prod 서버는 시작하지 않는다.
- 배포 전에 발급된 불투명 세션 쿠키는 기존 만료일까지 호환한다. 새 로그인/인증부터 JWT를 발급한다.
- localStorage에 토큰을 저장하지 않는다. JWT가 로그인 지속 시간을 무제한으로 만드는 것은 아니다. 전체 기기 세션 회수와 비밀번호 재설정·탈퇴는 2026-10-03 소스 구현·로컬 검증을 완료했다. 변경 요청 CSRF 방어와 인증 요청 제한도 소스에 연결되어 있다. 계정 관리의 운영 배포·실제 메일 수신 검증과 refresh 회전은 남은 작업이다.

## API Gateway와 서버 찾기

현재 무료 Micro VM의 자원을 고려해 Caddy를 HTTP Gateway 진입점으로 사용한다. 호스트별 dev/prod 라우팅, Docker DNS의 api/prod-api 이름 해석, HTTPS 종료, 주기적 health 확인과 제한된 GET 재시도를 구성했다. 클라이언트는 API 컨테이너 IP를 알 필요가 없다. 같은 환경 서버가 여러 대가 되면 upstream을 추가하는 방식으로 확장할 수 있다.

현재 Spring Cloud Gateway/Eureka나 업무별 마이크로서비스를 새로 띄운 것은 아니다. JWT 검증·호스트 권한은 Spring Boot에서 처리하며 Gateway에서 JWT를 검증하는 기능은 없다. Docker DNS는 단일 Docker 호스트에서 서비스 이름을 찾는 방식이며 VM 여러 대의 자동 등록/발견은 추가 구성해야 한다.

## Grafana 모니터링

DB VM에 Grafana 12.3.0·Prometheus 3.5.0·DB node-exporter를 실행하고, API VM에 node-exporter를 실행한다. API JVM/HTTP/DB 풀 지표는 Micrometer Prometheus로 수집한다. 지표는 30초마다 수집하며 TSDB 블록 보관은 7일·512MB다. WAL 등 추가 디스크 사용이 있어 전체 저장량의 엄격한 512MB 상한은 아니다. 수집 실패·메모리 부족·디스크 부족·API 5xx 경보 규칙을 포함한다. 외부 메일/메신저 알림 연동은 하지 않았다.

Grafana는 DB VM의 사설 IP [접속 IP 비공개]:3001에 바인딩하고 API VM의 Caddy HTTPS 주소로 접속한다. OCI와 DB 호스트의 DOCKER-USER 규칙은 API 사설 IP [접속 IP 비공개]/32만 허용한다. Prometheus는 DB VM localhost에만 바인딩한다. DB에 공인 IP나 공개 3001 포트를 추가하지 않는다. API 측 지표 경로는 HTTPS Basic 인증 뒤에 있으며 비밀값을 공개 설정 파일에 넣지 않는다.

1. 운영 Grafana (주소는 운영 담당자가 별도 전달) 접속, 아이디 [개인 계정 발급 요청].
2. 비밀번호는 Git 제외 `.env.monitoring`의 GRAFANA_ADMIN_PASSWORD를 로컬에서 확인한다. 대화창·문서에는 기록하지 않는다.
3. 자동 등록된 **얼쑤 서버 모니터링** 대시보드에서 CPU·메모리·swap·디스크·API 평균 응답/요청/5xx·JVM heap·DB 연결 대기·수집 상태를 확인한다.
4. 로컬 SSH 터널은 필요 없다. 기존 open-monitoring.sh는 이전 localhost 구성용이며 현재 Grafana 바인딩에서는 그대로 사용할 수 없다.

HTTPS 접속과 기존 계정 로그인 200, 미로그인 대시보드 401, 인증된 대시보드 10개 패널, Secure 세션 쿠키를 확인했다. 자세한 접속·방화벽 설정은 [14-grafana-https-access](14-grafana-https-access.md) 참고.

자원 제한: Grafana 256MiB, Prometheus 192MiB, 각 node-exporter 48MiB. 이는 실제 사용량이 아니라 Docker 제한이다. 대시보드 JSON·datasource·Compose는 API 저장소 monitoring/에 보관한다. 별도 Loki 로그 수집은 구성하지 않았다.

## 지연 조사 기록

2026-10-02 사전 측정, 5회 요청의 소규모 표본이다. 동시 사용자 부하 시험이 아니다.

- API VM: RAM 954MiB, available 약 178MiB, swap 사용 약 536MiB. CPU idle 약 98~100%, OOM·재시작 없음.
- API 서버에서 localhost HTTPS 요청: 1.916 / 0.226 / 0.291 / 0.298 / 0.520초.
- 사용자 컴퓨터에서 API 직접 요청: 중앙값 0.382초.
- 운영 웹을 경유한 요청: 중앙값 0.610초.

확인된 한계는 작은 메모리와 swap, Micro CPU/대역폭 제약이다. Oracle 공식 E2.1.Micro 사양은 1/8 OCPU·1GB RAM·인터넷 최대 50Mbps다. [Oracle 공식 사양](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)

이 표본만으로 DB·SMTP·Vercel 중 하나를 원인으로 단정하지 않는다. 새 지표의 시간대별 API 응답·DB 풀·호스트 부하를 비교한다. 원본 이미지 전송/변환량과 읽기 메모리를 줄였고, JVM 초기/최대 heap은 개발 32/128MiB, 운영 64/192MiB로 낮췄다. 재배포 후 같은 웹 경유 5회 측정은 0.484 / 0.150 / 0.112 / 0.105 / 0.104초, 중앙값 0.112초였다. 초기 상태·캐시·측정 시점이 다르므로 통제된 성능 개선 시험은 아니다. 재시작 후 API VM은 available 177MiB, swap 328MiB, 디스크 여유 37GiB였고 OOM/재시작은 없었다.

관련: [08-work-status](08-work-status.md) · [09-backend-architecture](09-backend-architecture.md) · [12-production-deployment](12-production-deployment.md).

## 원격 적용·검증 결과 (2026-10-02)

- API 실행 이미지: f8b889b21008dae755115f5a62dcec579846f6a9. 개발·운영 모두 적용, V1/V2/V3 성공. SMTP health 분리·readiness DB 포함 설정은 Compose 환경 변수로 같은 이미지에 적용했다.
- 웹: 주최자 관리·이미지 압축은 4da9419, 취소 모임 표시 보완은 7abe84c 코드로 main 운영과 develop Preview에 반영했다.
- 운영·개발 readiness UP, 운영 웹 경유 목록 200, 미로그인 호스트 정보/신청자 조회 401.
- Grafana health/database 정상, 자동 등록 대시보드 10개 패널 확인. api-dev/api-prod/node-api/node-db 네 수집 대상 모두 UP, 실제 시계열 값 확인.
- Prometheus는 extra_hosts로 API HTTPS 호스트를 내부 10.0.0.46에 연결한다. DB VM에 인터넷/NAT를 새로 공개하지 않고 TLS 호스트 검증과 Basic 인증을 유지한다.
- Java 테스트 11개 통과. JWT 서명·키/환경 격리·refresh 갱신·로그아웃, 비호스트 권한·정원 축소·취소 이력, 5MB보다 큰 이미지 변환·위장 이미지 거절을 포함한다. 웹 lint·타입 검사·프로덕션 빌드 통과.
- Gateway health 검사 추가 과정에서 전체 health가 SMTP STARTTLS 확인을 반복하며 개발 API에서 15~22초 지연·Broken pipe가 발생했다. 이 배포 과정의 문제를 확인하고 readiness(API·DB)로 전환, mail health 비활성화로 해결했다. 이를 변경 전 사용자 지연의 유일 원인이라고 단정하지 않는다.
- 실제 사용자의 로그인 비밀번호·학교 코드로 테스트하거나 기존 운영 모임을 수정·삭제하지 않았다. 주최자 화면의 실제 계정 흐름과 학교 메일 수신은 사용자 검증 대상이다.

## 계정 관리 추가 (2026-10-03)

학교 메일 기반 비밀번호 재설정·전체 기기 로그아웃·탈퇴와 데이터 처리 안내를 구현했다. 재설정 및 탈퇴 시 전체 세션을 폐기한다. `AccountManagementTests` 8개와 웹 lint·타입 검사·빌드가 통과했다. 이는 H2·모의 SMTP 검증이며 운영 배포·V5 마이그레이션·실제 학교 메일 수신은 검증 대기다. 처리 범위와 API는 [계정 관리·탈퇴 데이터 처리](16-account-management.md)를 따른다.
