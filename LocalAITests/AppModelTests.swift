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

    @Test func historyGroupsOrderTodayYesterdayPrevious7() {
        let model = makeTestAppModel()
        let groups = model.historyGroups
        let days = groups.map(\.day)
        #expect(days == days.sorted { a, b in
            let order: [ChatDay: Int] = [.today: 0, .yesterday: 1, .previous7: 2]
            return order[a]! < order[b]!
        })
    }

    @Test func copyMessageSetsCopiedId() {
        let model = makeTestAppModel()
        model.copyMessage(id: "m1", text: "some text")
        #expect(model.copiedId == "m1")
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

    @Test func goHistorySettingsChatUpdateScreen() {
        let model = makeTestAppModel()
        model.goHistory()
        #expect(model.screen == .history)
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
}
