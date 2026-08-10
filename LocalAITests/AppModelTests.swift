import Testing
@testable import LocalAI

@MainActor
@Suite struct AppModelChatTests {
    @Test func sendMessageAppendsUserMessageImmediatelyThenAssistantReply() async {
        let model = AppModel(backendClient: FakeChatBackendClient(reply: "hello there"))
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
        let model = AppModel(backendClient: FakeChatBackendClient(chunks: ["hel", "lo ", "there"]))
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "hi"
        model.sendMessage()

        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(model.generating == false)
        #expect(model.chats[chatId]?.messages.last?.text == "hello there")
        #expect(model.chats[chatId]?.messages.last?.role == .assistant)
    }

    @Test func firstUserMessageSetsChatTitle() async {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.newChat()
        let chatId = model.currentChatId!

        model.draft = "What's the weather like today?"
        model.sendMessage()

        #expect(model.chats[chatId]?.title == "What's the weather like today?")
    }

    @Test func regenerateRemovesMessageAndProducesNewReply() async {
        let model = AppModel(backendClient: FakeChatBackendClient(reply: "second reply"))
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
        let model = AppModel(backendClient: FakeChatBackendClient())
        let groups = model.historyGroups
        let days = groups.map(\.day)
        #expect(days == days.sorted { a, b in
            let order: [ChatDay: Int] = [.today: 0, .yesterday: 1, .previous7: 2]
            return order[a]! < order[b]!
        })
    }

    @Test func copyMessageSetsCopiedId() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.copyMessage(id: "m1", text: "some text")
        #expect(model.copiedId == "m1")
    }
}

@MainActor
@Suite struct AppModelNavigationTests {
    @Test func modelPickerRoundTripsBackToItsOrigin() {
        for origin: Screen in [.settings, .onboarding, .chat] {
            let model = AppModel(backendClient: FakeChatBackendClient())
            model.openModelPicker(from: origin)
            #expect(model.screen == .modelPicker)
            model.closeModelPicker()
            #expect(model.screen == origin)
        }
    }

    @Test func goHistorySettingsChatUpdateScreen() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.goHistory()
        #expect(model.screen == .history)
        model.goSettings()
        #expect(model.screen == .settings)
        model.goChat()
        #expect(model.screen == .chat)
    }

    @Test func openAndCloseLegalTogglesLegalOpenKey() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.openLegal(.privacy)
        #expect(model.legalOpenKey == .privacy)
        model.closeLegal()
        #expect(model.legalOpenKey == nil)
    }
}

@MainActor
@Suite struct AppModelSettingsTests {
    @Test func selectBackendResetsModelToFirstOfNewBackend() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.selectBackend(.lmstudio)
        #expect(model.backend == .lmstudio)
        #expect(model.model == Backend.lmstudio.models[0])
    }

    @Test func selectModelUpdatesModel() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        let target = Backend.ollama.models.last!
        model.selectModel(target)
        #expect(model.model == target)
    }

    @Test func setAppearanceAndLanguageUpdateState() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.setAppearance(.dark)
        #expect(model.appearance == .dark)
        model.setLanguage(.ko)
        #expect(model.language == .ko)
    }
}

@MainActor
@Suite struct AppModelOnboardingTests {
    @Test func onboardingBackClampsAtZero() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.onboardingBack()
        #expect(model.onboardingStep == 0)
    }

    @Test func onboardingNextIncrementsStep() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        model.onboardingNext()
        model.onboardingNext()
        #expect(model.onboardingStep == 2)
    }

    @Test func finishOnboardingGoesToChatAndCreatesAChat() {
        let model = AppModel(backendClient: FakeChatBackendClient())
        let chatCountBefore = model.chats.count
        model.finishOnboarding()
        #expect(model.screen == .chat)
        #expect(model.chats.count == chatCountBefore + 1)
        #expect(model.currentChatId != nil)
    }
}
