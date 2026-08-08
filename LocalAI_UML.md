# LocalAI UML 클래스 다이어그램

전체 소스는 `App → Model → Theme → Views` 순으로 좌에서 우로 의존한다: 진입점이 `AppModel` 하나를 만들고, 모든 화면(View)이 그 `AppModel`을 관찰(`@ObservedObject`)해서 상태를 읽고 액션을 호출한다. 실제 네트워크 계층은 없고 `CannedReplies`가 응답을 흉내 낸다.

```mermaid
classDiagram
    direction LR

    %% ---------- App entry ----------
    class LocalAIApp {
        <<App>>
        -model: AppModel
    }
    class RootView {
        <<View>>
        +model: AppModel
        +body: some View
    }

    %% ---------- Model ----------
    class AppModel {
        <<ObservableObject>>
        +screen: Screen
        +backend: Backend
        +model: String
        +appearance: AppearanceMode
        +language: AppLanguage
        +chats: [String: Chat]
        +currentChatId: String?
        +draft: String
        +generating: Bool
        +sendMessage()
        +regenerate(chatId, messageId)
        +newChat()
        +selectBackend(_)
        +openLegal(_)
    }
    class Screen {
        <<enum>>
        onboarding
        chat
        history
        settings
        modelPicker
    }
    class AppearanceMode {
        <<enum>>
        light
        dark
        system
    }

    class Chat {
        <<struct>>
        +id: String
        +day: ChatDay
        +title: String
        +messages: [ChatMessage]
    }
    class ChatMessage {
        <<struct>>
        +id: String
        +role: MessageRole
        +text: String
        +model: String?
    }
    class ChatDay {
        <<enum>>
        today
        yesterday
        previous7
    }
    class MessageRole {
        <<enum>>
        user
        assistant
    }
    class MessageBlock {
        <<enum>>
        code(text)
        text(parts)
    }
    class InlinePart {
        <<struct>>
        +bold: Bool
        +text: String
    }
    class MessageParsing {
        <<enum/static>>
        +blocks(from: String) [MessageBlock]
        +inlineParts(from: String) [InlinePart]
    }
    class CannedReplies { <<enum/static>> +random() String }
    class SeedChats { <<enum/static>> +make() [Chat] }

    class Backend {
        <<enum>>
        ollama
        lmstudio
        +models: [String]
        +description(language) String
    }

    class AppLanguage {
        <<enum>>
        en
        ko
        +strings: Strings
        +legal: LegalStrings
    }
    class Strings {
        <<struct>>
        +greeting() String
    }
    class LegalKey {
        <<enum>>
        privacy
        terms
        safety
        security
    }
    class LegalEntry {
        <<struct>>
        +title: String
        +body: String
    }
    class LegalStrings {
        <<struct>>
        +entry(key) LegalEntry
    }

    class Theme {
        <<struct>>
        +resolve(dark: Bool) Theme
    }
    class Palette {
        <<enum>>
        bg
        surface
        accent
        accent2
    }
    class AppFont {
        <<static>>
        +heading() Font
        +body() Font
    }

    %% ---------- Views: Onboarding ----------
    class OnboardingView { <<View>> +model: AppModel }
    class WelcomeStepView { <<View>> +model: AppModel }
    class BackendStepView { <<View>> +model: AppModel }
    class ModelStepView { <<View>> +model: AppModel }
    class ModelRow { <<View>> }

    %% ---------- Views: Chat ----------
    class ChatView { <<View>> +model: AppModel }
    class InputBarView { <<View>> +model: AppModel }
    class MessageBubbleView { <<View>> +model: AppModel }
    class TypingIndicatorView { <<View>> +model: AppModel }

    %% ---------- Views: History ----------
    class HistoryView { <<View>> +model: AppModel }
    class SubHeader { <<View>> }

    %% ---------- Views: Settings ----------
    class SettingsView { <<View>> +model: AppModel }
    class SectionLabel { <<View>> }
    class GroupCard { <<View>> }
    class GroupRow { <<View>> }
    class LegalSheetView { <<View>> +model: AppModel }

    %% ---------- Views: ModelPicker ----------
    class ModelPickerView { <<View>> +model: AppModel }

    %% ---------- Views: Components (shared) ----------
    class SegmentedPillControl~Item~ {
        <<View, generic>>
    }
    class IconButtonView { <<View>> }

    %% ===== relations =====
    LocalAIApp --> AppModel : creates (@StateObject)
    LocalAIApp --> RootView : hosts
    RootView --> AppModel : observes
    RootView --> OnboardingView : switch .onboarding
    RootView --> ChatView : switch .chat
    RootView --> HistoryView : switch .history
    RootView --> SettingsView : switch .settings
    RootView --> ModelPickerView : switch .modelPicker

    AppModel --> Screen : screen
    AppModel --> AppearanceMode : appearance
    AppModel --> Backend : backend
    AppModel --> AppLanguage : language
    AppModel "1" *-- "many" Chat : chats
    AppModel --> LegalKey : legalOpenKey
    AppModel ..> SeedChats : init() uses
    AppModel ..> CannedReplies : finishReply() uses

    Chat "1" *-- "many" ChatMessage : messages
    Chat --> ChatDay : day
    ChatMessage --> MessageRole : role
    MessageParsing --> MessageBlock : produces
    MessageBlock --> InlinePart : text case holds
    SeedChats ..> Chat : builds

    Backend --> AppLanguage : description(language)
    AppLanguage --> Strings : strings
    AppLanguage --> LegalStrings : legal
    LegalStrings --> LegalEntry : entry(for key)
    LegalStrings --> LegalKey : keyed by

    Theme ..> Palette : resolve() reads

    OnboardingView --> AppModel : reads/calls
    OnboardingView --> WelcomeStepView : step 0
    OnboardingView --> BackendStepView : step 1
    OnboardingView --> ModelStepView : step 2
    ModelStepView --> ModelRow : row per model

    ChatView --> AppModel : reads/calls
    ChatView --> InputBarView : composer
    ChatView --> MessageBubbleView : row per message
    ChatView --> TypingIndicatorView : while generating
    MessageBubbleView ..> MessageParsing : renders blocks

    HistoryView --> AppModel : reads/calls
    HistoryView --> SubHeader : section header

    SettingsView --> AppModel : reads/calls
    SettingsView --> SectionLabel : section header
    SettingsView --> GroupCard : grouped row card
    GroupCard --> GroupRow : row
    SettingsView --> LegalSheetView : opens sheet
    LegalSheetView --> LegalKey : legalOpenKey

    ModelPickerView --> AppModel : reads/calls

    BackendStepView --> SegmentedPillControl : platform toggle
    SettingsView --> SegmentedPillControl : appearance/language toggle
    ChatView --> IconButtonView : header icons
    HistoryView --> IconButtonView : header icons
    ModelPickerView --> IconButtonView : done button
```

