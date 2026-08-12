import Testing
import Foundation
@testable import LocalAI

@MainActor
@Suite struct AppModelChatTests {
    @Test func sendMessageAppendsUserMessageImmediatelyThenAssistantReply() async {
        let model = makeTestAppModel(backendClient: FakeChatBackendClient(reply: "hello there"))
        model.selectModel("test-model")
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "hi"
        model.sendMessage()

        #expect(model.chats[chatId]?.messages.last?.role == .user)
        #expect(model.generating == true)
        #expect(model.draft == "")

        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.generating == false)
        #expect(model.chats[chatId]?.messages.last?.text == "hello there")
    }

    @Test func sendMessageAssemblesReplyFromStreamedChunks() async {
        let model = makeTestAppModel(backendClient: FakeChatBackendClient(chunks: ["hel", "lo ", "there"]))
        model.selectModel("test-model")
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "hi"
        model.sendMessage()

        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.generating == false)
        #expect(model.chats[chatId]?.messages.last?.text == "hello there")
        #expect(model.chats[chatId]?.messages.last?.role == .assistant)
    }

    @Test func sendMessageWithNoModelSelectedStillPostsTheUserMessageButDoesNotGenerate() async {
        let model = makeTestAppModel(backendClient: FakeChatBackendClient(reply: "should not appear"))
        // No selectModel() call — model.model stays nil until the fake catalog's
        // async load resolves, which hasn't happened yet on this synchronous path.
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "hi"
        model.sendMessage()

        #expect(model.chats[chatId]?.messages.last?.role == .user)
        #expect(model.generating == false)
    }

    @Test func firstUserMessageSetsChatTitle() async {
        let model = makeTestAppModel()
        model.selectModel("test-model")
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "What's the weather like today?"
        model.sendMessage()

        #expect(model.chats[chatId]?.title == "What's the weather like today?")
    }

    @Test func regenerateRemovesMessageAndProducesNewReply() async {
        let model = makeTestAppModel(backendClient: FakeChatBackendClient(reply: "second reply"))
        model.selectModel("test-model")
        model.newChat()
        let chatId = model.currentChatId!
        let greetingId = model.chats[chatId]!.messages[0].id

        model.regenerate(chatId: chatId, messageId: greetingId)

        #expect(model.chats[chatId]?.messages.contains { $0.id == greetingId } == false)
        #expect(model.generating == true)

        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.generating == false)
        #expect(model.chats[chatId]?.messages.last?.text == "second reply")
    }

    @Test func copyMessageSetsCopiedId() {
        let model = makeTestAppModel()
        model.copyMessage(id: "m1", text: "some text")
        #expect(model.copiedId == "m1")
    }

    @Test func deleteMessageRemovesItFromTheChat() {
        let model = makeTestAppModel()
        model.newChat()
        let chatId = model.currentChatId!
        let greetingId = model.chats[chatId]!.messages[0].id

        model.deleteMessage(chatId: chatId, messageId: greetingId)

        #expect(model.chats[chatId]?.messages.contains { $0.id == greetingId } == false)
    }

    @Test func deleteMessageLeavesOtherMessagesInPlace() async {
        let model = makeTestAppModel(backendClient: FakeChatBackendClient(reply: "hello there"))
        model.selectModel("test-model")
        model.newChat()
        let chatId = model.currentChatId!
        let greetingId = model.chats[chatId]!.messages[0].id

        model.draft = "hi"
        model.sendMessage()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let userMessageId = model.chats[chatId]!.messages[1].id

        model.deleteMessage(chatId: chatId, messageId: greetingId)

        #expect(model.chats[chatId]?.messages.contains { $0.id == userMessageId } == true)
    }

    @Test func deleteMessageWithAnUnknownChatIdIsANoOp() {
        let model = makeTestAppModel()
        model.newChat()
        let chatId = model.currentChatId!
        let messageCountBefore = model.chats[chatId]!.messages.count

        model.deleteMessage(chatId: "no-such-chat", messageId: "no-such-message")

        #expect(model.chats[chatId]?.messages.count == messageCountBefore)
    }

    @Test func newChatSetsCreatedAtToNow() {
        let model = makeTestAppModel()
        model.newChat()
        let chat = model.chats[model.currentChatId!]!
        #expect(abs(chat.createdAt.timeIntervalSinceNow) < 1)
    }

    // MARK: - chatDayBucket

    @Test func chatDayBucketReturnsTodayForATimestampEarlierTheSameDay() {
        let now = DeleteRangeFixture.now
        let earlierToday = DeleteRangeFixture.calendar.date(byAdding: .hour, value: -3, to: now)!
        #expect(chatDayBucket(for: earlierToday, now: now, calendar: DeleteRangeFixture.calendar) == .today)
    }

    @Test func chatDayBucketReturnsYesterdayForATimestampYesterday() {
        #expect(chatDayBucket(for: DeleteRangeFixture.yesterday, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar) == .yesterday)
    }

    @Test func chatDayBucketReturnsPrevious7ForATimestampSeveralDaysAgo() {
        #expect(chatDayBucket(for: DeleteRangeFixture.lastMonth, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar) == .previous7)
    }

    @Test func chatDayBucketFlipsFromYesterdayToTodayOnceNowCrossesMidnight() {
        // A timestamp at 23:59 stays "today" while `now` is still that same day...
        let lateInTheDay = DeleteRangeFixture.calendar.date(byAdding: .minute, value: -1, to: DeleteRangeFixture.now)!
        #expect(chatDayBucket(for: lateInTheDay, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar) == .today)
        // ...but becomes "yesterday" once `now` has moved to the next calendar day.
        let nextDay = DeleteRangeFixture.calendar.date(byAdding: .day, value: 1, to: DeleteRangeFixture.now)!
        #expect(chatDayBucket(for: lateInTheDay, now: nextDay, calendar: DeleteRangeFixture.calendar) == .yesterday)
    }

    // MARK: - deleteChats(in:)

    @Test func deleteChatsInTodayRemovesOnlyTodaysChatsAndLeavesOthers() {
        let model = DeleteRangeFixture.makeModelWithOneChatPerBucket()
        model.deleteChats(in: .today, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar)

        #expect(model.chats["today"] == nil)
        #expect(model.chats["yesterday"] != nil)
        #expect(model.chats["thisWeekEarlier"] != nil)
        #expect(model.chats["thisMonthEarlierWeek"] != nil)
        #expect(model.chats["lastMonth"] != nil)
    }

    @Test func deleteChatsInSinceYesterdayRemovesTodayAndYesterdayButNotOlder() {
        let model = DeleteRangeFixture.makeModelWithOneChatPerBucket()
        model.deleteChats(in: .sinceYesterday, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar)

        #expect(model.chats["today"] == nil)
        #expect(model.chats["yesterday"] == nil)
        #expect(model.chats["thisWeekEarlier"] != nil)
        #expect(model.chats["thisMonthEarlierWeek"] != nil)
        #expect(model.chats["lastMonth"] != nil)
    }

    @Test func deleteChatsInThisWeekRemovesEverythingFromTheCurrentCalendarWeek() {
        let model = DeleteRangeFixture.makeModelWithOneChatPerBucket()
        model.deleteChats(in: .thisWeek, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar)

        #expect(model.chats["today"] == nil)
        #expect(model.chats["yesterday"] == nil)
        #expect(model.chats["thisWeekEarlier"] == nil)
        #expect(model.chats["thisMonthEarlierWeek"] != nil)
        #expect(model.chats["lastMonth"] != nil)
    }

    @Test func deleteChatsInThisMonthRemovesEverythingFromTheCurrentCalendarMonthIncludingEarlierWeeksOfIt() {
        let model = DeleteRangeFixture.makeModelWithOneChatPerBucket()
        model.deleteChats(in: .thisMonth, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar)

        #expect(model.chats["today"] == nil)
        #expect(model.chats["yesterday"] == nil)
        #expect(model.chats["thisWeekEarlier"] == nil)
        #expect(model.chats["thisMonthEarlierWeek"] == nil)
        #expect(model.chats["lastMonth"] != nil)
    }

    @Test func deleteChatsInAllRemovesEveryChatRegardlessOfCreatedAt() {
        let model = DeleteRangeFixture.makeModelWithOneChatPerBucket()
        model.deleteChats(in: .all, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar)

        #expect(model.chats.isEmpty)
    }

    @Test func deleteChatsInAllOnAnEmptyChatsDictionaryIsANoOp() {
        let model = makeTestAppModel()
        model.deleteChats(in: .all)
        #expect(model.chats.isEmpty)
    }

    @Test func deleteChatsInRangeClearsCurrentChatIdWhenTheOpenChatFallsInRange() {
        let model = DeleteRangeFixture.makeModelWithOneChatPerBucket()
        model.currentChatId = "today"

        model.deleteChats(in: .today, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar)

        #expect(model.currentChatId == nil)
    }

    @Test func deleteChatsInRangeLeavesCurrentChatIdUntouchedWhenTheOpenChatIsOutsideRange() {
        let model = DeleteRangeFixture.makeModelWithOneChatPerBucket()
        model.currentChatId = "lastMonth"

        model.deleteChats(in: .today, now: DeleteRangeFixture.now, calendar: DeleteRangeFixture.calendar)

        #expect(model.currentChatId == "lastMonth")
    }

    @Test func deletingAllChatsFollowedByNewChatLeavesExactlyOneFreshChat() {
        let model = makeTestAppModel()
        model.newChat()
        let oldId = model.currentChatId!
        model.chats[oldId]!.messages.append(ChatMessage(id: "extra", role: .user, text: "some history"))

        // Mirrors ChatView's trash-icon dialog handler for the "All" range. newChat()
        // derives ids from a millisecond timestamp, so back-to-back calls can land on
        // the same id — assert on the resulting chat's freshness rather than id (in)equality.
        model.deleteChats(in: .all)
        model.newChat()

        #expect(model.chats.count == 1)
        #expect(model.currentChatId != nil)
        let freshChat = model.chats[model.currentChatId!]!
        #expect(freshChat.messages.count == 1)
        #expect(freshChat.messages.first?.isGreeting == true)
    }
}

