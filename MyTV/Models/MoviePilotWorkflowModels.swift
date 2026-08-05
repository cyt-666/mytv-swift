import Foundation

struct MoviePilotWorkflow: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let description: String?
    let triggerType: String?
    let state: String?
    let runCount: Int?
    let timer: String?
    let eventType: String?
    let addTime: String?
    let lastTime: String?
    let currentAction: String?

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed! : "工作流 #\(id)"
    }

    var displayTriggerType: String {
        let value = triggerType?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return "定时触发" }
        switch value.lowercased() {
        case "timer": return "定时触发"
        case "event": return "事件触发"
        case "manual": return "手动触发"
        default: return value
        }
    }

    var displayState: String {
        let value = state?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return "未知" }
        switch value.uppercased() {
        case "W": return "等待"
        case "R": return "运行中"
        case "P": return "暂停"
        case "S": return "成功"
        case "F": return "失败"
        default: return value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id)
        name = container.decodeFlexibleStringIfPresent(forKey: .name)
        description = container.decodeFlexibleStringIfPresent(forKey: .description)
        triggerType = container.decodeFlexibleStringIfPresent(forKey: .triggerType)
        state = container.decodeFlexibleStringIfPresent(forKey: .state)
        runCount = container.decodeFlexibleIntIfPresent(forKey: .runCount)
        timer = container.decodeFlexibleStringIfPresent(forKey: .timer)
        eventType = container.decodeFlexibleStringIfPresent(forKey: .eventType)
        addTime = container.decodeFlexibleStringIfPresent(forKey: .addTime)
        lastTime = container.decodeFlexibleStringIfPresent(forKey: .lastTime)
        currentAction = container.decodeFlexibleStringIfPresent(forKey: .currentAction)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, state, timer
        case triggerType = "trigger_type"
        case runCount = "run_count"
        case eventType = "event_type"
        case addTime = "add_time"
        case lastTime = "last_time"
        case currentAction = "current_action"
    }
}

enum MoviePilotWorkflowStateFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case waiting = "W"
    case running = "R"
    case paused = "P"
    case succeeded = "S"
    case failed = "F"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "全部状态"
        case .waiting: return "等待"
        case .running: return "运行中"
        case .paused: return "暂停"
        case .succeeded: return "成功"
        case .failed: return "失败"
        }
    }
}

enum MoviePilotWorkflowTriggerFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case timer
    case event
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "全部触发方式"
        case .timer: return "定时触发"
        case .event: return "事件触发"
        case .manual: return "手动触发"
        }
    }
}

enum MoviePilotWorkflowResultParser {
    static func successMessage(from text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MoviePilotError.toolFailed("MoviePilot 未返回工作流执行结果")
        }
        guard trimmed.contains("工作流执行成功") else {
            throw MoviePilotError.toolFailed(trimmed)
        }
        return trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key),
           let number = Int(value) {
            return number
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected an integer or numeric string"
        )
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key),
           let number = Int(value) {
            return number
        }
        return nil
    }

    func decodeFlexibleStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