## 요약

- **App / Root**: `LocalAIApp`이 `AppModel` 하나를 만들고, `RootView`가 `AppModel.screen` 값에 따라 5개 화면 중 하나를 스위칭.
- **Model**: `AppModel`이 유일한 `ObservableObject`로 모든 화면의 상태·액션을 소유. `Chat`/`ChatMessage`는 대화 데이터, `Backend`/`AppLanguage`는 설정값, `MessageParsing`은 마크다운 라이트 렌더러.
- **Theme**: `Palette`(원색 토큰) → `Theme`(다크/라이트 해석) → View들이 소비.
- **Views**: 화면별 폴더(Onboarding/Chat/History/Settings/ModelPicker)가 각각 `AppModel`을 관찰하며, `Components`(SegmentedPillControl, IconButtonView)는 여러 화면에서 공유.

---

# 폴더별 상세 다이어그램

각 `Views/` 하위 폴더 내부에서 타입들이 어떻게 조립되는지 좌→우로 펼친 상세 다이어그램. 모든 하위 View는 부모로부터 `theme: Theme`를 값으로 전달받고, `AppModel`은 `@ObservedObject`로 직접 관찰한다 (전달이 아니라 참조 공유).

## Onboarding/

`OnboardingView`가 `onboardingStep`(0~2)에 따라 세 스텝 뷰 중 하나를 보여주고, 하단 진행 도트 + 기본 버튼(다음/시작하기)을 공통으로 그린다.