/// Fixed, deterministic dates for range/bucketing tests — real wall-clock
/// `Date()` would make week/month-boundary assertions flaky depending on
/// when the test happens to run.
private enum DeleteRangeFixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }()

    /// Wednesday, June 12 2024, safely mid-week and mid-month.
    static let now: Date = date(year: 2024, month: 6, day: 12, hour: 12)
    /// Same week as `now` (week runs Sun June 9 – Sat June 15).
    static let yesterday: Date = date(year: 2024, month: 6, day: 11, hour: 12)
    static let thisWeekEarlier: Date = date(year: 2024, month: 6, day: 9, hour: 8)
    /// Previous week (June 2–8), same month as `now`.
    static let thisMonthEarlierWeek: Date = date(year: 2024, month: 6, day: 2, hour: 8)
    /// A different month entirely.
    static let lastMonth: Date = date(year: 2024, month: 5, day: 15, hour: 8)

    static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = hour
        return calendar.date(from: components)!
    }

    static func makeChat(id: String, createdAt: Date) -> Chat {
        Chat(id: id, createdAt: createdAt, title: "title", snippet: "snippet", messages: [])
    }

    @MainActor
    static func makeModelWithOneChatPerBucket() -> AppModel {
        let model = makeTestAppModel()
        model.chats = [
            "today": makeChat(id: "today", createdAt: now),
            "yesterday": makeChat(id: "yesterday", createdAt: yesterday),
            "thisWeekEarlier": makeChat(id: "thisWeekEarlier", createdAt: thisWeekEarlier),
            "thisMonthEarlierWeek": makeChat(id: "thisMonthEarlierWeek", createdAt: thisMonthEarlierWeek),
            "lastMonth": makeChat(id: "lastMonth", createdAt: lastMonth),
        ]
        model.currentChatId = nil
        return model
    }
}

