# 구현 상태 — bigwash-hq 정본

정본: [`HQ-BUILDER-SPEC.md`](HQ-BUILDER-SPEC.md)  
검증: `npm run test:hq19` + `npm run test:hq20`

## 수락 테스트

| 범위 | 결과 |
|------|------|
| §19 / test:hq19 (1–10) | **PASS 10/10** |
| §20 / test:hq20 (11–20) | **PASS 10/10** |

## §1 차단 정리

- README 본사 HQ 전용, 진입 `/hq/login.html`
- `register.html` / `customer.html` → `legacy/public/`, HQ 라우트 **404**
- `COMPLETION_REPORT` / `PHASE2_ROADMAP` LEGACY 표시
- `npm start` = `hq-server.fl` only
- `npm test` = hq19+hq20 (레거시 44테스트 아님)
- 로그인 화면 실비밀번호 문구 제거

## 신규 구현

- 구매확정 `hq_customer_purchases` + 무상 힌트(확정일+365)
- N배정 + 용병 `hq_ticket_assignees` / `hq_contractors`
- 장바구니 `hq_cart_lines` + 권역 출장비 동기화
- 명세 다운로드 `pdf_base64` + `image_svg` (동일 본문+계좌줄)
- 고객 `region_id` (`hq_customer_extra`)

## 진입

`/hq/login.html` · 시드 계정은 env/`ADMIN_PASSWORD` (문서에 비밀번호 없음)
