import Foundation

/// How a failed `ChatBackendClient.generateReply` stream should be explained
/// to the user — coarse enough to map onto a handful of localized messages
/// without echoing raw networking errors into the chat.
enum ChatReplyFailureKind {
    case unreachable
    case timeout
    case modelNotFound
    case other
}

func classifyChatReplyFailure(_ error: Error) -> ChatReplyFailureKind {
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .dnsLookupFailed:
            return .unreachable
        case .timedOut:
            return .timeout
        default:
            return .other
        }
    }

    if case OpenAICompatibleChatBackendClientError.badResponse(.some(404)) = error {
        return .modelNotFound
    }

    return .other
}
