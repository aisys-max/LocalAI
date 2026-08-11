import Foundation

extension AppModel {
    func selectBackend(_ b: Backend) {
        backend = b
        model = nil
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
    func selectModel(_ m: String) { model = m }
    func setAppearance(_ a: AppearanceMode) { appearance = a }
    func setLanguage(_ l: AppLanguage) { language = l }

    func serverAddress(for backend: Backend) -> String {
        backendServerAddresses[backend] ?? backend.defaultServerAddress
    }

    func setServerAddress(_ address: String, for backend: Backend) {
        backendServerAddresses[backend] = address
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
