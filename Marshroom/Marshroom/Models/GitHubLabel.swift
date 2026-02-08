import Foundation

struct GitHubLabel: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String
    let description: String?
}
