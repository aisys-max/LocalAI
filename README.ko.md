# LocalAI

내 손으로 직접 돌리는 LLM과 대화하는 네이티브 SwiftUI 아이폰 채팅 클라이언트입니다 —
Mac, PC, Linux 위에서 [Ollama](https://ollama.com) 또는 [LM Studio](https://lmstudio.ai)를 통해 실행됩니다.
입력한 내용은 어디로도 업로드되지 않고, 내 기기들 밖으로 나가지 않습니다.

*[English version is here](README.md)*

## 1. LocalAI의 탄생과 용도

LocalAI는 Claude Design 프로토타입 "Local AI Chat App Design"을 SwiftUI로 1:1
포팅하면서 시작됐습니다 — 화면 구성, 문구, 인터랙션 로직이 모두 그 디자인에서
그대로 옮겨온 것입니다. 이후 실제 네트워크 계층이 붙어서, 채팅과 모델 목록
요청이 설정된 Backend(Ollama 또는 LM Studio)로 HTTP를 통해 실제로 나갑니다 —
두 Backend가 공유하는 OpenAI 호환 API(`/v1/chat/completions`, `/v1/models`)를
사용합니다.

이 앱의 목적은 프라이버시와 통제권입니다: 모든 대화는 클라우드 API가 아니라
사용자가 소유한 하드웨어에서 돌아가는 모델이 생성합니다. LocalAI 자체는
메시지, 첨부파일, 모델 응답을 그 어디에도 업로드하지 않습니다 — Settings에서
설정한 Backend 주소하고만 통신합니다. 코드베이스에는 `SimulatedChatBackendClient`
(고정 응답)도 여전히 남아있지만, 이건 SwiftUI 프리뷰와 네트워크 없이 도는
테스트용일 뿐, 앱의 기본 동작은 아닙니다.

## 2. 요구사항

- Xcode 15 이상 (iOS 17 SDK)
- iPhone 또는 iOS 17 이상 시뮬레이터
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — Xcode 프로젝트는 직접 관리하지 않고 생성됩니다
- 모델이 최소 1개 이상 설치된, 직접 통제 가능한 Mac/PC/Linux 위의 Ollama 또는 LM Studio 인스턴스

## 3. 빌드 & 실행

```bash
xcodegen generate
```

```bash
xcodebuild -project LocalAI.xcodeproj -scheme LocalAI \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

`build` 대신 `test`를 쓰면 `LocalAITests` 스위트가 실행됩니다. 소스 파일을
추가/삭제하거나 `project.yml`을 수정할 때마다 `xcodegen generate`를 다시
실행하세요 — `LocalAI.xcodeproj` 자체는 gitignore 대상이고, 필요할 때마다
`project.yml`로부터 새로 생성됩니다.

## 4. Ollama/LM Studio를 Local Address로 연결하는 방법

앱에서: **Settings → Model** 섹션에서 Backend(Ollama 또는 LM Studio)를 고른 뒤,
바로 아래 **Server Address**를 설정합니다.

두 Backend 모두 기본값은 `127.0.0.1`(루프백)만 듣도록 되어 있어서, 아무 설정도
안 하면 **같은 기기 안에서만** 접근 가능합니다 — 같은 Wi-Fi에 있는 폰에서도
안 닿습니다:

- **Ollama**: 실행 전에 `OLLAMA_HOST` 환경변수를 `0.0.0.0:11434`(또는 그
  기기의 LAN IP)로 설정하세요 — 루프백이 아니라 네트워크 인터페이스에서
  듣도록 바뀝니다.
- **LM Studio**: **Developer 탭 → Server Settings**에서 **"Serve on Local
  Network"**를 켜세요. `127.0.0.1`에서 `0.0.0.0`으로 바뀝니다.

이렇게 설정한 뒤, 호스트 기기의 LAN IP(예: `192.168.1.42`)를 찾아서 LocalAI의
Server Address에 입력하세요 — Ollama는 `http://192.168.1.42:11434`, LM Studio는
`http://192.168.1.42:1234` 같은 형태입니다. 이 방식은 폰이 호스트 기기와 **같은
Wi-Fi**에 있어야 동작합니다.

## 5. Ollama/LM Studio를 Remote(Tailscale)로 연결하는 방법

LocalAI는 자체 VPN이나 터널링 로직을 내장하고 있지 않습니다 — Server Address는
그냥 평범한 URL이라, 원격 접속은 결국 "폰과 호스트 기기를 먼저 같은 사설망에
두고, 그 망의 주소를 입력하는 것"의 문제입니다. [Tailscale](https://tailscale.com)
(개인 사용 무료)을 쓰는 게 추천 방법입니다:

1. **호스트 기기에서**: Tailscale을 설치하고 로그인합니다. 4번 항목대로 Backend가
   루프백 너머에서도 접근 가능하도록 설정돼 있는지 확인하세요 (Ollama는
   `OLLAMA_HOST=0.0.0.0:...`, LM Studio는 "Serve on Local Network") — Tailscale
   트래픽도 서버가 `127.0.0.1`이 아닌 곳에서 듣고 있어야 닿습니다.
2. **iPhone에서**: App Store에서 공식 Tailscale 앱을 설치하고, **같은 계정**으로
   로그인합니다.
3. 호스트 기기의 Tailscale 주소를 확인합니다 (`tailscale ip -4`, 또는 Tailscale
   관리 콘솔/메뉴바 앱) — `100.x.x.x` 형태의 IP이거나, MagicDNS 이름
   (예: `my-mac.tailxxxx.ts.net`)입니다.
4. LocalAI의 Settings에서, LAN 주소 대신 그 주소를 Server Address에 입력합니다.
   예: `http://100.64.1.42:11434`.

이 방식은 폰이 인터넷에 연결돼 있기만 하면 어디서든 동작합니다 — 포트포워딩도,
공유기 설정 변경도 필요 없습니다. 내부적으로는 LM Studio 자체의 "LM Link"
기능이 쓰는 것과 같은 메커니즘입니다(그것도 Tailscale 기반입니다) — 다만 LM
Studio는 자사 동반 앱("Locally")에 한해 이 설정을 자동화해주고, LocalAI는 그
자동화에 접근할 수 없어서 이 수동 Tailscale 설정이 이 앱에서 지원하는 경로입니다.

## 6. 개인정보/보안

- 대화, 첨부파일, 모델 응답은 기기 안 또는 사용자 소유의 Backend 기기에서
  처리되며, LocalAI 개발자가 관리하는 서버로 업로드되지 않습니다.
- Settings의 보관 기간(Retention Period)이 대화가 자동 만료되기까지의 기간을
  결정하며, 언제든 수동으로 삭제할 수도 있습니다.
- 5번 항목처럼 원격 접속을 설정했다면, 호스트 기기의 OS, Ollama/LM Studio,
  Tailscale 클라이언트를 최신 상태로 유지하세요.

## 7. 알려진 제한사항

- LM Studio의 계정 로그인 기반 자동 연결("LM Link")을 위한 공개 모바일
  SDK/API는 (이 글을 쓰는 시점 기준) 존재하지 않습니다 — 그 편의 기능은 LM
  Studio 자사 앱 "Locally" 전용입니다. LocalAI는 대신 그 밑바탕이 되는
  Tailscale 메커니즘을 통해 원격 접속을 지원하며(5번 항목), 설정은 조금 더
  수동적이지만 두 Backend 모두 동일한 방식으로 동작합니다.
- 앱은 `NSAppTransportSecurity`에서 더 좁은 `NSAllowsLocalNetworking` 대신
  `NSAllowsArbitraryLoads`를 켜고 있습니다. Tailscale이 `100.64.0.0/10`
  CGNAT 대역(RFC 6598)의 주소를 할당하는데, `NSAllowsLocalNetworking`의
  고정된 RFC1918 전용 예외가 이 대역을 커버하지 않고, iOS의 App Transport
  Security 자체에 특정 대역만 골라 예외 처리하는 기능이 없기 때문입니다.
  LocalAI는 사용자가 직접 설정한 단 하나의 Server Address(사용자 본인이
  운영하는 Ollama/LM Studio 인스턴스)에만 연결하고 임의의 제3자 콘텐츠를
  가져오지 않으므로, ATS가 그렇게 표현할 방법은 없지만 실질적으로는 이
  기능 하나에만 국한된 예외입니다. **App Store 심사 중 이 부분에 대해
  질문받으면**, 이 문단을 App Store Connect의 Review 노트에 그대로
  가져다 쓰시면 됩니다.
- iPhone 전용입니다 (`TARGETED_DEVICE_FAMILY: 1`) — 아직 iPad 전용 레이아웃은
  없습니다.
- Ollama와 LM Studio만 지원하며, 둘이 공유하는 OpenAI 호환 API만 사용합니다 —
  Ollama의 네이티브 전용 API 기능은 쓰지 않습니다
  ([ADR-0001](docs/adr/0001-openai-compatible-backend-client.md) 참고).

## 8. 기여하기

이슈와 스펙은 이 레포의 GitHub Issues에 있으며, 이슈별 브랜치(`issue-N-slug`)
컨벤션을 따릅니다. 컨벤션은 [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)를,
새로운 용어를 쓰기 전에는 이 프로젝트의 도메인 용어(Backend, Server Address,
Model, Chat 등)를 정리한 [`CONTEXT.md`](CONTEXT.md)를 먼저 참고하세요.
