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
