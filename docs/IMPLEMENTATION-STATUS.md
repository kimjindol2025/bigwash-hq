# 구현 상태 — 검수 잔여 지시 반영

정본: [`HQ-BUILDER-SPEC.md`](HQ-BUILDER-SPEC.md)

## 수락

| 스위트 | 결과 |
|--------|------|
| test:hq19 (1–10) | 유지 |
| test:hq20 (11–20) | **PASS 10/10** (권역 자동복사·실 PDF/PNG 매직 포함) |

## 검수 “남은 빌더 지시” 반영

| # | 지시 | 상태 |
|---|------|------|
| 1 | `login.html`/`dashboard.html` → legacy + HQ 404 | **됨** |
| 2 | `server.js`/`v9` → legacy | **됨** |
| 3 | 명세 PDF 실바이트 + PNG | **됨** (`%PDF` / `\x89PNG`). SVG는 추가 대체. PNG는 세로 템플릿+동일 content(고품질 텍스트 래스터 합성은 후속) |
| 4 | 티켓 생성 시 고객 region 자동복사 테스트 | **됨** (region 생략 요청) |
| 5 | hq20 README 레포 상대경로 | **됨** |
| 6 | `.env.example` 실비번 문구 정리 | **됨** |
| + | `HQ-CRM-AS-REVIEW.md` 비정본 표시 | **됨** |

## 아직 남는 한계 (정직)

- 테스트는 여전히 **API 중심**. `/hq/app.html` 클릭 스위트는 없음.
- PNG는 **공유 가능한 실파일 바이트**이나, PDF 본문 전체를 픽셀로 구운 고품질 이미지 합성은 아님.
- SPEC §4–18 서술 축약은 대화/이 상태문서로 보완 중.

## 진입

`/hq/login.html` only. 옛 `/login.html` 등은 404.
