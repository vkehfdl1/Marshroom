//
//  PendingSubStatus.swift
//  Marshroom
//
//  Created by Claude on 2026-02-13.
//

import SwiftUI

/// Sub-status categories for pending PRs, computed from live GitHub data
enum PendingSubStatus: String, CaseIterable {
    case justCreated = "PR Just Created"
    case aiReviewCompleted = "AI Review Completed"
    case reviewerAssigned = "Reviewer Assigned"
    case changesRequested = "Changes Requested"

    /// Display order priority (1 = highest priority, 4 = lowest)
    var order: Int {
        switch self {
        case .changesRequested: return 1
        case .reviewerAssigned: return 2
        case .aiReviewCompleted: return 3
        case .justCreated: return 4
        }
    }

    /// Color progression: orange → darker orange → even darker → red
    var color: Color {
        switch self {
        case .justCreated: return Color.orange
        case .aiReviewCompleted: return Color.orange.opacity(0.8)
        case .reviewerAssigned: return Color.orange.opacity(0.6)
        case .changesRequested: return Color.red
        }
    }

    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .justCreated: return "envelope.badge"
        case .aiReviewCompleted: return "bubble.left.and.bubble.right"
        case .reviewerAssigned: return "person.badge.clock"
        case .changesRequested: return "exclamationmark.triangle"
        }
    }
}
