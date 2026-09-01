# JOB.md — OpenCode/Claude Code 자동화 워크플로우

> GitHub 이슈 코멘트 `/oc` 또는 `/cc` → AI 분석 → 파일 수정 → PR 생성

---

## 📌 현재 상황

| 항목 | 값 |
|------|-----|
| 레포지토리 | `jmpark333/2027-essay-admission` |
| 워크플로우 파일 | `.github/workflows/opencode.yml` |
| AI 모델 | `poolside/laguna-s-2.1:free` (Nous Research API) |
| API 엔드포인트 | `https://inference-api.nousresearch.com/v1/chat/completions` |
| API 키 | `secrets.NOUS_API_KEY` |
| 모델 최대 출력 | 128K (131,072 토큰) |

---

## 🔧 완료된 작업

### 1. 워크플로우 구조 (양호)
- **트리거**: `issue_comment` 생성 시 `/oc`, `/opencode`, `/cc` 명령어 감지
- **Job 구성**: `oc` (OpenCode) + `cc` (Claude Code) 두 개 Job
- **Step 순서**:
  1. `actions/checkout@v4` — 레포 체크아웃
  2. `actions/github-script@v7` — 👀 eyes 리액션
  3. `actions/github-script@v7` — Nous API 호출 (파일 목록 + index.html 컨텍스트 포함)
  4. `bash` + `node` — AI 응답 기반 파일 편집 (search/replace)
  5. `bash` — 브랜치 생성, 커밋, 푸시
  6. `actions/github-script@v7` — PR 생성 + 코멘트 알림

### 2. 시스템 프롬프트 (양호)
- 레포 설명: 2027학년도 논술전형 달력
- 데이터 구조: `events.deadlines[]`, `events.exams[]`, `events.results[]`
- 파일 목록 자동 주입 (GitHub API `getContent`)
- index.html 내용 8000자 주입
- 응답 형식: JSON `{explanation, branch, edits[{file, old, new}]}`
- 대학명 규칙: 짧은 형태 + 따옴표 (`'한양대'` NOT `'한양대학교'`)

### 3. API 호출 설정 (수정 완료, 미검증)
```javascript
{
  model: "poolside/laguna-s-2.1:free",
  max_tokens: 16384,        // 기존 2048 → 16384로 증가
  temperature: 0.3
  // reasoning 파라미터 불필요 (laguna는 reasoning mandatory 아님)
}
```

---

## ✅ 수정 완료 (검증 대기 중)

### 문제: 빈 응답 (Empty Response)
**증상:**
```
Nous API status: 200
{
  "choices": [{
    "finish_reason": "length",
    "message": {
      "content": null,
      "reasoning_content": "..."  // 모든 토큰이 reasoning에 소모
    }
  }]
}
```

**원인:**
- `meituan/longcat-2.0:free` 모델이 `reasoning_effort: "high"` 설정 시 내부 reasoning에 모든 토큰 소모
- `content`가 null로 반환되어 JSON 파싱 실패 (`Unexpected end of JSON input`)

**수정 내용:**
- 모델 변경: `meituan/longcat-2.0:free` → `poolside/laguna-s-2.1:free`
  - `stepfun/step-3.7-flash:free` 시도 → reasoning mandatory라 "missing tags" 400 에러 발생
  - `poolside/laguna-s-2.1:free`: 코딩 에이전트 특화, reasoning mandatory 아님 → 최종 채택
- `reasoning_effort: "high"` 제거 (longcat에서 content null 문제)
- `content`가 비어 있을 때 `reasoning_content`에서 JSON 추출하는 fallback 추가
- cc job도 oc job과 동일한 견고한 JSON 파싱 로직(코드블록 + JSON 추출)으로 통일
- Node 20 deprecation 경고 해결 (`ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION: true`)

**검증 방법:**
1. 이슈에 `/oc 테스트` 코멘트 작성
2. Actions 로그에서:
   - `Nous API status: 200` 확인
   - `finish_reason: "stop"` 확인 (기존: `"length"`)
   - `content`에 JSON 응답 있는지 확인
   - 파일 편집 → 브랜치 생성 → PR 생성까지 정상 동작 확인

---

## 📋 향후 확인 체크리스트

- [ ] `/oc` 명령어 정상 동작 (파일 수정 + PR 생성)
- [ ] `/cc` 명령어 정상 동작 (동일 확인)
- [ ] AI가 정확한 파일 내용 인식 (대학명 짧은 형태, 날짜 형식)
- [ ] JSON 파싱 성공 (markdown code block 처리 포함)
- [ ] 파일 편집 시 `old` 텍스트 매칭 성공
- [ ] PR 본문에 변경 요약 포함
- [ ] 코멘트에 PR 링크 알림

---

## 🔗 관련 링크

- Actions 로그: https://github.com/jmpark333/2027-essay-admission/actions
- 워크플로우 파일: `.github/workflows/opencode.yml`
- 대상 파일: `index.html` (696줄, 이벤트 데이터 포함)

---

*최종 수정: 2026-09-01 01:00 KST*