@MainActor
@Suite struct AppModelNavigationTests {
    @Test func modelPickerRoundTripsBackToItsOrigin() {
        for origin: Screen in [.settings, .onboarding, .chat] {
            let model = makeTestAppModel()
            model.openModelPicker(from: origin)
            #expect(model.screen == .modelPicker)
            model.closeModelPicker()
            #expect(model.screen == origin)
        }
    }

    @Test func goSettingsChatUpdateScreen() {
        let model = makeTestAppModel()
        model.goSettings()
        #expect(model.screen == .settings)
        model.goChat()
        #expect(model.screen == .chat)
    }

    @Test func openAndCloseLegalTogglesLegalOpenKey() {
        let model = makeTestAppModel()
        model.openLegal(.privacy)
        #expect(model.legalOpenKey == .privacy)
        model.closeLegal()
        #expect(model.legalOpenKey == nil)
    }
}

@MainActor
@Suite struct AppModelSettingsTests {
    @Test func selectModelUpdatesModel() {
        let model = makeTestAppModel()
        model.selectModel("Some Model")
        #expect(model.model == "Some Model")
    }

    @Test func setAppearanceAndLanguageUpdateState() {
        let model = makeTestAppModel()
        model.setAppearance(.dark)
        #expect(model.appearance == .dark)
        model.setLanguage(.ko)
        #expect(model.language == .ko)
    }