```mermaid
classDiagram
    direction LR

    class AppModel {
        <<ObservableObject>>
        onboardingStep: Int
        backend: Backend
        model: String
        +onboardingNext()
        +onboardingBack()
        +selectBackend()
        +selectModel()
        +finishOnboarding()
    }

    class OnboardingView {
        <<View>>
        +model: AppModel
        +theme: Theme
        -primaryLabel: String
        -primaryAction()
    }
    class WelcomeStepView {
        <<View>>
        +model: AppModel
        +theme: Theme
    }
    class BackendStepView {
        <<View>>
        +model: AppModel
        +theme: Theme
    }
    class BackendCard {
        <<View, private>>
        +backend: Backend
        +model: AppModel
        +theme: Theme
        -selected: Bool
    }
    class ModelStepView {
        <<View>>
        +model: AppModel
        +theme: Theme
    }
    class ModelRow {
        <<View>>
        +name: String
        +selected: Bool
        +action: () -> Void
    }
    class SegmentedPillControl~Item~ {
        <<View, generic>>
    }
    class IconButtonView {
        <<View>>
    }
    class Backend {
        <<enum>>
        ollama
        lmstudio
    }

    OnboardingView --> AppModel : observes (step/nav)
    OnboardingView --> IconButtonView : back chevron (step > 0)
    OnboardingView --> WelcomeStepView : step == 0
    OnboardingView --> BackendStepView : step == 1
    OnboardingView --> ModelStepView : step == 2 (default)

    BackendStepView --> AppModel : observes
    BackendStepView "1" *-- "many" BackendCard : one per Backend.allCases
    BackendCard --> AppModel : selectBackend(_)
    BackendCard --> Backend : backend

    ModelStepView --> AppModel : observes
    ModelStepView --> SegmentedPillControl : backend switch
    ModelStepView "1" *-- "many" ModelRow : one per backend.models
    SegmentedPillControl --> AppModel : onSelect → selectBackend
    ModelRow --> AppModel : tap → selectModel
```

## Chat/

`ChatView`가 헤더(히스토리/설정 진입 + 모델 배지) · 메시지 스크롤 · 입력창을 세로로 쌓는다. 메시지 배지는 `MessageBubbleView`가 `MessageParsing`으로 코드/볼드 블록을 파싱해 그린다.

```mermaid
classDiagram
    direction LR

    class AppModel {
        <<ObservableObject>>
        currentChat: Chat?
        draft: String
        generating: Bool
        tick: Int
        copiedId: String?
        +sendMessage()
        +regenerate()
        +copyMessage()
        +goHistory()
        +goSettings()
        +openModelPicker()
    }

    class ChatView {
        <<View>>
        +model: AppModel
        +theme: Theme
        -scrollToBottom(proxy)
    }
    class InputBarView {
        <<View>>
        +model: AppModel
        +theme: Theme
        -canSend: Bool
    }
    class MessageBubbleView {
        <<View>>
        +model: AppModel
        +message: ChatMessage
        +theme: Theme
        -isUser: Bool
        -inlineText(parts)
    }
    class TypingIndicatorView {
        <<View>>
        +model: AppModel
        +theme: Theme
    }
    class IconButtonView {
        <<View>>
    }
    class ChatMessage {
        <<struct, Model>>
        id
        role
        text
        model
    }
    class MessageParsing {
        <<static, Model>>
        +blocks(from:) [MessageBlock]
    }
    class MessageBlock {
        <<enum, Model>>
        code(text)
        text(parts)
    }

    ChatView --> AppModel : observes (currentChat/generating)
    ChatView --> IconButtonView : history / settings icons
    ChatView "1" *-- "many" MessageBubbleView : one per chat.messages
    ChatView --> TypingIndicatorView : while generating
    ChatView --> InputBarView : composer footer

    InputBarView --> AppModel : draft binding, sendMessage()
    MessageBubbleView --> AppModel : copyMessage() / regenerate()
    MessageBubbleView --> ChatMessage : message
    MessageBubbleView ..> MessageParsing : blocks(from message.text)
    MessageParsing --> MessageBlock : produces
    TypingIndicatorView --> AppModel : reads tick (500ms 애니메이션)
```

## History/

`HistoryView`는 공용 `SubHeader`를 얹고, `AppModel.historyGroups`(오늘/어제/지난 7일)를 순회하며 채팅 카드 목록을 그린다.

```mermaid
classDiagram
    direction LR

    class AppModel {
        <<ObservableObject>>
        historyGroups: [Group]
        +newChat()
        +goChat()
        +openChat(id)
    }

    class HistoryView {
        <<View>>
        +model: AppModel
        +theme: Theme
    }
    class SubHeader {
        <<View, shared>>
        title
        theme
        onBack
        trailing
    }
    class IconButtonView {
        <<View>>
    }
    class Chat {
        <<struct, Model>>
        id
        day
        title
        snippet
        messages
    }
    class ChatDay {
        <<enum, Model>>
        today
        yesterday
        previous7
    }

    HistoryView --> AppModel : observes historyGroups
    HistoryView --> SubHeader : header (+ "새 채팅" 버튼)
    SubHeader --> IconButtonView : back / trailing 아이콘
    HistoryView "1" *-- "many" Chat : renders group.chats
    Chat --> ChatDay : day
    HistoryView ..> AppModel : row tap → openChat(chat.id)
```

## Settings/

`SettingsView`가 섹션(Model/Appearance/Language/About)마다 `SectionLabel` + `GroupCard`(내부에 `GroupRow` 또는 `SegmentedPillControl`)를 쌓고, About의 각 행이 `LegalSheetView`를 시트로 띄운다.

