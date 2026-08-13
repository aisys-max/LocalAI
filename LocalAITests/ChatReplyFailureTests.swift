import Testing
import Foundation
@testable import LocalAI

struct ChatReplyFailureTests {
    @Test func urlErrorsThatMeanTheServerIsUnreachableClassifyAsUnreachable() {
        for code: URLError.Code in [.notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .dnsLookupFailed] {
            #expect(classifyChatReplyFailure(URLError(code)) == .unreachable)
        }
    }

    @Test func urlErrorTimedOutClassifiesAsTimeout() {
        #expect(classifyChatReplyFailure(URLError(.timedOut)) == .timeout)
    }

    @Test func notFoundBadResponseClassifiesAsModelNotFound() {
        let error = OpenAICompatibleChatBackendClientError.badResponse(statusCode: 404)
        #expect(classifyChatReplyFailure(error) == .modelNotFound)
    }

    @Test func nonNotFoundBadResponseClassifiesAsOther() {
        let error = OpenAICompatibleChatBackendClientError.badResponse(statusCode: 500)
        #expect(classifyChatReplyFailure(error) == .other)
    }

    @Test func badResponseWithNoStatusCodeClassifiesAsOther() {
        let error = OpenAICompatibleChatBackendClientError.badResponse(statusCode: nil)
        #expect(classifyChatReplyFailure(error) == .other)
    }

    @Test func unrecognizedErrorClassifiesAsOther() {
        struct SomeOtherError: Error {}
        #expect(classifyChatReplyFailure(SomeOtherError()) == .other)
    }
}
