import Foundation

extension AppModel {
    func selectBackend(_ b: Backend) {
        backend = b
        model = b.models[0]
    }
    func selectModel(_ m: String) { model = m }
    func setAppearance(_ a: AppearanceMode) { appearance = a }
    func setLanguage(_ l: AppLanguage) { language = l }
}
