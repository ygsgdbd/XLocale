import Foundation

enum LocaleUtils {
    /// 将地区代码转换为对应的国旗 emoji
    /// 例如: "zh-Hans" -> "🇨🇳", "en" -> "🇺🇸"
    static func flagEmoji(for localeCode: String) -> String {
        // 处理特殊情况
        switch localeCode.lowercased() {
        // 中文
        case "zh-hans", "zh_cn", "zh-cn", "zh_hans", "zho": return "🇨🇳"
        case "zh-hant", "zh_tw", "zh-tw", "zh_hk", "zh-hk", "zh_hant": return "🇹🇼"
        
        // 英语变体
        case "en", "eng", "en_us": return "🇺🇸"
        case "en_gb", "en-gb": return "🇬🇧"
        case "en_au", "en-au": return "🇦🇺"
        case "en_ca", "en-ca": return "🇨🇦"
        case "en_nz", "en-nz": return "🇳🇿"
        case "en_ie", "en-ie": return "🇮🇪"
        
        // 欧洲语言
        case "fr", "fra", "fr_fr", "fr-fr": return "🇫🇷"
        case "de", "deu", "de_de", "de-de": return "🇩🇪"
        case "it", "ita", "it_it", "it-it": return "🇮🇹"
        case "es", "spa", "es_es", "es-es": return "🇪🇸"
        case "pt", "por", "pt_pt", "pt-pt": return "🇵🇹"
        case "pt_br", "pt-br": return "🇧🇷"
        case "ru", "rus", "ru_ru", "ru-ru": return "🇷🇺"
        case "nl", "nld", "nl_nl", "nl-nl": return "🇳🇱"
        case "sv", "swe", "sv_se", "sv-se": return "🇸🇪"
        case "da", "dan", "da_dk", "da-dk": return "🇩🇰"
        case "fi", "fin", "fi_fi", "fi-fi": return "🇫🇮"
        case "no", "nor", "nb_no", "nb-no": return "🇳🇴"
        case "pl", "pol", "pl_pl", "pl-pl": return "🇵🇱"
        
        // 亚洲语言
        case "ja", "jpn", "ja_jp", "ja-jp": return "🇯🇵"
        case "ko", "kor", "ko_kr", "ko-kr": return "🇰🇷"
        case "th", "tha", "th_th", "th-th": return "🇹🇭"
        case "vi", "vie", "vi_vn", "vi-vn": return "🇻🇳"
        case "id", "ind", "id_id", "id-id": return "🇮🇩"
        case "ms", "msa", "ms_my", "ms-my": return "🇲🇾"
        case "hi", "hin", "hi_in", "hi-in": return "🇮🇳"
        
        // 其他地区语言
        case "ar", "ara", "ar_sa", "ar-sa": return "🇸🇦"
        case "he", "heb", "he_il", "he-il": return "🇮🇱"
        case "tr", "tur", "tr_tr", "tr-tr": return "🇹🇷"
        case "el", "ell", "el_gr", "el-gr": return "🇬🇷"
        case "cs", "ces", "cs_cz", "cs-cz": return "🇨🇿"
        case "hu", "hun", "hu_hu", "hu-hu": return "🇭🇺"
        case "ro", "ron", "ro_ro", "ro-ro": return "🇷🇴"
        case "sk", "slk", "sk_sk", "sk-sk": return "🇸🇰"
        case "uk", "ukr", "uk_ua", "uk-ua": return "🇺🇦"
        case "hr", "hrv", "hr_hr", "hr-hr": return "🇭🇷"
        case "ca", "cat", "ca_es", "ca-es": return "🇦🇩"
        case "eu", "eus", "eu_es", "eu-es": return "🇪🇺"
        case "gl", "glg", "gl_es", "gl-es": return "🇪🇸"
        
        default: break
        }
        
        // 尝试从 Locale 获取
        let locale = Locale(identifier: localeCode)
        if let regionCode = locale.region?.identifier {
            return regionCode
                .unicodeScalars
                .map { String(UnicodeScalar(127397 + $0.value)!) }
                .joined()
        }
        
        // 如果是两字母代码，直接转换为国旗
        if localeCode.count == 2 {
            return localeCode
                .uppercased()
                .unicodeScalars
                .map { String(UnicodeScalar(127397 + $0.value)!) }
                .joined()
        }
        
        // 无法识别的语言代码返回问号
        return "🌐"  // 改用地球图标代替问号
    }
    
    /// 获取语言的本地化名称
    /// 例如: "zh-Hans" -> "简体中文"
    static func localizedName(for localeCode: String) -> String {
        // 处理特殊情况
        switch localeCode.lowercased() {
        // 中文
        case "zh-hans", "zh_cn", "zh-cn", "zh_hans", "zho": return "简体中文"
        case "zh-hant", "zh_tw", "zh-tw", "zh_hk", "zh-hk", "zh_hant": return "繁體中文"
        
        // 东亚语言
        case "ja", "jpn", "ja_jp", "ja-jp": return "日本語"
        case "ko", "kor", "ko_kr", "ko-kr": return "한국어"
        
        // 欧洲语言
        case "en", "eng", "en_us": return "English (US)"
        case "en_gb", "en-gb": return "English (UK)"
        case "fr", "fra", "fr_fr", "fr-fr": return "Français"
        case "de", "deu", "de_de", "de-de": return "Deutsch"
        case "it", "ita", "it_it", "it-it": return "Italiano"
        case "es", "spa", "es_es", "es-es": return "Español"
        case "pt", "por", "pt_pt", "pt-pt": return "Português"
        case "pt_br", "pt-br": return "Português (Brasil)"
        case "ru", "rus", "ru_ru", "ru-ru": return "Русский"
        
        default: break
        }
        
        // 尝试从 Locale 获取本地化名称
        let locale = Locale(identifier: localeCode)
        if let languageName = locale.localizedString(forIdentifier: localeCode) {
            return languageName
        }
        
        // 如果无法获取本地化名称，返回原始代码
        return localeCode
    }
    
    /// 获取完整的语言显示信息（包含国旗和名称）
    /// 例如: "zh-Hans" -> "🇨🇳 简体中文"
    static func fullDisplayName(for localeCode: String) -> String {
        "\(flagEmoji(for: localeCode)) \(localizedName(for: localeCode))"
    }
} 