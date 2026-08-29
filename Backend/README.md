# iManagerAI Backend

OpenAI API 키를 iPhone 앱에 넣지 않고 서버에서 보호하기 위한 최소 AI 게이트웨이입니다.

제공 경로:

- `GET /health`
- `POST /v1/captions`: 개인 설정을 반영한 인스타그램 문구 생성
- `POST /v1/images`: 완성 글을 근거로 이미지 생성

ChatGPT 사용에는 `OPENAI_API_KEY`, Gemini 사용에는 `GEMINI_API_KEY`를 서버 비밀값으로 설정합니다. 둘 중 사용할 제공자의 키만 있어도 동작하며, 앱에서 제공자를 바꾸려면 두 키를 모두 설정합니다. 선택적으로 `IMANAGERAI_APP_TOKEN`을 설정할 수 있으며, 운영 전에는 요청 제한과 Apple App Attest 검증을 추가해야 합니다. 과거 iManager·StarManager 클라이언트와의 전환 기간 동안에는 `IMANAGER_APP_TOKEN`, `STARMANAGER_APP_TOKEN`도 동일한 값으로 함께 설정해 두면, 앱이 보내는 `X-iManagerAI-Token`(우선), `X-iManager-Token`, `X-StarManager-Token`(예전) 헤더를 모두 받아 인증합니다.

기본 모델은 텍스트 `gpt-5.4`, 이미지 `gpt-image-2`입니다. 서버 환경 변수 `OPENAI_TEXT_MODEL`, `OPENAI_IMAGE_MODEL`, `OPENAI_IMAGE_QUALITY`로 변경할 수 있습니다.

Gemini 기본 모델은 텍스트 `gemini-3.7-flash`, 이미지 `gemini-3.1-flash-image`이며 `GEMINI_TEXT_MODEL`, `GEMINI_IMAGE_MODEL`로 변경할 수 있습니다. API 키는 iPhone 앱에 저장하지 않고 서버에서만 보관합니다.

배포 후 앱의 `내 설정 → 고급 설정 → AI 연결 및 원문 프롬프트`에서 실제 AI 사용을 켜고 HTTPS 서버 주소를 입력합니다. 만들기 화면에서 `ChatGPT / Gemini`를 게시물마다 바로 선택할 수 있습니다.

## Cloudflare Workers 연결

`wrangler.toml`에는 공개해도 되는 모델 설정만 들어 있습니다. API 키와 앱 토큰은 반드시 서버 비밀값으로 등록합니다.

```sh
cd Backend
wrangler secret put OPENAI_API_KEY
wrangler secret put GEMINI_API_KEY
wrangler secret put IMANAGERAI_APP_TOKEN
wrangler deploy
```

로컬 점검은 `.dev.vars.example`을 `.dev.vars`로 복사한 뒤 실제 값을 로컬 파일에만 넣고 `wrangler dev`로 실행합니다. 운영 앱에서는 서비스 주소와 인증정보를 제품 설정으로 내장하고, 일반 사용자에게 서버 주소·토큰·API 키를 입력하게 하지 않습니다. 제공자 키 값은 응답에 포함되지 않습니다.
