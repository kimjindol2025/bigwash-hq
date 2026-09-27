# bigwash-hq 구현 상태

정본: [`HQ-BUILDER-SPEC.md`](HQ-BUILDER-SPEC.md)  
저장소: https://github.com/kimjindol2025/bigwash-hq · `main`

## 진입

- URL: `/hq/login.html`
- `npm start` = AFJ HQ only (`src/hq-server.fl`)
- 레거시 고객입구(`/register.html`, `/login.html` 등) = **404**

## 잠긴 UI 슬라이스

| 화면 | 상태 |
|------|------|
| 전화 데스크 | 검색(번호 부분일치·상호) → 카드 → 장비 → 출장/상담. 최근출장은 **요약 미리보기** |
| 고객 카드 | 필수+권고 필드, 장비, 구매확정, 무상힌트 |
| 티켓 서랍 | 고객/요청 · 배정(N+용병) · 장바구니=견적 · 일지/사진 썸네일 |
| 스케줄 | 직원/용병 선선택 후 부여 |
| 사내몰 | 상품 마스터 (`fulfill_type`) — 장바구니는 티켓 서랍 |

## 성능

- 대시보드: DB 왕복 축소 + **10초 서버 캐시** + 브라우저 즉시 표시
- 티켓: `/hq/tickets/:id/bundle` 1회 로딩
- 참조데이터(직원·권역·상품) 60초 클라이언트 캐시

## 테스트

```bash
npm run test:hq19   # 1–10
npm run test:hq20   # 11–20
```

## 아직 얇은 점

- UI E2E 스위트 없음 (손테스트 기준)
- 명세 PNG는 세로 템플릿 + 동일 content (고품질 텍스트 래스터 합성은 후속)
- 역할별 화면 숨김 UX는 부분적
- 보고·정산 화면은 기능 API 위주, 손질 여지 있음