```mermaid
classDiagram
    direction LR

    class AppModel {
        <<ObservableObject>>
        backend
        appearance
        language
        legalOpenKey
        +selectBackend()
        +setAppearance()
        +setLanguage()
        +openLegal()
        +closeLegal()
    }

    class SettingsView {
        <<View>>
        +model: AppModel
        +theme: Theme
        -legalLabel(key)
    }
    class SectionLabel {
        <<View>>
        +text
        +theme
    }
    class GroupCard~Content~ {
        <<View, generic>>
        +theme
        +content
    }
    class GroupRow~Content~ {
        <<View, generic>>
        +theme
        +isFirst
        +action
        +content
    }
    class SegmentedPillControl~Item~ {
        <<View, generic, shared>>
    }
    class LegalSheetView {
        <<View>>
        +model: AppModel
        +key: LegalKey
        +theme: Theme
        -entry: LegalEntry
    }
    class AppearanceItem {
        <<struct, private>>
        mode: AppearanceMode
    }
    class LegalKey {
        <<enum, Model>>
        privacy
        terms
        safety
        security
    }

    SettingsView --> AppModel : observes
    SettingsView "1" *-- "4" SectionLabel : Model/Appearance/Language/About
    SettingsView "1" *-- "4" GroupCard : one per section
    GroupCard "1" o-- "0..*" GroupRow : model row, legal rows
    GroupCard --> SegmentedPillControl : backend / appearance / language 스위치
    SegmentedPillControl --> AppearanceItem : appearance 섹션에서 사용
    GroupRow --> AppModel : tap → openModelPicker() / openLegal(key)
    SettingsView --> LegalSheetView : .sheet(item legalOpenKey)
    LegalSheetView --> LegalKey : key
    LegalSheetView --> AppModel : closeLegal()
```

## ModelPicker/

`ModelPickerView`는 `SubHeader` + 백엔드 스위치(`SegmentedPillControl`) + 모델 목록(`ModelRow`, Onboarding과 타입 공유) + 완료 버튼으로 구성된 단일 파일 화면.

```mermaid
classDiagram
    direction LR

    class AppModel {
        <<ObservableObject>>
        backend
        model
        language
        +selectBackend()
        +selectModel()
        +closeModelPicker()
    }

    class ModelPickerView {
        <<View>>
        +model: AppModel
        +theme: Theme
    }
    class SubHeader {
        <<View, shared>>
    }
    class SegmentedPillControl~Item~ {
        <<View, generic, shared>>
    }
    class ModelRow {
        <<View, shared with Onboarding>>
        name
        selected
        action
    }
    class Backend {
        <<enum, Model>>
        +models: [String]
        +description(language)
    }

    ModelPickerView --> AppModel : observes
    ModelPickerView --> SubHeader : header (닫기 = closeModelPicker)
    ModelPickerView --> SegmentedPillControl : backend 전환
    ModelPickerView "1" *-- "many" ModelRow : one per backend.models
    SegmentedPillControl --> AppModel : onSelect → selectBackend
    ModelRow --> AppModel : tap → selectModel
    ModelPickerView --> Backend : backend.description(language)
```

## Components/ (교차 화면 공유)

두 파일 모두 상태를 갖지 않는 순수 표현 View. `theme`와 콜백만 받아 여러 화면에서 재사용된다.

```mermaid
classDiagram
    direction LR

    class SegmentedPillControl~Item~ {
        <<View, generic>>
        +items: [Item]
        +label: (Item) -> String
        +isSelected: (Item) -> Bool
        +onSelect: (Item) -> Void
        +theme: Theme
    }
    class IconButtonView {
        <<View>>
        +systemName: String
        +theme: Theme
        +action: () -> Void
    }

    class BackendStepView { <<uses, Onboarding/>> }
    class ModelStepView { <<uses, Onboarding/>> }
    class SettingsView { <<uses, Settings/>> }
    class ModelPickerView { <<uses, ModelPicker/>> }
    class OnboardingView { <<uses, Onboarding/>> }
    class ChatView { <<uses, Chat/>> }
    class HistoryView { <<uses, History/ via SubHeader>> }

    ModelStepView --> SegmentedPillControl : backend 선택
    SettingsView --> SegmentedPillControl : backend/appearance/language
    ModelPickerView --> SegmentedPillControl : backend 선택

    OnboardingView --> IconButtonView : back chevron
    ChatView --> IconButtonView : history/settings icons
    HistoryView --> IconButtonView : back/trailing (SubHeader 경유)
    ModelPickerView --> IconButtonView : back (SubHeader 경유)
```
