import SwiftUI

enum IssueStatus: String, Codable, CaseIterable {
    case soon
    case running
    case pending
    case completed

    var displayName: String {
        switch self {
        case .soon: return "Soon"
        case .running: return "Running"
        case .pending: return "Pending"
        case .completed: return "Completed"
        }
    }

    var iconName: String {
        switch self {
        case .soon: return "clock"
        case .running: return "play.circle.fill"
        case .pending: return "arrow.triangle.pull"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .soon: return .gray
        case .running: return .blue
        case .pending: return .orange
        case .completed: return .green
        }
    }
}