    @Test func serverAddressDefaultsToEachBackendsStandardPort() {
        let model = makeTestAppModel()
        #expect(model.serverAddress(for: .ollama) == "http://localhost:11434")
        #expect(model.serverAddress(for: .lmstudio) == Backend.lmstudio.defaultServerAddress)
    }

    @Test func setServerAddressIsStoredPerBackendIndependently() {
        let model = makeTestAppModel()
        model.setServerAddress("http://192.168.1.5:11434", for: .ollama)
        model.setServerAddress("http://192.168.1.5:1234", for: .lmstudio)

        #expect(model.serverAddress(for: .ollama) == "http://192.168.1.5:11434")
        #expect(model.serverAddress(for: .lmstudio) == "http://192.168.1.5:1234")
    }

    @Test func switchingBackendDoesNotClobberTheOtherBackendsCustomAddress() {
        let model = makeTestAppModel()
        model.setServerAddress("http://custom-ollama:11434", for: .ollama)

        model.selectBackend(.lmstudio)
        model.setServerAddress("http://custom-lmstudio:1234", for: .lmstudio)
        model.selectBackend(.ollama)

        #expect(model.serverAddress(for: .ollama) == "http://custom-ollama:11434")
        #expect(model.serverAddress(for: .lmstudio) == "http://custom-lmstudio:1234")
    }

    @Test func currentServerURLFallsBackToTheBackendsDefaultWhenTheStoredAddressIsInvalid() {
        let model = makeTestAppModel()
        model.setServerAddress("not a url", for: .ollama)
        #expect(model.currentServerURL == URL(string: Backend.ollama.defaultServerAddress)!)
    }

    @Test func currentServerURLReflectsAValidCustomAddress() {
        let model = makeTestAppModel()
        model.setServerAddress("http://192.168.1.5:11434", for: .ollama)
        #expect(model.currentServerURL == URL(string: "http://192.168.1.5:11434")!)
    }
}

