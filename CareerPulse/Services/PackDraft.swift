import Foundation

/// An editable, not-yet-installed pack (the wizard's working copy). Edits
/// propagate through prerequisites and stages so the draft always stays
/// installable (the validator would reject dangling references).
struct PackDraft {
    var file: PackFile
    var origin: String            // "builtin" | "imported" | "generated"

    mutating func removeConcept(named name: String) {
        file.concepts.removeAll { $0.name == name }
        for index in file.concepts.indices {
            file.concepts[index].prerequisites.removeAll { $0 == name }
        }
        for index in file.stages.indices {
            file.stages[index].concepts.removeAll { $0 == name }
        }
    }

    mutating func renameConcept(_ oldName: String, to rawNewName: String) {
        let newName = rawNewName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != oldName,
              !file.concepts.contains(where: { $0.name == newName }) else { return }
        for index in file.concepts.indices {
            if file.concepts[index].name == oldName {
                file.concepts[index].name = newName
            }
            file.concepts[index].prerequisites = file.concepts[index].prerequisites
                .map { $0 == oldName ? newName : $0 }
        }
        for index in file.stages.indices {
            file.stages[index].concepts = file.stages[index].concepts
                .map { $0 == oldName ? newName : $0 }
        }
    }

    var conceptsByCluster: [(cluster: String, concepts: [PackFile.PackConcept])] {
        let grouped = Dictionary(grouping: file.concepts, by: \.cluster)
        return file.clusterOrder.compactMap { cluster in
            grouped[cluster].map { (cluster, $0) }
        }
    }
}

/// Validates a user-pasted URL as a feed — directly, or by discovering the
/// site's advertised RSS/Atom link.
enum FeedDiscovery {
    static func probe(_ rawInput: String) async -> PackFile.PackSource? {
        var input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.lowercased().hasPrefix("http") { input = "https://" + input }
        guard let url = URL(string: input), url.scheme == "https" || url.scheme == "http" else { return nil }

        guard let data = await fetch(url) else { return nil }
        if !RSSParser.parse(data).isEmpty {
            return source(for: url)
        }
        // Not a feed — look for <link rel="alternate" type="application/rss+xml" href="…">
        guard let html = String(data: data, encoding: .utf8),
              let tagRange = html.range(
                of: #"<link[^>]+type=["']application/(rss|atom)\+xml["'][^>]*>"#,
                options: [.regularExpression, .caseInsensitive])
        else { return nil }
        let tag = String(html[tagRange])
        guard let hrefRange = tag.range(of: #"href=["'][^"']+["']"#,
                                        options: [.regularExpression, .caseInsensitive])
        else { return nil }
        let href = String(tag[hrefRange])
            .dropFirst(6)                                         // href="
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard let feedURL = URL(string: href, relativeTo: url)?.absoluteURL,
              let feedData = await fetch(feedURL),
              !RSSParser.parse(feedData).isEmpty else { return nil }
        return source(for: feedURL)
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (iPhone) CareerPulse/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              data.count < 5_000_000 else { return nil }
        return data
    }

    private static func source(for url: URL) -> PackFile.PackSource {
        let host = (url.host() ?? "feed").replacingOccurrences(of: "www.", with: "")
        return .init(name: host, url: url.absoluteString, category: "My sources")
    }
}
