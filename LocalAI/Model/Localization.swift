import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case ko

    var id: String { rawValue }

    var label: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어"
        }
    }

    var strings: Strings {
        switch self {
        case .en: return .en
        case .ko: return .ko
        }
    }

    var legal: LegalStrings {
        switch self {
        case .en: return .en
        case .ko: return .ko
        }
    }
}

/// Port of the design's `TXT` table.
struct Strings {
    let appName: String
    let newChat: String
    let historyTitle: String
    let settingsTitle: String
    let today: String
    let yesterday: String
    let previous7: String
    let sectionModel: String
    let sectionAppearance: String
    let sectionLanguage: String
    let sectionAbout: String
    let light: String
    let dark: String
    let system: String
    let privacyPolicy: String
    let terms: String
    let safety: String
    let security: String
    let version: String
    let modelPickerTitle: String
    let done: String
    let welcomeTitle: String
    let welcomeBody: String
    let continueBtn: String
    let choosePlatformTitle: String
    let choosePlatformBody: String
    let chooseModelTitle: String
    let chooseModelBody: String
    let getStarted: String
    let copy: String
    let copied: String
    let regenerate: String
    let ollamaDesc: String
    let lmstudioDesc: String
    let inputPlaceholder: String

    static let en = Strings(
        appName: "Local AI", newChat: "New chat", historyTitle: "History", settingsTitle: "Settings",
        today: "Today", yesterday: "Yesterday", previous7: "Previous 7 Days",
        sectionModel: "Model", sectionAppearance: "Appearance", sectionLanguage: "Language", sectionAbout: "About",
        light: "Light", dark: "Dark", system: "System",
        privacyPolicy: "Privacy Policy", terms: "Terms of Service", safety: "Safety Information", security: "Security",
        version: "Version 1.0.0", modelPickerTitle: "Choose Model", done: "Done",
        welcomeTitle: "Local AI",
        welcomeBody: "Chat with open models running entirely on your iPhone. Nothing you type ever leaves this device.",
        continueBtn: "Continue", choosePlatformTitle: "Choose your engine",
        choosePlatformBody: "Local AI runs on top of a local model server. Pick the one you have installed.",
        chooseModelTitle: "Choose a model",
        chooseModelBody: "Pick which downloaded model to chat with. You can change this any time in Settings.",
        getStarted: "Get Started", copy: "Copy", copied: "Copied", regenerate: "Regenerate",
        ollamaDesc: "Connects to a local Ollama server (localhost:11434).",
        lmstudioDesc: "Connects to a local LM Studio server (OpenAI-compatible API).",
        inputPlaceholder: "Message Local AI…"
    )

    static let ko = Strings(
        appName: "Local AI", newChat: "새 대화", historyTitle: "기록", settingsTitle: "설정",
        today: "오늘", yesterday: "어제", previous7: "지난 7일",
        sectionModel: "모델", sectionAppearance: "화면 모드", sectionLanguage: "언어", sectionAbout: "정보",
        light: "라이트", dark: "다크", system: "시스템",
        privacyPolicy: "개인정보 처리방침", terms: "서비스 이용약관", safety: "안전 정보", security: "보안",
        version: "버전 1.0.0", modelPickerTitle: "모델 선택", done: "완료",
        welcomeTitle: "Local AI",
        welcomeBody: "아이폰에서 완전히 로컬로 실행되는 오픈 모델과 대화하세요. 입력한 내용은 기기 밖으로 전송되지 않습니다.",
        continueBtn: "계속", choosePlatformTitle: "엔진 선택",
        choosePlatformBody: "Local AI는 로컬 모델 서버 위에서 실행됩니다. 설치한 서버를 선택하세요.",
        chooseModelTitle: "모델 선택",
        chooseModelBody: "대화할 모델을 선택하세요. 설정에서 언제든지 변경할 수 있습니다.",
        getStarted: "시작하기", copy: "복사", copied: "복사됨", regenerate: "다시 생성",
        ollamaDesc: "로컬 Ollama 서버(localhost:11434)에 연결됩니다.",
        lmstudioDesc: "로컬 LM Studio 서버(OpenAI 호환 API)에 연결됩니다.",
        inputPlaceholder: "Local AI에게 메시지 보내기…"
    )

    func greeting(backendLabel: String, model: String, language: AppLanguage) -> String {
        switch language {
        case .en:
            return "Hi — I'm running locally via \(backendLabel) on \(model). Ask me anything, nothing leaves your phone."
        case .ko:
            return "안녕하세요 — 저는 \(backendLabel)을 통해 \(model) 모델로 기기에서 직접 실행되고 있어요. 무엇이든 물어보세요, 아무것도 기기 밖으로 전송되지 않습니다."
        }
    }
}

/// Port of the design's `LEGAL` table.
enum LegalKey: String, CaseIterable, Identifiable, Hashable {
    case privacy, terms, safety, security
    var id: String { rawValue }
}

struct LegalEntry {
    let title: String
    let body: String
}

struct LegalStrings {
    let privacy: LegalEntry
    let terms: LegalEntry
    let safety: LegalEntry
    let security: LegalEntry

    func entry(for key: LegalKey) -> LegalEntry {
        switch key {
        case .privacy: return privacy
        case .terms: return terms
        case .safety: return safety
        case .security: return security
        }
    }

    static let en = LegalStrings(
        privacy: LegalEntry(
            title: "Privacy Policy",
            body: "Local AI processes every conversation on your iPhone. Messages, attachments, and model outputs are never uploaded to a server we control. If you enable iCloud backup, your device's own backup settings apply."
        ),
        terms: LegalEntry(
            title: "Terms of Service",
            body: "Local AI is provided as-is. You are responsible for the models you download and the content you generate with them. Local model servers (Ollama, LM Studio) are third-party software governed by their own licenses."
        ),
        safety: LegalEntry(
            title: "Safety Information",
            body: "Local models can produce inaccurate, biased, or inappropriate output. Verify anything important before relying on it, especially medical, legal, or financial answers."
        ),
        security: LegalEntry(
            title: "Security",
            body: "Running models locally keeps your data off the network, but keep your iPhone, Ollama, and LM Studio installations up to date to reduce security risk."
        )
    )

    static let ko = LegalStrings(
        privacy: LegalEntry(
            title: "개인정보 처리방침",
            body: "Local AI는 모든 대화를 아이폰 안에서 처리합니다. 메시지, 첨부파일, 모델 응답은 저희가 관리하는 서버로 전송되지 않습니다. iCloud 백업을 사용 중이라면 기기 자체의 백업 설정이 적용됩니다."
        ),
        terms: LegalEntry(
            title: "서비스 이용약관",
            body: "Local AI는 있는 그대로 제공됩니다. 다운로드한 모델과 이를 통해 생성한 콘텐츠에 대한 책임은 사용자에게 있습니다. 로컬 모델 서버(Ollama, LM Studio)는 각자의 라이선스를 따르는 타사 소프트웨어입니다."
        ),
        safety: LegalEntry(
            title: "안전 정보",
            body: "로컬 모델은 부정확하거나 편향되거나 부적절한 결과를 생성할 수 있습니다. 특히 의료, 법률, 금융 관련 답변은 신뢰하기 전에 반드시 확인하세요."
        ),
        security: LegalEntry(
            title: "보안",
            body: "로컬에서 모델을 실행하면 데이터가 네트워크 밖에 머물지만, 보안 위험을 줄이려면 아이폰과 Ollama, LM Studio를 항상 최신 상태로 유지하세요."
        )
    )
}
