---
status: accepted
---

# One OpenAI-compatible HTTP client for both Backends

Ollama exposes both a native API (`/api/chat`) and an OpenAI-compatible endpoint (`/v1/chat/completions`); LM Studio only exposes the OpenAI-compatible shape. Rather than writing a native client per Backend, `ChatBackendClient` is implemented once, as `OpenAICompatibleChatBackendClient`, talking to whichever Backend's OpenAI-compatible endpoint is configured. This trades access to Ollama-native-only features for a single client implementation and a single code path to test — reversing it later means writing a Backend-native client and re-splitting the protocol's call sites.
