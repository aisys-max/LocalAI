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
                        try await Task.sleep(for: .nanoseconds(Int64(timeoutNanoseconds)))
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
            modelListState = resolvedState
            if case .loaded(let models) = resolvedState {
                // Only the persisted selection gets validated against the
                // fetched list (and only once, ever) — a Model the user
                // has since picked explicitly via selectModel() is never
                // second-guessed here, no matter what the list contains.
                if let pending = modelPendingValidation, model == pending, !models.contains(pending) {
                    model = nil
                } else if model == nil {
                    model = models.first
                }
                modelPendingValidation = nil
                persistSettings()
                // Catches up a Greeting comparison that `goChat()` had
                // to skip because `model` was still nil at the time
                // (see `reconcileGreetingForCurrentChat()`'s own nil
                // guard) — without this, a fetch that resolves after
                // the user has already returned to Chat (slower
                // networks, e.g. a remote Backend over Tailscale) would
                // otherwise never get a chance to update the Greeting.
                // Gated on `screen == .chat`: reconciliation is only
                // ever meant to happen on return to Chat, not while
                // still browsing Settings/Model Picker — a fetch that
                // resolves *before* the user has returned (the common
                // case on a fast/local network) must wait for `goChat()`
                // the same as always, so flipping Backend/Model back and
                // forth before returning still doesn't accumulate
                // Greetings the user never actually confirmed.
                if screen == .chat {
                    reconcileGreetingForCurrentChat()
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
                    modelRetryLoopTask = nil
                    isRetryingModels = false
                    return
                case .failed, .timedOut:
                    try? await Task.sleep(for: .nanoseconds(Int64(backoffNanoseconds)))
                case .loading:
                    // Unreachable — loadModels()'s task always resolves to a
                    // terminal state — but clear the task reference defensively
                    // so isRetryingModels can't get stuck true if it ever does.
                    modelRetryLoopTask = nil
                    isRetryingModels = false
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
    /// Only cancels `modelLoadTask` when a loop was actually running: a bare
    /// `loadModels()` fetch that isn't part of one (e.g. kicked off by a
    /// Backend/Model switch in Settings) is left to resolve normally even
    /// after this is called from `goChat()` — otherwise returning to Chat
    /// quickly after a switch would silently abandon that fetch, and
    /// `model` would never actually get set (see `reconcileGreetingForCurrentChat()`,
    /// which relies on this fetch eventually resolving to catch up the
    /// current Chat's Greeting). Use `stopAllModelWork()` where abandoning
    /// a bare fetch too is actually required.
    func stopModelRetryLoop() {
        let wasRetrying = modelRetryLoopTask != nil
        modelRetryLoopTask?.cancel()
        modelRetryLoopTask = nil
        isRetryingModels = false
        if wasRetrying {
            modelLoadTask?.cancel()
        }
    }

    /// Cancels every in-flight Model-list activity unconditionally — the
    /// retry loop (if any) and a bare, non-retry-loop `loadModels()` fetch
    /// alike. `goChat()` deliberately uses `stopModelRetryLoop()` instead
    /// (see its doc comment); `resetToDefault()` needs this stronger
    /// guarantee, since a stale fetch resolving after a reset could
    /// silently re-persist a non-default Model.
    func stopAllModelWork() {
        stopModelRetryLoop()
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
