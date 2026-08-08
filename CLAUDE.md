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
    AppModel.swift          # single ObservableObject driving all screens (port of the design's Component state)
    Chat.swift               # Chat / Message / MessageBlock / InlinePart
    Backend.swift             # Backend enum (ollama/lmstudio) + per-backend model lists
    Localization.swift        # AppLanguage enum + en/ko string + legal-text tables
  Views/                   # one subfolder per screen, mirroring the design's screen states
    Onboarding/
    Chat/
    History/
    Settings/               # also owns LegalSheetView (opened from Settings' About section)
    ModelPicker/
    Components/              # cross-screen reusable pieces only (segmented pill control, icon button)
  Theme/
    Theme.swift              # color + font tokens, light/dark variants, ported from the design's styles.css
  Assets.xcassets/
```

**Where new files go:** a file belongs in `Components/` only if more than one
screen uses it; otherwise it goes in its own screen's folder. This structure
doc should only change when the top-level shape changes (a new screen, a
renamed module) — not every time a file is added inside an existing folder.
