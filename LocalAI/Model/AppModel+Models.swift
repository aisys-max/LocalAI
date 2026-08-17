import Foundation

extension AppModel {
    /// Fetches the current Backend's Model list, racing it against
    /// `modelFetchTimeoutNanoseconds`. Returns the terminal `ModelListState`
    /// as the task's value — callers that need the outcome should `await
    /// loadModels().value` rather than re-reading `modelListState`
    /// afterwards, since that property may have moved on by the time a
    /// caller resumes (e.g. a newer `loadModels()` call, or the retry loop).
    ///
    /// Cancels any in-flight fetch first: without this, switching Backend
    /// twice in quick succession (e.g. Ollama → LM Studio → Ollama) could let
    /// the first, slower fetch resolve last and overwrite the current
    /// Backend's state with stale results from a Backend that's no longer
    /// selected.
    @discardableResult
    func loadModels() -> Task<ModelListState, Never> {
        modelLoadTask?.cancel()
        modelListState = .loading
        modelListFetchedForAddress = serverAddress(for: backend)
        let baseURL = currentServerURL
        let timeoutNanoseconds = modelFetchTimeoutNanoseconds
        let client = modelCatalogClient

        let task = Task<ModelListState, Never> {
            let resolvedState: ModelListState
            do {
                let models = try await withThrowingTaskGroup(of: [String].self) { group -> [String] in
                    group.addTask { try await client.fetchModels(baseURL: baseURL) }
                    group.addTask {
                        try await Task.sleep(nanoseconds: timeoutNanoseconds)
                        throw ModelFetchTimeoutError()
                    }
                    defer { group.cancelAll() }
                    guard let first = try await group.next() else {
                        throw ModelFetchTimeoutError()
                    }
                    return first
                }
                resolvedState = .loaded(models)
            } catch is ModelFetchTimeoutError {
                resolvedState = .timedOut
            } catch {
                resolvedState = .failed
            }

            guard !Task.isCancelled else { return resolvedState }
            await MainActor.run {
                self.modelListState = resolvedState
                if case .loaded(let models) = resolvedState {
                    // Only the persisted selection gets validated against the
                    // fetched list (and only once, ever) — a Model the user
                    // has since picked explicitly via selectModel() is never
                    // second-guessed here, no matter what the list contains.
                    if let pending = self.modelPendingValidation, self.model == pending, !models.contains(pending) {
                        self.model = nil
                    } else if self.model == nil {
                        self.model = models.first
                    }
                    self.modelPendingValidation = nil
                    self.persistSettings()
                }
            }
            return resolvedState
        }
        modelLoadTask = task
        return task
    }

    /// Starts (or restarts) an automatic retry loop: calls `loadModels()`,
    /// and if it lands in `.failed`/`.timedOut`, waits
    /// `modelRetryBackoffNanoseconds` and tries again, repeating until it
    /// succeeds or the loop is stopped (`stopModelRetryLoop()`, called when
    /// navigating back to Chat). Used by Settings/Model Picker so a user
    /// editing the server address — or returning to a Backend that
    /// previously failed to load — doesn't have to keep tapping Retry
    /// manually. A manual Retry tap in that context calls this same method,
    /// so there's only ever one retry driver active at a time.
    @discardableResult
    func startModelRetryLoop() -> Task<Void, Never> {
        modelRetryLoopTask?.cancel()
        modelListState = .loading
        isRetryingModels = true
        let backoffNanoseconds = modelRetryBackoffNanoseconds

        let task = Task {
            while !Task.isCancelled {
                let state = await self.loadModels().value
                guard !Task.isCancelled else { return }
                switch state {
                case .loaded:
                    await MainActor.run {
                        self.modelRetryLoopTask = nil
                        self.isRetryingModels = false
                    }
                    return
                case .failed, .timedOut:
                    try? await Task.sleep(nanoseconds: backoffNanoseconds)
                case .loading:
                    // Unreachable — loadModels()'s task always resolves to a
                    // terminal state — but clear the task reference defensively
                    // so isRetryingModels can't get stuck true if it ever does.
                    await MainActor.run {
                        self.modelRetryLoopTask = nil
                        self.isRetryingModels = false
                    }
                    return
                }
            }
        }
        modelRetryLoopTask = task
        return task
    }

    /// Stops the auto-retry loop, if one is running, and cancels whatever
    /// fetch it's currently mid-flight on. These are cancelled separately
    /// because they're independent unstructured tasks — cancelling the loop
    /// does not, by itself, cancel the fetch it most recently kicked off.
    func stopModelRetryLoop() {
        modelRetryLoopTask?.cancel()
        modelRetryLoopTask = nil
        isRetryingModels = false
        modelLoadTask?.cancel()
    }

    /// Call when entering Settings or the Model Picker: resumes trying in
    /// the background, without requiring a manual Retry tap, if either the
    /// server address changed since the last fetch or that fetch previously
    /// failed/timed out.
    func resumeModelRetryLoopIfNeeded() {
        guard modelRetryLoopTask == nil else { return }

        if modelListFetchedForAddress != serverAddress(for: backend) {
            model = nil
            persistSettings()
            startModelRetryLoop()
            return
        }

        switch modelListState {
        case .failed, .timedOut:
            startModelRetryLoop()
        case .loading, .loaded:
            break
        }
    }
}
