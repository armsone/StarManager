# Android Instagram 공유 핸드오프 동기화 보고서

- 그룹: `starmanager`
- 기준 멤버: iOS `/Users/armsone/git/StarManager`
- 구현 멤버: Android `/Users/armsone/git/StarManager-Android`
- 범위: 캡션 선복사 → 미디어 준비 → 시스템 공유 선택창 → 사용자가 Instagram 선택
- 시작: 2026-08-27 15:04:57 KST
- 종료: 2026-08-27 15:22:13 KST
- 경과: 17분 16초
- 산출물: `/Users/armsone/git/StarManager-Android/app/build/outputs/apk/debug/app-debug.apk`

## 실제 동기화 표

| 기능 | iOS 기준 | Android 구현 상태 | 기술·런타임 근거 | Matchup 근거 | 최종 판정 |
|---|---|---|---|---|---|
| 캡션 클립보드 선복사 | 공유 화면을 열기 전에 완성 문구 복사 | `ClipboardManager`로 `post.composedText` 복사 | 소스 확인, 단위 테스트·빌드·린트 통과; 런타임 미확인 | 실행 화면 없음 | source-only |
| 단일 이미지·영상 | 단일 미디어를 시스템 공유로 전달 | `ACTION_SEND`, `EXTRA_STREAM`, `ClipData` | 빌드 통과; 런타임 미확인 | 실행 화면 없음 | source-only |
| 복수 미디어 | 선택 순서대로 여러 미디어 전달 | `ACTION_SEND_MULTIPLE`, URI 배열, 다중 `ClipData` | 빌드 통과; 런타임 미확인 | 실행 화면 없음 | source-only |
| MIME 라우팅 | 이미지·영상 종류에 맞춰 전달 | 이미지 `image/*`, 영상 `video/*`, 혼합 `*/*` | `MediaAttachmentPolicyTest` 및 전체 단위 테스트 통과 | 비시각 기능 | source-only |
| URI 읽기 권한 | 수신 앱이 임시 파일을 읽을 수 있음 | `FileProvider`와 `FLAG_GRANT_READ_URI_PERMISSION` | Manifest·소스·APK 빌드 확인 | 비시각 기능 | source-only |
| 시스템 선택창 | 사용자가 Instagram을 선택 | `Intent.createChooser`; Instagram 패키지·딥링크 강제 없음 | 소스·빌드 확인; 기기 미연결 | OS 강제 차이, 화면 증거 없음 | intentional difference / source-only |
| 공유 가드 | 미디어 없음·8개 초과·오래된 초안·작업 중 차단 | 동일 상태 가드 적용 | 소스·빌드·린트 통과; 런타임 미확인 | 실행 화면 없음 | source-only |

Android 구현 파일은 `ComposerModels.kt`, `ComposerViewModel.kt`, `ComposerScreen.kt`, `MediaAttachmentPolicyTest.kt`이다. 기존의 무관한 iOS 작업 트리 변경은 보존했다.

## 프로젝트별 검증

| 프로젝트 | 검증 | 결과 |
|---|---|---|
| Android | `git diff --check` | 통과 |
| Android | 패리티 원장 구조 검사 | `Structure OK: 5 row(s), 0 complete, 5 open` |
| Android | 패리티 완료 게이트 | 실패(예상): 5개 행 모두 `implemented_source_only` |
| Android | `./gradlew testDebugUnitTest assembleDebug` | `BUILD SUCCESSFUL` (20초) |
| Android | `./gradlew lintDebug` | `BUILD SUCCESSFUL` (38초) |
| Android | APK 메타데이터·서명 | 21 MB, `com.armsone.starmanager`, 2.0.1/340680, min 26, target 37, V2 디버그 서명 확인 |
| iOS | 소스 변경·빌드 | 이번 Android 동기화 범위에서 미수행; 기존 변경 보존 |

## 오류와 해결

| 단계 | 관찰된 오류 | 원인 | 조치 | 재시도 결과 | 열림 여부 |
|---|---|---|---|---|---|
| Android 빌드 | SDK 위치를 찾지 못함 | `local.properties` 부재 | Git 제외 대상 로컬 설정에 SDK 경로 추가 | 테스트·빌드 성공 | 해결 |
| 패리티 기록 | 최초 원장 스키마 검증 오류 25개 | 참조·시도 필드가 정규 형식과 불일치 | 정규 필드로 수정 | 구조 검사 통과 | 해결 |
| ADB 확인 | 셸에서 `adb` 명령을 찾지 못함 | `platform-tools`가 PATH에 없음 | SDK 절대 경로로 1회 확인 | 명령 실행 성공 | 해결 |
| 런타임 검증 | 연결 기기 없음 | ADB 대상 부재 | 자동 에뮬레이터 시작·무단 설치를 하지 않음 | 런타임 증거 없음 | 열림 |
| 기록 위임 | 두 저장소 동시 읽기 권한 거부 | 헤드리스 작업 경계 | 저장소별 기록 작업으로 분리 | 기록 완료 | 해결 |

## 미완료 항목

| 기능·플랫폼 | 완료된 부분 | 빠진 증거·조치 | 미완료 이유 | 다음 안전한 조치 |
|---|---|---|---|---|
| Android 공유 핸드오프 | 소스, 단위 테스트, 빌드, 린트, APK 검증 | 실제 공유 선택창에서 Instagram 선택 후 미디어·클립보드 확인 | 연결 기기와 설치 승인 없음 | 기기를 연결한 뒤 사용자 승인 하에 APK 설치 및 E2E 테스트 |
| Android 시각 패리티 | OS 선택창 사용이라는 플랫폼 차이 기록 | 런타임 스크린샷 | 실행 대상 없음 | 동일 테스트 데이터로 Android 화면과 선택창 캡처 |
| 패리티 원장 | 정규 구조 및 5개 안정 ID | 런타임 증거 | 시각·동작 증거가 없어 완료 처리 불가 | 증거 확보 후 각 행을 재검증하고 `--gate` 실행 |

## 의도된 차이와 작업 상태

- iOS는 `UIActivityViewController`, Android는 `Intent.createChooser`를 사용한다.
- Android Instagram은 미디어와 본문을 안정적으로 함께 받지 않을 수 있어 캡션을 먼저 복사한다.
- 특정 Instagram 패키지나 비공개 새 게시물 주소를 강제하지 않는다.
- 커밋, 푸시, 기기 설치, 릴리스는 수행하지 않았다.
- 사용량: Gemini 5시간 잔여 `64.70% → 54.58%` (10.12%p 감소), 주간 잔여 `92.64% → 89.72%` (2.93%p 감소). Gemini가 Android 구현·기록을 수행했고 TM Codex가 검증·통합했다. 개별 Gemini 호출별 잔여량 귀속은 제공되지 않아 공급자 전체 감소로 기록한다.
