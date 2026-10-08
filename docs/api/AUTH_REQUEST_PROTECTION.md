# 인증 요청 제한과 CSRF 방어

2026-10-03 소스 구현. 운영 배포·실제 프록시 IP 검증은 별도다.

## 요청 계약

모든 `/v1/**` 변경 요청은 `X-Eolssu-Request: 1`이 필요하다. JSON, 이미지 multipart,
본문 없는 참여·관심·로그아웃도 동일하다. GET/HEAD/OPTIONS는 제외한다.
웹은 `src/lib/api.ts`의 `apiFetch`로 헤더를 자동 설정한다.

브라우저 Origin은 WEB_ORIGIN과 정확히 일치해야 한다. WEB_ORIGIN은 쉼표로 구분한
명시적 출처 목록을 지원한다. 경로·끝 슬래시·와일드카드는 거부한다.
다른/null Origin, 브라우저 메타데이터나 Referer가 있으면서 Origin이 없는 요청은 403.
비브라우저 CLI는 Origin 없이 전용 헤더를 보낼 수 있다.
CORS는 같은 출처 목록과 Content-Type/X-Eolssu-Request 헤더만 허용한다.
전용 헤더는 비밀 토큰이 아니라 동일 출처 정책·제한된 CORS와 결합하는
[OWASP custom request header 방식](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#employing-custom-request-headers-for-ajaxapi)이다.

Swagger 변경 요청도 동일한 계약이다. API 출처의 Swagger를 사용하려면 개발
WEB_ORIGIN에 그 출처를 명시적으로 추가하고 전용 헤더를 제공한다. 운영 Swagger는 비활성이다.

## 기본 제한

| 대상 | IP | 이메일 | 창 |
|---|---:|---:|---|
| login | 30회 | 10회 | 15분 |
| register + resend 합산 | 20회 | 5회 | 1시간 |
| verify | 60회 | 10회 | 15분 |

인증메일은 추가로 이메일당 60초에 한 번만 통과한다. 동시 요청에도 Redis의 원자적
소비를 적용한다. 기존 DB의 코드 만료·5회 오입력 검사는 유지한다.
성공·실패 모두 카운트한다. 잘못된 JSON/필수 필드 누락도 IP 제한을 소비한다.
이메일은 trim/lowercase 후 키를 만들고 Redis 키에는 이메일/IP의 SHA-256만 저장한다.
창은 첫 통과 요청에서 시작한다. 차단 요청은 만료 시간을 연장하지 않는다.
초과는 429 + Retry-After(초), 제한 저장소 장애는 503이다. 조회·다른 기능까지 차단하지 않는다.

환경 변수 AUTH_LOGIN_IP_LIMIT/ACCOUNT_LIMIT, AUTH_MAIL_IP_LIMIT/ACCOUNT_LIMIT,
AUTH_VERIFY_IP_LIMIT/ACCOUNT_LIMIT로 횟수를 설정한다. 창은
`eolssu.security.rate-limit.{login,mail,verify}.window-seconds`로 조정한다. 0/음수는 시작 시 거부한다.

local/docker는 최대 10,000개 키의 프로세스 메모리 구현, dev/prod는 기존 Redis 연결을 사용한다.
환경별 Redis 분리를 유지한다. 현재 Redis는 비영속이므로 Redis 재시작 시 횟수도 초기화된다.

## IP 신뢰 경계와 배포

기본은 socket peer IP만 사용한다. 임의 전달 헤더로 IP를 바꿀 수 없다.
AUTH_TRUSTED_PROXIES에는 API의 직접 접속 프록시의 **정확한 IP**만 지정한다.
그 프록시가 추가한 X-Forwarded-For 마지막 주소만 사용한다. 첫 번째 주소,
X-Real-IP/X-Vercel-Forwarded-For를 임의로 신뢰하지 않는다.
server.forward-headers-strategy=none으로 원래 socket peer를 유지한다.

현재 Vercel → Caddy → API 경로의 마지막 주소는 Vercel 프록시일 수 있다.
설정이 비어 있으면 Caddy IP에 합산된다. **그대로 배포하면 여러 사용자가 하나의 IP 제한을 공유할 수 있다.**
운영의 개별 사용자 IP 제한은 Vercel의 검증된 IP 전달과 Caddy의 신뢰 체인을 구성하거나
Vercel 신뢰 경계에서 IP 제한을 추가한 후 완성된다. 첫 IP 헤더를 무조건 믿는 방식으로 해결하지 않는다.
이메일별 제한은 이 구성과 무관하게 적용된다.

배포 순서:

1. 웹 apiFetch 변경 먼저 배포(기존 API에서도 작동).
2. 개발 Redis, 실제 WEB_ORIGIN, 프록시 IP 전달 확인.
3. 개발 API 배포 후 로그인·메일·프로필·업로드·참여·로그아웃 검증.
4. 운영 IP 신뢰 경계와 임계값을 확정한 후 운영 API 배포.

## 검증

- RequestProtectionTests: 변경 요청 헤더/출처, Origin 누락, 조회 유지, IP 위조 방어, 잘못된 인증 요청 카운트.
- AuthRateLimiterTests: 이메일 정규화, IP/계정 분리, 메일 cooldown, Retry-After, 503, 키 비식별화, 창 만료.
- AuthProtectionHttpTests: 실제 MVC와 로그인 쿠키, 로그인 제한, 가입/재발송 합산 IP 차단과 메일 미호출, CORS preflight.
- RedisAuthRateLimitTests: 두 인스턴스의 50개 동시 요청에서 정확히 10개 통과, TTL 후 재통과.

```sh
AUTH_TEST_REDIS_PORT=16389 ./mvnw -Dtest=RedisAuthRateLimitTests test
./mvnw test
```

전용 테스트 Redis만 사용한다. 운영 Redis를 테스트 대상으로 지정하지 않는다.
