# LocalAI

A SwiftUI local-LLM chat client that talks to a locally-running Ollama or LM Studio server.

## Language

**Backend**:
A locally-running LLM server the app connects to for generating replies — either Ollama or LM Studio. Each Backend has its own base URL and its own list of installable Models.
_Avoid_: Provider, model server.

**Model**:
A specific LLM (e.g. "Llama 3.1 8B") available on the currently selected Backend. The list of Models for a Backend is fetched live from that Backend, not hardcoded.
_Avoid_: Checkpoint, engine.

**Chat**:
A single conversation thread: an ordered list of ChatMessages plus display metadata (title, snippet, day grouping). Identified by id, stored in `AppModel.chats`.
_Avoid_: Conversation, session, thread.

**Generation**:
The in-flight act of a Backend producing an assistant ChatMessage for a Chat, delivered incrementally as streamed text chunks rather than as one final string.
_Avoid_: Completion, response (those name the result, not the act).

**Simulated Backend**:
`SimulatedChatBackendClient` — a canned-reply stand-in for a real Backend connection, kept for SwiftUI previews and network-free unit tests. Not used as the app's default once a real Backend client exists.
_Avoid_: Mock backend, fake backend (this is a product-facing fallback, not a test double).
