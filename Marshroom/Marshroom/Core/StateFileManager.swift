import Foundation

enum StateFileManager {
    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    private static let decoder = JSONDecoder()

    static func readState() -> MarshroomState? {
        let path = Constants.stateFilePath
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        return try? decoder.decode(MarshroomState.self, from: data)
    }

    static func writeState(_ state: MarshroomState) throws {
        let dirPath = Constants.stateFileDirectory
        let filePath = Constants.stateFilePath

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: dirPath) {
            try FileManager.default.createDirectory(
                atPath: dirPath,
                withIntermediateDirectories: true
            )
        }

        var mutable = state
        mutable.version = 3
        mutable.updatedAt = Constants.iso8601Formatter.string(from: Date())

        let data = try encoder.encode(mutable)
        let url = URL(fileURLWithPath: filePath)
        try data.write(to: url, options: .atomic)
    }

    static func buildState(
        cart: [CartItem],
        repos: [GitHubRepo],
        existingState: MarshroomState? = nil
    ) -> MarshroomState {
        var state = MarshroomState.empty()

        // Preserve repo-level cache data from existing state
        let existingRepos = existingState?.repos ?? []

        state.repos = repos.map { repo in
            let existing = existingRepos.first { $0.fullName == repo.fullName }
            return MarshroomState.RepoEntry(
                fullName: repo.fullName,
                cloneURL: repo.cloneURL,
                sshURL: repo.sshURL,
                claudeMdCache: existing?.claudeMdCache,
                claudeMdCachedAt: existing?.claudeMdCachedAt,
                localPath: existing?.localPath
            )
        }

        state.cart = cart.map { item in
            MarshroomState.CartEntry(
                repoFullName: item.repo.fullName,
                repoCloneURL: item.repo.cloneURL,
                repoSSHURL: item.repo.sshURL,
                issueNumber: item.issue.number,
                issueTitle: item.issue.title,
                branchName: item.branchName,
                status: item.status,
                issueBody: item.issue.body,
                prNumber: item.prNumber,
                prURL: item.prURL
            )
        }

        return state
    }
}
