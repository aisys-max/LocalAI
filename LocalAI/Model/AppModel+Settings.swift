import Foundation

extension AppModel {
    func selectBackend(_ b: Backend) {
        backend = b
        model = nil
        // Whatever was pending validation belonged to the old Backend's
        // Model namespace — irrelevant now, and `model == nil` already
        // makes the pending-validation branch a no-op, but clearing it
        // explicitly avoids leaving stale state around to reason about.
        modelPendingValidation = nil
        persistSettings()
        // Route through the retry loop if one is active, rather than calling
        // loadModels() directly — otherwise switching Backend mid-retry would
        // cancel the loop's in-flight fetch, leaving it stuck on `.loading`
        // and silently killing auto-retry for good.
        if modelRetryLoopTask != nil {
            startModelRetryLoop()
        } else {
            loadModels()
        }
    }
    func selectModel(_ m: String) { model = m; persistSettings() }
    func setAppearance(_ a: AppearanceMode) { appearance = a; persistSettings() }
    func setLanguage(_ l: AppLanguage) { language = l; persistSettings() }

    /// Shortening the Retention Period takes effect immediately — any Chat
    /// now outside the window is pruned right away, not deferred to the
    /// next launch. Lengthening it is a no-op for `pruneExpiredChats()`
    /// (nothing to prune), so it's always safe to call unconditionally
    /// rather than branching on direction.
    func setRetentionPeriod(_ period: RetentionPeriod) {
        retentionPeriod = period
        persistSettings()
        pruneExpiredChats()
    }

    func serverAddress(for backend: Backend) -> String {
        backendServerAddresses[backend] ?? backend.defaultServerAddress
    }

    func setServerAddress(_ address: String, for backend: Backend) {
        backendServerAddresses[backend] = address
        persistSettings()
    }

    /// Saves the current Settings snapshot — called at well-defined mutation
    /// points (like `AppModel+Chat.swift`'s `persistChat(_:)`), not via a
    /// blanket `didSet` on every field.
    func persistSettings() {
        persistenceStore.saveSettings(PersistedSettings(
            backend: backend,
            model: model,
            backendServerAddresses: backendServerAddresses,
            appearance: appearance,
            language: language,
            retentionPeriod: retentionPeriod
        ))
    }

    /// Copies every Settings field from `settings` onto the matching
    /// `@Published` property — the one place that does this field-by-field,
    /// shared by `AppModel.init` (applying persisted Settings) and
    /// `resetToDefault()` (applying `PersistedSettings.default`), so a
    /// future Settings field can't be added to one and forgotten in the
    /// other. Doesn't call `persistSettings()` itself — callers decide
    /// whether/when the applied values need saving.
    func applySettings(_ settings: PersistedSettings) {
        backend = settings.backend
        model = settings.model
        backendServerAddresses = settings.backendServerAddresses
        appearance = settings.appearance
        language = settings.language
        retentionPeriod = settings.retentionPeriod
    }

    /// Wipes every persisted Chat/Message, resets all of Settings to
    /// `PersistedSettings.default`, clears the draft and onboarding
    /// progress, and returns to onboarding — applied immediately,
    /// in-session, no relaunch needed. Reuses `deleteChats(in: .all)` for
    /// the Chat wipe rather than reimplementing it.
    ///
    /// Stops any in-flight Model-list work first (`stopAllModelWork()`
    /// cancels both the retry loop and a bare `loadModels()` fetch — unlike
    /// plain `stopModelRetryLoop()`, which leaves a bare fetch to resolve):
    /// without this, a fetch already in flight for the *old* Backend could
    /// resolve after the reset and silently re-persist a non-default Model,
    /// making the reset not actually final. `modelListState` and
    /// `modelPendingValidation` are reset alongside it so nothing stale
    /// carries into onboarding. A `streamReply` Task from an in-flight
    /// Generation isn't (and can't be straightforwardly be) cancelled here
    /// — no reference to it is kept past `sendMessage()`/`regenerate()`
    /// returning — but it's harmless: every mutation it can still make
    /// (`persistChat`, `appendReplyChunk`, `appendAssistantMessage`)
    /// already no-ops once its Chat is gone from `chats`, which
    /// `deleteChats(in: .all)` below guarantees.
    func resetToDefault() {
        stopAllModelWork()
        generating = false
        copyResetTask?.cancel()
        copiedId = nil
        legalOpenKey = nil

        deleteChats(in: .all)
        draft = ""

        applySettings(.default)
        modelPendingValidation = nil
        persistSettings()

        onboardingStep = 0
        screen = .onboarding

        // Matches AppModel.init, which always kicks off a fetch for the
        // (default) Backend at the end — without this, `modelListState`
        // just sits at whatever `stopAllModelWork()` left it/`.loading`
        // forever, since onboarding's Backend step only calls
        // `selectBackend(_:)` (which would otherwise trigger this) if the
        // user taps a card, not when the already-selected default is kept.
        loadModels()
    }

    /// The current Backend's server address, parsed as a URL for the
    /// backend client — falls back to the Backend's default if the
    /// configured address isn't a valid absolute URL. `URL(string:)` alone
    /// isn't enough here: it happily parses scheme-less text (e.g. "not a
    /// url") as a relative URL instead of returning nil, so validity is
    /// checked by requiring a scheme and host.
    var currentServerURL: URL {
        let address = serverAddress(for: backend)
        if let url = URL(string: address), url.scheme != nil, url.host != nil {
            return url
        }
        return URL(string: backend.defaultServerAddress)!
    }
}
