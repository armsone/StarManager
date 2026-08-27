# 설정·외부 AI Android 동기화 보고서

- 그룹: `starmanager`
- 기준 멤버: iOS `/Users/armsone/git/StarManager`
- 대상 멤버: Android `/Users/armsone/git/StarManager-Android`
- 시작: 2026-08-27 15:30:49 KST
- 종료: 2026-08-27 15:57:06 KST
- 경과: 26분 17초
- 범위: 나의 취향 단순화, 설정 순서, 외부 AI 로그인, AI 선택 목록, 내부 브라우저, 간결한 요청문

## 실제 동기화 표

| 기능 | iOS 기준 | Android 구현 상태 | 기술·런타임 근거 | Matchup 근거 | 최종 판정 |
|---|---|---|---|---|---|
| 설정 섹션 순서 | `ProfileSettingsView` | 8개 섹션을 요청 순서로 재배치 | SM-F968N에서 전체 스크롤 확인 | Android 캡처 3장, iOS 대응 캡처 없음 | source-only |
| 나의 취향 단순화 | 말투·이모지·스타일·분위기·이야기 비중·글자 수 중심 | 주제·독자·톤 5종·작성 원칙 편집 UI 제거, 저장 모델은 보존 | 65개 단위 테스트·빌드·린트 통과, 실기기 렌더 확인 | Android 캡처 있음, iOS 대응 캡처 없음 | source-only |
| 외부 AI 로그인 관리 | Gemini·ChatGPT·Claude 내부 로그인 화면 | 동일 순서와 설명, 공유 CookieManager/WebStorage | ChatGPT 열기→공식 페이지 로드→닫기 동작 확인 | Android 로그인 캡처 있음, iOS 대응 캡처 없음 | source-only |
| AI 선택 목록 | Gemini·ChatGPT·Claude·Apple Intelligence | Gemini·ChatGPT·Claude·기기 AI | Android 실기기에서 순서 확인 | Apple Intelligence 부재에 따른 라벨 차이, 대응 캡처 없음 | intentional difference / source-only |
| 간결한 외부 AI 요청문 | `[내가 입력한 내용]`·`[원하는 결과]`·선택적 `[추가 요청]` | Kotlin `generationPrompt`로 동일 구조 구현 | 결정적 JVM 테스트 통과 | 비시각 데이터 흐름 | source-only |
| 내부 생성 브라우저 | 로그인 세션 재사용, 자동 입력·전송·안정 응답 가져오기 | 공식 HTTPS WebView, 호스트 허용 목록, 수동 대체 동작 | 소스·테스트·빌드·린트 통과 | 실시간 생성 E2E 미실행 | source-only |
| 오래된·부분 응답 방지 | 새 답변만 안정 후 가져오기 | 시작 답변 기준선, 전송 확인, 비생성 상태 동일 결과 3회 확인 | 안정성 리듀서·JSON 이중 인코딩 테스트 통과 | 실시간 DOM E2E 미실행 | source-only |
| 하단 관리 항목 | iOS 테마가 하단 | Android는 외부 AI 다음 `앱 업데이트`, 마지막 `테마 관리` | 실기기에서 순서 확인 | Android 캡처 있음 | intentional difference / source-only |

## 프로젝트별 검증

| 프로젝트 | 검증 | 결과 |
|---|---|---|
| Android | `./gradlew testDebugUnitTest assembleDebug` | 65개 테스트 및 디버그 APK 빌드 성공 |
| Android | `./gradlew lintDebug` | 성공 |
| Android | `git diff --check` | 통과 |
| Android | 패리티 원장 구조 | `Structure OK: 12 row(s), 0 complete, 12 open` |
| Android | 패리티 완료 게이트 | 실패(예상): 12개 행이 `implemented_source_only` |
| Android | 설치 | Samsung SM-F968N에 `adb install -r` 성공, 데이터 보존 |
| Android | 실행 | `com.armsone.starmanager/.BkIconAlias` 포그라운드 확인 |
| Android | 최종 APK SHA-256 | `b8f49825169491f1124bd7c2ffba212afaff7fec4a18c818eecd46b66f344d21` |
| iOS | 변경·빌드 | 이번 범위에서 기준 소스만 읽음; 기존 사용자 변경 보존 |

## Matchup 증거 판단

