//
//  LinkMetadataService.swift
//  jez-blog
//
//  Fetches Open Graph / Twitter card metadata for a link card.
//

import Foundation

/// What we learned about a URL.
struct LinkMetadata: Equatable {
    var title: String?
    var description: String?
    var imageURL: String?
    var siteName: String?

    var isEmpty: Bool {
        title == nil && description == nil && imageURL == nil && siteName == nil
    }
}

enum LinkMetadataError: LocalizedError {
    case invalidURL(String)
    case badResponse(Int)
    case notHTML
    case noMetadata

    var errorDescription: String? {
        switch self {
        case .invalidURL(let string):
            return "“\(string)” is not a valid web address."
        case .badResponse(let code):
            return "The site answered with status \(code)."
        case .notHTML:
            return "That address did not return a web page."
        case .noMetadata:
            return "No preview information was found on that page."
        }
    }
}

enum LinkMetadataService {

    /// Normalises user input: adds a scheme, trims whitespace.
    static func normalizedURL(from string: String) -> URL? {
        var trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }

        guard let url = URL(string: trimmed), let host = url.host(), host.contains(".") else { return nil }
        return url
    }

    /// Downloads the page and pulls out its social preview tags.
    static func fetch(_ url: URL) async throws -> LinkMetadata {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 jez-blog/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LinkMetadataError.badResponse(http.statusCode)
        }

        guard let html = decodeHTML(data) else { throw LinkMetadataError.notHTML }

        var metadata = parse(html: html, baseURL: url)
        if metadata.isEmpty { throw LinkMetadataError.noMetadata }
        if metadata.siteName == nil { metadata.siteName = url.host() }
        return metadata
    }

    // MARK: - Parsing

    /// HTML often lies about its encoding; try the usual suspects.
    private static func decodeHTML(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let latin = String(data: data, encoding: .isoLatin1) { return latin }
        return String(data: data, encoding: .ascii)
    }

    static func parse(html: String, baseURL: URL?) -> LinkMetadata {
        let tags = metaTags(in: html)

        func value(_ keys: [String]) -> String? {
            for key in keys {
                if let found = tags[key], !found.isEmpty { return found }
            }
            return nil
        }

        var metadata = LinkMetadata()
        metadata.title = value(["og:title", "twitter:title"]) ?? titleTag(in: html)
        metadata.description = value(["og:description", "twitter:description", "description"])
        metadata.siteName = value(["og:site_name", "application-name"])

        if let image = value(["og:image", "og:image:url", "twitter:image", "twitter:image:src"]) {
            metadata.imageURL = absoluteString(for: image, baseURL: baseURL)
        }

        return metadata
    }

    /// Maps every `<meta>` tag's property/name to its content.
    private static func metaTags(in html: String) -> [String: String] {
        var tags: [String: String] = [:]

        guard let tagPattern = try? NSRegularExpression(pattern: "<meta\\b[^>]*>", options: [.caseInsensitive]) else {
            return tags
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in tagPattern.matches(in: html, range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])

            guard
                let key = attribute("property", in: tag) ?? attribute("name", in: tag),
                let content = attribute("content", in: tag)
            else { continue }

            let normalizedKey = key.lowercased()
            if tags[normalizedKey] == nil {
                tags[normalizedKey] = decodeEntities(content)
            }
        }

        return tags
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\(name)\\s*=\\s*(\"([^\"]*)\"|'([^']*)')"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..<tag.endIndex, in: tag))
        else { return nil }

        for group in [2, 3] {
            if let range = Range(match.range(at: group), in: tag) {
                let value = String(tag[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    private static func titleTag(in html: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
            let range = Range(match.range(at: 1), in: html)
        else { return nil }

        let title = decodeEntities(String(html[range]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private static func absoluteString(for candidate: String, baseURL: URL?) -> String? {
        if candidate.hasPrefix("http://") || candidate.hasPrefix("https://") { return candidate }
        guard let baseURL else { return nil }
        if candidate.hasPrefix("//") {
            return (baseURL.scheme ?? "https") + ":" + candidate
        }
        return URL(string: candidate, relativeTo: baseURL)?.absoluteString
    }

    /// The handful of entities that actually show up in titles.
    private static func decodeEntities(_ text: String) -> String {
        var result = text
        let replacements = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&nbsp;", " "), ("&mdash;", "—"), ("&ndash;", "–"),
            ("&hellip;", "…"), ("&rsquo;", "’"), ("&lsquo;", "‘"),
            ("&ldquo;", "“"), ("&rdquo;", "”")
        ]
        for (entity, character) in replacements {
            result = result.replacingOccurrences(of: entity, with: character, options: .caseInsensitive)
        }
        return result
    }
}
