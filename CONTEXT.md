# LocalAI

A SwiftUI local-LLM chat client that talks to a locally-running Ollama or LM Studio server.

## Language

**Backend**:
A locally-running LLM server the app connects to for generating replies — either Ollama or LM Studio. Each Backend has its own Server Address and its own list of installable Models.
_Avoid_: Provider, model server.

**Server Address**:
The URL a Backend is reached at (e.g. `http://localhost:11434`). Each Backend has its own, editable in Settings and defaulting to that Backend's standard local port. Persisted across app relaunches (via SwiftData), along with the rest of Settings.
_Avoid_: Base URL, endpoint (in user-facing/Settings contexts — "base URL" is fine as an internal implementation term).

**Model**:
A specific LLM (e.g. "Llama 3.1 8B") available on the currently selected Backend. The list of Models for a Backend is fetched live from that Backend, not hardcoded.
_Avoid_: Checkpoint, engine.

**Model list fetch**:
The in-flight act of loading a Backend's Model list, in one of four states: loading, loaded (possibly empty — a reachable Backend with nothing installed), failed (unreachable, bad response), or timed out (no response within 30 seconds — shown with its own message, distinct from a general failure). A failed, timed-out, or empty fetch is shown as its own state — it never falls back to a stale or hardcoded list. Triggered on app start and whenever the Backend changes; switching Backend again while a fetch is in flight cancels it, so a slow, stale fetch can't land after and overwrite a newer one.
_Avoid_: Model loading (ambiguous with a Model itself being "loaded" into a Backend).

**Auto-retry loop**:
In Settings and the Model Picker only (not onboarding), a failed or timed-out Model list fetch keeps retrying every 5 seconds in the background — on its own, or via a manual Retry tap, which just restarts the same loop rather than racing it. Also (re-)starts whenever Settings or the Model Picker is entered and the Server Address has changed since the last fetch, or that fetch previously failed/timed out. Stops when the user leaves Settings back to Chat — for now, that's the only "stop" signal; the loop otherwise runs until it succeeds. Onboarding never runs this loop — a failed or timed-out fetch there is a one-shot attempt with a manual Retry, and onboarding no longer requires a Model to be selected to finish (fix it later in Settings).
_Avoid_: Polling (this is triggered/bounded, not a fixed background poll independent of user action).

**Chat**:
A single conversation thread: an ordered list of ChatMessages plus display metadata (title, snippet, day grouping). Identified by id, stored in `AppModel.chats`. Persisted across app relaunches (via SwiftData), along with which Chat is currently open — the app resumes directly into the last-open Chat rather than landing on a blank/new one. The unsent composer draft also persists.
_Avoid_: Conversation, session, thread.

**Generation**:
The in-flight act of a Backend producing an assistant ChatMessage for a Chat, delivered incrementally as streamed text chunks rather than as one final string. A Generation interrupted by the app being killed or crashing (not a normal stream error) surfaces the same way an ordinary failed Generation does on next launch — the existing failure-message treatment, not a truncated partial reply left in place.
_Avoid_: Completion, response (those name the result, not the act).

**Greeting**:
A synthetic assistant ChatMessage (`ChatMessage.isGreeting`) worded against whichever Backend/Model was selected at the moment it was shown, then persisted like any other Message — never re-rendered live afterward. A new Chat gets one at creation; a Chat loaded from storage that predates this (zero Greeting Messages) gets one bootstrapped once, at launch. Returning to Chat (`AppModel.goChat()`, or a Model-list fetch resolving after the fact) compares the currently selected (Backend, Model) against the Chat's most recent Greeting: unchanged is a no-op; changed appends a new Greeting only if a real Message was sent *since that last Greeting* (leaving it and everything before it in place — a literal log of what happened, even a switch back to an earlier Backend/Model still appends once there's been real conversation since); otherwise it updates that last Greeting in place, whether the Chat is still fully unstarted or the user is just flipping Backend/Model again without sending anything in between. Identity is a fresh id per occurrence, not derived from the Chat's id, since a Chat can end up holding more than one over its lifetime.
_Avoid_: Welcome message, intro message.

**Retention Period**:
A user-chosen Settings option (1 week / 1 month / 6 months) controlling how long a Chat is kept before automatic expiry. Enforced at Chat granularity by `Chat.createdAt`, the same granularity as the existing manual bulk-delete ranges — never a partial, per-message trim. Checked once per app launch, and immediately whenever the period is shortened in Settings — lengthening it never resurrects an already-pruned Chat.
_Avoid_: Retention policy, TTL (internal-implementation terms; use Retention Period in user-facing/Settings contexts).

**Reset to Default**:
A destructive Settings action that wipes every persisted Chat/ChatMessage and resets all Settings (Backend, Model, appearance, language, Server Addresses, Retention Period) to their defaults, then returns the app to onboarding (`onboardingStep = 0`). Applies immediately, in-session — no relaunch needed. Reuses the app's existing two-step confirm-dialog pattern (the one already used for bulk-delete-all).
_Avoid_: Factory reset, wipe data (use Reset to Default in user-facing/Settings contexts).

**Simulated Backend**:
`SimulatedChatBackendClient` — a canned-reply stand-in for a real Backend connection, kept for SwiftUI previews and network-free unit tests. Not used as the app's default once a real Backend client exists.
_Avoid_: Mock backend, fake backend (this is a product-facing fallback, not a test double).