- Android 원본 PNG·UI XML과 해시는 `/Users/armsone/git/StarManager-Android/.parity/evidence/settings_ai_20260827/`에 보존했다.
- 설정 섹션의 구조·문구·순서는 Android 실기기에서 확인했다.
- 대응하는 동일 상태의 iOS 후변경 캡처가 없어 픽셀·타이포그래피·간격의 시각 동일성은 판정하지 않았다.
- WebView 내부 ChatGPT 페이지 로드는 PNG로 확인했지만 UIAutomator XML에는 웹 내부 요소가 노출되지 않았다.

## 오류와 해결

| 단계 | 관찰된 오류 | 원인 | 조치 | 재시도 결과 | 열림 여부 |
|---|---|---|---|---|---|
| 기준 검색 | Android 작업 디렉터리에서 상대 iOS 경로 검색 실패 | 저장소 기준 경로 불일치 | iOS 절대 경로로 재조회 | 기준 소스 확인 | 해결 |
| 첫 단위 테스트 | 56개 중 2개 실패 | iOS 문구와 기대값 차이, Android `Uri` JVM 스텁 | iOS 문구 구조로 수정, `java.net.URI` 사용 | 해당 테스트 통과 | 해결 |
| 안정성 테스트 | 65개 중 3개 실패 | Android `org.json` JVM 스텁 | 기존 Gson으로 JS 값 인코딩·이중 JSON 파싱 | 2개 해결 | 해결 |
| 중첩 따옴표 테스트 | 65개 중 1개 실패 | 수동으로 쓴 이중 JSON 픽스처가 잘못 이스케이프됨 | Gson으로 실제 콜백 형식 생성 | 65개 전부 통과 | 해결 |
| 시각 게이트 | 12개 행 열림 | 대응 iOS 캡처 및 일부 E2E 증거 없음 | Android 증거·제한을 원장에 기록 | 게이트는 정직하게 열림 유지 | 열림 |

## 미완료 항목

| 기능·플랫폼 | 완료된 부분 | 빠진 증거·조치 | 이유 | 다음 안전한 조치 |
|---|---|---|---|---|
| 시각 패리티 | Android 설정 전체와 로그인 화면 캡처 | 같은 상태의 iPhone 캡처 쌍 | 이번 실행에서 iPhone 캡처 자동화 미사용 | 동일 데이터·테마로 iPhone 캡처 후 원자 행 비교 |
| Gemini·Claude 로그인 | 목록·URL·WebView 소스 및 테스트 | 각 공식 페이지 열기와 닫기 | ChatGPT만 런타임 확인 | 자격증명 없이 두 제공사 표면 열기 확인 |
| 로그인 유지 | 공유 영구 쿠키 저장소 구현 | 실제 로그인 후 앱 재실행 세션 유지 | 자격증명을 입력하지 않음 | 사용자가 직접 로그인한 뒤 재실행 확인 |
| 외부 AI 생성 E2E | 입력·전송·새 답변 기준선·3회 안정성 로직 | 실제 제공사별 생성 및 가져오기 | 웹 DOM과 계정 상태가 필요 | 짧은 테스트 문구로 Gemini·ChatGPT·Claude 각각 실행 |

## 의도된 차이와 작업 상태

- Android에는 Apple Intelligence가 없으므로 오프라인 결정적 생성기를 `기기 AI`로 표시한다.
- Android 전용 `앱 업데이트`는 사용자의 지시에 따라 하단에서 `테마 관리` 바로 앞에 둔다.
- 외부 AI 웹 DOM은 제공사가 바꿀 수 있으므로 자동 전송 실패 시 직접 전송 안내와 `다시 넣기`·`문구 복사` 대체 동작을 유지한다.
- Gemini가 Android 구현을 담당했고 Darwin이 설치·실기기 조작·증거 수집을 담당했으며 TM Codex가 검증·통합했다.
- Gemini 5시간 잔여: `52.73% → 43.53%` (9.20%p 감소). 주간 잔여: `90.20% → 87.87%` (2.32%p 감소). 개별 호출별 귀속이 없어 공급자 전체 감소로 기록한다.
- Codex 주간 잔여: `71% → 70%` (1%p 감소). Darwin의 별도 사용량 수치는 제공되지 않았다.
- 커밋, 푸시, 릴리스는 수행하지 않았다. Android 실기기 교체 설치만 수행했다.
