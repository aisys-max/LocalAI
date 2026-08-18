# LocalAI

A native SwiftUI iPhone chat client for LLMs you run yourself — on a Mac, PC,
or Linux box, via [Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai).
Nothing you type ever leaves your own devices.

*[한국어 버전은 여기](README.ko.md)*

## 1. What LocalAI is, and why it exists

LocalAI started as a 1:1 SwiftUI port of the "Local AI Chat App Design" Claude
Design prototype — the screens, copy, and interaction logic all come from
that source design. It has since grown a real network layer: chat and model
list requests go out over HTTP to whichever Backend (Ollama or LM Studio) you
point it at, using their shared OpenAI-compatible API surface
(`/v1/chat/completions`, `/v1/models`).

The point of the app is privacy and control: every conversation is generated
by a model running on hardware you own, not a cloud API. LocalAI itself never
uploads a message, an attachment, or a model reply anywhere — it only talks to
the Backend address you configure in Settings. A `SimulatedChatBackendClient`
(canned replies) is still kept around in the codebase, but only for SwiftUI
previews and network-free tests, not as the app's default.

## 2. Requirements

- Xcode 15 or later (iOS 17 SDK)
- An iPhone or iOS 17+ Simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the Xcode project is generated, not hand-maintained
- A running Ollama or LM Studio instance, on a Mac/PC/Linux machine you control, with at least one model downloaded

## 3. Build & run

```bash
xcodegen generate
```

```bash
xcodebuild -project LocalAI.xcodeproj -scheme LocalAI \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Swap `build` for `test` to run the `LocalAITests` suite instead. Re-run
`xcodegen generate` any time you add/remove a source file or edit
`project.yml` — `LocalAI.xcodeproj` itself is gitignored and rebuilt from
`project.yml` on demand.

## 4. Connecting to Ollama / LM Studio on your Local Network

In the app: **Settings → Model** section, pick your Backend (Ollama or LM
Studio), then set **Server Address** underneath it.

Both backends default to listening on `127.0.0.1` (loopback) only, so out of
the box they're only reachable from the same machine they're running on —
**not** from your phone, even on the same Wi-Fi:

- **Ollama**: set the `OLLAMA_HOST` environment variable to `0.0.0.0:11434`
  (or your machine's LAN IP) before starting it, so it listens on your
  network interface instead of just loopback.
- **LM Studio**: in the **Developer tab → Server Settings**, enable **"Serve
  on Local Network"**. This switches it from `127.0.0.1` to `0.0.0.0`.

Once that's done, find your host machine's LAN IP (e.g. `192.168.1.42`) and
enter it as the Server Address in LocalAI, e.g. `http://192.168.1.42:11434`
for Ollama or `http://192.168.1.42:1234` for LM Studio. Your phone needs to be
on the same Wi-Fi network as the host machine for this to work.

## 5. Connecting to Ollama / LM Studio remotely, over Tailscale

LocalAI doesn't embed any VPN or tunneling logic of its own — Server Address
is a plain URL, so remote access is a matter of putting your phone and your
host machine on the same private network first, then entering *that*
network's address instead of a LAN one. [Tailscale](https://tailscale.com)
(free for personal use) is the recommended way to do this:

1. **On the host machine**: install Tailscale and sign in. Make sure the
   Backend is also reachable beyond loopback, per section 4 above
   (`OLLAMA_HOST=0.0.0.0:...` for Ollama, "Serve on Local Network" for LM
   Studio) — Tailscale traffic still needs the server bound to more than
   `127.0.0.1` to reach it.
2. **On your iPhone**: install the official Tailscale app from the App Store
   and sign in with the *same* account.
3. Find the host machine's Tailscale address (`tailscale ip -4`, or the
   Tailscale admin console / menu bar app) — a `100.x.x.x` address, or a
   MagicDNS name like `my-mac.tailxxxx.ts.net`.
4. In LocalAI's Settings, enter that address as the Server Address instead of
   the LAN one, e.g. `http://100.64.1.42:11434`.

This works from anywhere your phone has internet access — no port forwarding,
no router configuration. Under the hood, it's the same mechanism LM Studio's
own "LM Link" feature uses (it's built on Tailscale too) — LM Studio just
automates the setup for its own companion app ("Locally"), which LocalAI
doesn't have access to, so this manual Tailscale setup is the supported path
here.

## 6. Privacy & security

- Chats, attachments, and model replies are processed on-device or on your
  own Backend machine — never uploaded to a server LocalAI's developers
  control.
- Retention Period (in Settings) controls how long a Chat is kept before
  automatic expiry; conversations can also be deleted manually at any time.
- If you enable remote access per section 5, keep the host machine's OS,
  Ollama/LM Studio installation, and Tailscale client up to date.

## 7. Known limitations

- No mobile SDK or public API exists (as of this writing) for LM Studio's
  account-based "LM Link" auto-connect — that convenience is exclusive to LM
  Studio's own "Locally" app. LocalAI supports remote access via the
  underlying Tailscale mechanism instead (section 5), which requires a bit
  more manual setup but works the same way for both Backends.
- iPhone only (`TARGETED_DEVICE_FAMILY: 1`) — no iPad-specific layout yet.
- Only Ollama and LM Studio are supported, both via their shared
  OpenAI-compatible API surface — Ollama's native-only API features aren't
  used (see [ADR-0001](docs/adr/0001-openai-compatible-backend-client.md)).

## 8. Contributing

Issues and specs live as GitHub Issues on this repo, with a branch-per-issue
workflow (`issue-N-slug`). See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)
for the conventions, and [`CONTEXT.md`](CONTEXT.md) for this project's domain
vocabulary (Backend, Server Address, Model, Chat, etc.) before introducing new
terms.