@MainActor
@Suite struct AppModelModelsTests {
    @Test func initTriggersAnInitialLoadThatAutoSelectsTheFirstModel() async {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1", "m2"]))
        #expect(model.model == nil)
        #expect(model.modelListState == .loading)

        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.modelListState == .loaded(["m1", "m2"]))
        #expect(model.model == "m1")
    }

    @Test func loadModelsOnFailureSetsFailedStateAndLeavesModelUnset() async {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(shouldFail: true))
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.modelListState == .failed)
        #expect(model.model == nil)
    }

    @Test func loadModelsOnEmptyResultLeavesModelUnset() async {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: []))
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.modelListState == .loaded([]))
        #expect(model.model == nil)
    }

    @Test func loadModelsDoesNotOverrideAnAlreadySelectedModel() async {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1", "m2"]))
        model.selectModel("user-picked")
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.modelListState == .loaded(["m1", "m2"]))
        #expect(model.model == "user-picked")
    }

    @Test func selectBackendClearsModelAndTriggersAFreshLoadForTheNewBackend() async {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["ollama-model"]))
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(model.model == "ollama-model")

        model.selectBackend(.lmstudio)
        #expect(model.backend == .lmstudio)
        #expect(model.model == nil)
        #expect(model.modelListState == .loading)

        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(model.modelListState == .loaded(["ollama-model"]))
        #expect(model.model == "ollama-model")
    }

    @Test func retryAfterAFailureCanSucceed() async {
        let fake = ToggleableModelCatalogClient(shouldFail: true)
        let model = makeTestAppModel(modelCatalogClient: fake)
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(model.modelListState == .failed)

        fake.shouldFail = false
        fake.models = ["recovered-model"]
        model.loadModels()
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.modelListState == .loaded(["recovered-model"]))
        #expect(model.model == "recovered-model")
    }

    @Test func loadModelsTimesOutWhenTheFetchExceedsTheTimeout() async {
        let fake = DelayedModelCatalogClient(delayNanoseconds: 40_000_000, models: ["too-slow"])
        let model = makeTestAppModel(modelCatalogClient: fake, modelFetchTimeoutNanoseconds: 10_000_000)

        let state = await model.loadModels().value

        #expect(state == .timedOut)
        #expect(model.modelListState == .timedOut)
    }

    @Test func loadModelsResolvesNormallyWhenFasterThanTheTimeout() async {
        let fake = DelayedModelCatalogClient(delayNanoseconds: 5_000_000, models: ["fast-enough"])
        let model = makeTestAppModel(modelCatalogClient: fake, modelFetchTimeoutNanoseconds: 40_000_000)

        let state = await model.loadModels().value

        #expect(state == .loaded(["fast-enough"]))
        #expect(model.model == "fast-enough")
    }

    @Test func retryLoopKeepsTryingUntilItSucceeds() async {
        let fake = ToggleableModelCatalogClient(shouldFail: true)
        let model = makeTestAppModel(modelCatalogClient: fake, modelRetryBackoffNanoseconds: 5_000_000)

        let loopTask = model.startModelRetryLoop()
        #expect(model.isRetryingModels == true)

        // Let it fail at least once, then flip the fake to succeed.
        try? await Task.sleep(nanoseconds: 12_000_000)
        fake.shouldFail = false
        fake.models = ["recovered-model"]

        await loopTask.value

        #expect(model.modelListState == .loaded(["recovered-model"]))
        #expect(model.model == "recovered-model")
        #expect(model.isRetryingModels == false) // loop clears itself on success
    }

    @Test func stopModelRetryLoopEndsTheLoopAndIgnoresLaterFakeChanges() async {
        let fake = ToggleableModelCatalogClient(shouldFail: true)
        let model = makeTestAppModel(modelCatalogClient: fake, modelRetryBackoffNanoseconds: 5_000_000)
        model.startModelRetryLoop()

        try? await Task.sleep(nanoseconds: 8_000_000)
        model.stopModelRetryLoop()
        #expect(model.isRetryingModels == false)

        // Even though the fake would now succeed, nothing should pick it up
        // — the loop was stopped, not paused.
        fake.shouldFail = false
        fake.models = ["should-not-appear"]
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(model.model != "should-not-appear")
    }

    @Test func selectBackendDuringAnActiveLoopKeepsRetryingForTheNewBackend() async {
        let fake = SlowModelCatalogClient()
        let ollamaURL = URL(string: Backend.ollama.defaultServerAddress)!
        let lmstudioURL = URL(string: Backend.lmstudio.defaultServerAddress)!
        // Ollama always fails (slowly enough to still be in flight when we
        // switch Backend); LM Studio succeeds fast.
        fake.responses = [
            SlowModelCatalogClient.Response(baseURL: ollamaURL, delayNanoseconds: 40_000_000, shouldFail: true),
            SlowModelCatalogClient.Response(baseURL: lmstudioURL, delayNanoseconds: 2_000_000, models: ["lmstudio-model"]),
        ]
        let model = makeTestAppModel(modelCatalogClient: fake, modelRetryBackoffNanoseconds: 5_000_000)

        model.startModelRetryLoop()
        try? await Task.sleep(nanoseconds: 5_000_000) // Ollama's attempt is still in flight (40ms delay)
        #expect(model.isRetryingModels == true)

        model.selectBackend(.lmstudio)
        // selectBackend() re-enters the loop with a *new* task; don't await
        // the old (now-superseded) loop task — wait for the new one to settle.
        try? await Task.sleep(nanoseconds: 15_000_000)

        #expect(model.backend == .lmstudio)
        #expect(model.modelListState == .loaded(["lmstudio-model"]))
        #expect(model.model == "lmstudio-model")
    }

    @Test func resumeModelRetryLoopIfNeededStartsALoopWhenAlreadyFailed() async {
        let fake = FakeModelCatalogClient(shouldFail: true)
        let model = makeTestAppModel(modelCatalogClient: fake)
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(model.modelListState == .failed)
        #expect(model.isRetryingModels == false)

        model.resumeModelRetryLoopIfNeeded()

        #expect(model.isRetryingModels == true)
    }

    @Test func resumeModelRetryLoopIfNeededDoesNothingWhenAlreadyLoadedAndAddressUnchanged() async {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1"]))
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(model.modelListState == .loaded(["m1"]))

        model.resumeModelRetryLoopIfNeeded()

        #expect(model.isRetryingModels == false)
        #expect(model.modelListState == .loaded(["m1"])) // untouched
    }

    @Test func resumeModelRetryLoopIfNeededStartsAFreshLoadWhenTheAddressChangedSinceTheLastFetch() async {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["old-address-model"]))
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(model.modelListState == .loaded(["old-address-model"]))

        model.setServerAddress("http://192.168.1.50:11434", for: .ollama)
        model.resumeModelRetryLoopIfNeeded()

        #expect(model.model == nil) // cleared immediately
        #expect(model.isRetryingModels == true)
    }

    @Test func editingTheAddressAloneDoesNotTriggerAReloadUntilNavigation() {
        let model = makeTestAppModel(modelCatalogClient: FakeModelCatalogClient(models: ["m1"]))
        model.setServerAddress("http://192.168.1.50:11434", for: .ollama)

        // No navigation happened — resumeModelRetryLoopIfNeeded() was never
        // called, so nothing should have restarted yet (guards against
        // reloading on every keystroke of a live-bound TextField).
        #expect(model.isRetryingModels == false)
    }

    @Test func goChatStopsAnActiveRetryLoop() async {
        let fake = FakeModelCatalogClient(shouldFail: true)
        let model = makeTestAppModel(modelCatalogClient: fake)
        try? await Task.sleep(nanoseconds: 10_000_000)
        model.resumeModelRetryLoopIfNeeded()
        #expect(model.isRetryingModels == true)

        model.goChat()

        #expect(model.isRetryingModels == false)
        #expect(model.screen == .chat)
    }

    @Test func closeModelPickerStopsTheLoopOnlyWhenReturningToChat() async {
        let fake = FakeModelCatalogClient(shouldFail: true)

        let fromChat = makeTestAppModel(modelCatalogClient: fake)
        try? await Task.sleep(nanoseconds: 10_000_000)
        fromChat.openModelPicker(from: .chat)
        #expect(fromChat.isRetryingModels == true)
        fromChat.closeModelPicker()
        #expect(fromChat.isRetryingModels == false)

        let fromSettings = makeTestAppModel(modelCatalogClient: fake)
        try? await Task.sleep(nanoseconds: 10_000_000)
        fromSettings.openModelPicker(from: .settings)
        #expect(fromSettings.isRetryingModels == true)
        fromSettings.closeModelPicker()
        #expect(fromSettings.isRetryingModels == true) // still within the Settings context
    }

    @Test func rapidBackendSwitchesDoNotLetAStaleSlowFetchOverwriteNewerState() async {
        let fake = SlowModelCatalogClient()
        let ollamaURL = URL(string: Backend.ollama.defaultServerAddress)!
        let lmstudioURL = URL(string: Backend.lmstudio.defaultServerAddress)!
        fake.responses = [
            SlowModelCatalogClient.Response(baseURL: ollamaURL, delayNanoseconds: 60_000_000, models: ["ollama-model"]),
            SlowModelCatalogClient.Response(baseURL: lmstudioURL, delayNanoseconds: 5_000_000, models: ["lmstudio-model"]),
        ]
        // init() already kicked off a slow fetch for the default Backend (.ollama).
        let model = makeTestAppModel(modelCatalogClient: fake)

        model.selectBackend(.lmstudio)

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(model.backend == .lmstudio)
        #expect(model.modelListState == .loaded(["lmstudio-model"]))
        #expect(model.model == "lmstudio-model")
    }
}

@MainActor
@Suite struct AppModelOnboardingTests {
    @Test func onboardingBackClampsAtZero() {
        let model = makeTestAppModel()
        model.onboardingBack()
        #expect(model.onboardingStep == 0)
    }

    @Test func onboardingNextIncrementsStep() {
        let model = makeTestAppModel()
        model.onboardingNext()
        model.onboardingNext()
        #expect(model.onboardingStep == 2)
    }

    @Test func finishOnboardingGoesToChatAndCreatesAChat() {
        let model = makeTestAppModel()
        model.selectModel("test-model")
        let chatCountBefore = model.chats.count
        model.finishOnboarding()
        #expect(model.screen == .chat)
        #expect(model.chats.count == chatCountBefore + 1)
        #expect(model.currentChatId != nil)
    }

    @Test func finishOnboardingSucceedsEvenWithoutAModelSelected() {
        // No selectModel() call — model.model stays nil (fetch never completed
        // on this synchronous path). Onboarding should still be finishable;
        // the user can pick a Model later in Settings.
        let model = makeTestAppModel()
        model.finishOnboarding()
        #expect(model.screen == .chat)
        #expect(model.model == nil)
        #expect(model.currentChatId != nil)
    }
}
