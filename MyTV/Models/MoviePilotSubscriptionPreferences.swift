import Foundation

enum MoviePilotSubscriptionPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case unrestricted
    case fullHD
    case ultraHD
    case ultraHDHDR
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unrestricted: return "不限"
        case .fullHD: return "1080p"
        case .ultraHD: return "4K"
        case .ultraHDHDR: return "4K HDR"
        case .custom: return "自定义"
        }
    }

    var description: String {
        switch self {
        case .unrestricted: return "使用 MoviePilot 默认规则，不附加筛选条件"
        case .fullHD: return "仅匹配 1080p 或 1080i 资源"
        case .ultraHD: return "仅匹配 2160p、4K 或 UHD 资源"
        case .ultraHDHDR: return "匹配 4K，并要求 HDR 或 Dolby Vision"
        case .custom: return "使用自定义质量、分辨率、特效、站点和规则组"
        }
    }
}

struct MoviePilotSubscriptionPreferences: Codable, Equatable, Sendable {
    var preset: MoviePilotSubscriptionPreset = .unrestricted
    var customQuality = ""
    var customResolution = ""
    var customEffect = ""
    var siteIDs: Set<Int> = []
    var filterGroupNames: Set<String> = []

    static let `default` = MoviePilotSubscriptionPreferences()

    var resolvedQuality: String? {
        guard preset == .custom else { return nil }
        return customQuality.nonEmpty
    }

    var resolvedResolution: String? {
        switch preset {
        case .unrestricted:
            return nil
        case .fullHD:
            return "1080p|1080i"
        case .ultraHD, .ultraHDHDR:
            return "2160p|4K|UHD"
        case .custom:
            return customResolution.nonEmpty
        }
    }

    var resolvedEffect: String? {
        switch preset {
        case .ultraHDHDR:
            return "HDR|HDR10|HDR10\\+|DV|Dolby Vision"
        case .custom:
            return customEffect.nonEmpty
        default:
            return nil
        }
    }

    var resolvedSiteIDs: [Int]? {
        guard preset == .custom, !siteIDs.isEmpty else { return nil }
        return siteIDs.sorted()
    }

    var resolvedFilterGroupNames: [String]? {
        guard preset == .custom, !filterGroupNames.isEmpty else { return nil }
        return filterGroupNames.sorted()
    }
}

struct MoviePilotConfiguredSite: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let isActive: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case isActive = "is_active"
    }
}

struct MoviePilotRuleGroupResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
    let count: Int?
    let ruleGroups: [MoviePilotRuleGroup]

    private enum CodingKeys: String, CodingKey {
        case success, message, count
        case ruleGroups = "rule_groups"
    }
}

struct MoviePilotRuleGroup: Decodable, Identifiable, Sendable {
    let name: String
    let description: String?
    let ruleString: String?

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name, description
        case ruleString = "rule_string"
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
