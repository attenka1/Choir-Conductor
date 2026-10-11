import Foundation

struct AppLanguage: Identifiable, Sendable {
    let id: String
    let name: String
    nonisolated static let all: [AppLanguage] = [
        AppLanguage(id: "fi", name: "Suomi"),
        AppLanguage(id: "en", name: "English"),
        AppLanguage(id: "zh-Hans", name: "中文（普通话）"),
        AppLanguage(id: "hi", name: "हिन्दी"),
        AppLanguage(id: "es", name: "Español"),
        AppLanguage(id: "ar", name: "العربية"),
        AppLanguage(id: "fr", name: "Français"),
        AppLanguage(id: "bn", name: "বাংলা"),
        AppLanguage(id: "pt", name: "Português"),
        AppLanguage(id: "id", name: "Bahasa Indonesia"),
        AppLanguage(id: "ur", name: "اردو"),
        AppLanguage(id: "ru", name: "Русский"),
        AppLanguage(id: "de", name: "Deutsch"),
        AppLanguage(id: "ja", name: "日本語"),
        AppLanguage(id: "pcm", name: "Naijá"),
        AppLanguage(id: "ar-EG", name: "العربية المصرية"),
        AppLanguage(id: "mr", name: "मराठी"),
        AppLanguage(id: "vi", name: "Tiếng Việt"),
        AppLanguage(id: "te", name: "తెలుగు"),
        AppLanguage(id: "sw", name: "Kiswahili"),
        AppLanguage(id: "ha", name: "Hausa"),
        AppLanguage(id: "tr", name: "Türkçe"),
        AppLanguage(id: "pa-Arab", name: "پنجابی"),
        AppLanguage(id: "tl", name: "Tagalog"),
        AppLanguage(id: "ta", name: "தமிழ்"),
        AppLanguage(id: "yue", name: "粵語"),
        AppLanguage(id: "wuu", name: "吴语（书面中文）"),
        AppLanguage(id: "fa", name: "فارسی"),
        AppLanguage(id: "ko", name: "한국어"),
        AppLanguage(id: "am", name: "አማርኛ"),
        AppLanguage(id: "th", name: "ไทย")
    ]
    nonisolated static func isRTL(_ code: String) -> Bool {
        ["ar", "ar-EG", "ur", "pa-Arab", "fa"].contains(code)
    }
}

/// App-specific language selection. Every translation ships inside the app bundle.
nonisolated func T(_ key: String, _ arguments: CVarArg...) -> String {
    let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? "fi"
    let code = AppLanguage.all.contains(where: { $0.id == stored }) ? stored : "fi"
    let localized = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    let english = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))
    let fallback = english?.localizedString(forKey: key, value: key, table: nil) ?? key
    let format = localized?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    return arguments.isEmpty ? format : String(format: format, locale: Locale(identifier: code), arguments: arguments)
}
