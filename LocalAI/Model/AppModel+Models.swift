import Foundation

extension AppModel {
    /// Fetches the current Backend's Model list. Called on init (for the
    /// default Backend) and whenever the Backend changes. On success, if no
    /// Model is currently selected, the first fetched Model is auto-selected
    /// — matching the old hardcoded-list behaviour as closely as possible.
    ///
    /// Cancels any in-flight fetch first: without this, switching Backend
    /// twice in quick succession (e.g. Ollama → LM Studio → Ollama) could let
    /// the first, slower fetch resolve last and overwrite the current
    /// Backend's state with stale results from a Backend that's no longer
    /// selected.
    func loadModels() {
        modelLoadTask?.cancel()
        modelListState = .loading
        let baseURL = currentServerURL
        modelLoadTask = Task {
            do {
                let models = try await modelCatalogClient.fetchModels(baseURL: baseURL)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.modelListState = .loaded(models)
                    if self.model == nil {
                        self.model = models.first
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.modelListState = .failed
                }
            }
        }
    }
}
