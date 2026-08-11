# LocalAI

SwiftUI port of the "Local AI Chat App Design" Claude Design prototype — a
local-LLM (Ollama / LM Studio) chat client. Chat responses are currently
simulated (canned replies), matching the source design 1:1; there is no real
network layer yet.

## Folder structure

```
LocalAI/                  # app target source root
  LocalAIApp.swift        # @main entry point, owns the AppModel
  RootView.swift           # top-level switch over AppModel.screen
  Model/                   # state + data, no SwiftUI imports beyond ObservableObject
    AppModel.swift          # single ObservableObject driving all screens — @Published state + init only;
    AppModel+Navigation.swift  # behavior organized by concern into these extensions
    AppModel+Settings.swift
    AppModel+Onboarding.swift
    AppModel+Chat.swift
    ChatBackendClient.swift  # ChatBackendClient protocol + SimulatedChatBackendClient (canned replies) — the seam a real Ollama/LM Studio client slots into
    Chat.swift               # Chat / ChatMessage / MessageBlock / InlinePart — pure data, no logic
    Backend.swift             # Backend enum (ollama/lmstudio) + per-backend model lists
    Localization.swift        # AppLanguage enum + en/ko string + legal-text tables
  Views/                   # one subfolder per screen, mirroring the design's screen states
    Onboarding/
    Chat/                    # also owns MessageParsing.swift (markdown-lite renderer, presentation logic)
    History/
    Settings/               # also owns LegalSheetView (opened from Settings' About section)
    ModelPicker/
    Components/              # cross-screen reusable pieces only (segmented pill control, icon button, step header)
  Theme/
    Theme.swift              # color + font tokens, light/dark variants, ported from the design's styles.css
  Assets.xcassets/
LocalAITests/              # unit tests (Swift Testing), one test file per corresponding source file
```

**Where new files go:** a file belongs in `Components/` only if more than one
screen uses it; otherwise it goes in its own screen's folder. This structure
doc should only change when the top-level shape changes (a new screen, a
renamed module) — not every time a file is added inside an existing folder.

## Architecture changes

Architecture-level changes — new abstractions/protocols, splitting or
merging `ObservableObject`s, adding new top-level state layers, or
restructuring how `Model/`/`Views/` communicate — should be discussed and
agreed on before implementation, not decided unilaterally mid-task.

New logic added under `Model/` or extracted into its own file should come
with unit tests in `LocalAITests/` (Swift Testing), named to match the
source file (e.g. `Fixtures.swift` → `FixturesTests.swift`).

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`aisys-max/LocalAI`), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — `CONTEXT.md` + `docs/adr/` at the repo root, created lazily. See `docs/agents/domain.md`.
