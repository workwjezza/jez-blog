//
//  SiteExporter.swift
//  jez-blog
//
//  Turns every post with `publishToWeb` on into a small static site:
//
//      index.html · style.css · feed.json · posts/<slug>.html · media/…
//

import Foundation

struct ExportSummary {
    let destination: URL
    let postCount: Int
    let mediaCount: Int
    let skippedMediaCount: Int
}

enum SiteExportError: LocalizedError {
    case nothingPublished
    case writeFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .nothingPublished:
            return "No posts are published yet. Switch “Publish to Web” on for the posts you want to export."
        case .writeFailed(let url, let error):
            return "Could not write to “\(url.lastPathComponent)” — \(error.localizedDescription)"
        }
    }
}

@MainActor
enum SiteExporter {

    static let siteTitle = "jez-blog"
    static let siteTagline = "A media garden."

    /// Writes the site into `root`, which the user picked, and returns a summary.
    static func export(posts: [Post], to root: URL) throws -> ExportSummary {
        let scoped = root.startAccessingSecurityScopedResource()
        defer { if scoped { root.stopAccessingSecurityScopedResource() } }

        let published = posts
            .filter(\.publishToWeb)
            .sorted { $0.createdAt > $1.createdAt }

        guard !published.isEmpty else { throw SiteExportError.nothingPublished }

        let fileManager = FileManager.default
        let postsDirectory = root.appendingPathComponent("posts", isDirectory: true)
        let mediaDirectory = root.appendingPathComponent("media", isDirectory: true)

        for directory in [postsDirectory, mediaDirectory] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // Slugs must be unique and stable.
        var usedSlugs: Set<String> = []
        var pages: [(post: Post, slug: String)] = []

        for post in published {
            let base = post.webSlug ?? PostToolbarView.slug(from: post.previewTitle)
            var slug = base
            var suffix = 2
            while usedSlugs.contains(slug) {
                slug = "\(base)-\(suffix)"
                suffix += 1
            }
            usedSlugs.insert(slug)
            post.webSlug = slug
            pages.append((post, slug))
        }

        // Copy media alongside the pages.
        var copied = 0
        var skipped = 0
        for page in pages {
            for asset in page.post.sortedAssets {
                guard let path = asset.localPath else { continue }
                guard asset.fileExists else { skipped += 1; continue }

                let source = URL(fileURLWithPath: path)
                let destination = mediaDirectory.appendingPathComponent(source.lastPathComponent)
                if fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.removeItem(at: destination)
                }
                do {
                    try fileManager.copyItem(at: source, to: destination)
                    copied += 1
                } catch {
                    skipped += 1
                }
            }
        }

        // Pages.
        for page in pages {
            let html = postPage(for: page.post, slug: page.slug)
            try write(html, to: postsDirectory.appendingPathComponent("\(page.slug).html"))
        }

        try write(indexPage(for: pages), to: root.appendingPathComponent("index.html"))
        try write(styleSheet, to: root.appendingPathComponent("style.css"))
        try write(feed(for: pages), to: root.appendingPathComponent("feed.json"))

        return ExportSummary(
            destination: root,
            postCount: pages.count,
            mediaCount: copied,
            skippedMediaCount: skipped
        )
    }

    private static func write(_ contents: String, to url: URL) throws {
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw SiteExportError.writeFailed(url, error)
        }
    }

    // MARK: - Index

    private static func indexPage(for pages: [(post: Post, slug: String)]) -> String {
        let cards = pages.map { page -> String in
            let post = page.post
            let tags = post.tags.map { "<li>#\(escape($0))</li>" }.joined()

            return """
                  <li class="card">
                    <a class="card-link" href="posts/\(page.slug).html">
                      <p class="kind">\(escape(post.displayType.label))</p>
                      <h2>\(escape(post.previewTitle))</h2>
                      <p class="excerpt">\(escape(String(post.previewExcerpt.prefix(220))))</p>
                    </a>
                    <footer>
                      <time datetime="\(post.createdAt.isoDescription)">\(escape(post.createdAt.longDescription))</time>
                      \(tags.isEmpty ? "" : "<ul class=\"tags\">\(tags)</ul>")
                    </footer>
                  </li>
                """
        }.joined(separator: "\n")

        return document(
            title: siteTitle,
            stylePath: "style.css",
            body: """
                <header class="site">
                  <h1>\(escape(siteTitle))</h1>
                  <p class="tagline">\(escape(siteTagline))</p>
                </header>
                <main>
                  <ul class="cards">
                \(cards)
                  </ul>
                </main>
                <footer class="site">
                  <p>\(pages.count) post\(pages.count == 1 ? "" : "s") · exported \(escape(Date().longDescription))</p>
                </footer>
                """
        )
    }

    // MARK: - Post pages

    private static func postPage(for post: Post, slug: String) -> String {
        let tags = post.tags.map { "<li>#\(escape($0))</li>" }.joined()

        return document(
            title: "\(post.previewTitle) — \(siteTitle)",
            stylePath: "../style.css",
            body: """
                <header class="site">
                  <p class="back"><a href="../index.html">← \(escape(siteTitle))</a></p>
                </header>
                <article class="post \(post.displayType.rawValue)">
                  <header>
                    <p class="kind">\(escape(post.displayType.label))</p>
                    <time datetime="\(post.createdAt.isoDescription)">\(escape(post.createdAt.longDescription))</time>
                  </header>
                \(content(for: post))
                  \(tags.isEmpty ? "" : "<ul class=\"tags\">\(tags)</ul>")
                </article>
                """
        )
    }

    private static func content(for post: Post) -> String {
        switch post.displayType {
        case .thread, .singlePost:
            return paragraphs(for: post.sortedBlocks)

        case .mediaArrangement:
            return "\(gallery(for: post))\n\(paragraphs(for: post.sortedBlocks))"

        case .shortWithImage:
            return "\(gallery(for: post))\n\(paragraphs(for: post.sortedBlocks))"

        case .videoClip:
            return "\(videoTag(for: post))\n\(paragraphs(for: post.sortedBlocks))"

        case .linkCard:
            return "\(linkCard(for: post))\n\(paragraphs(for: post.sortedBlocks))"
        }
    }

    private static func paragraphs(for blocks: [ContentBlock]) -> String {
        blocks
            .map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { block in
                let lines = block
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { "  <p>\(escape($0))</p>" }
                    .joined(separator: "\n")
                return "  <div class=\"block\">\n\(lines)\n  </div>"
            }
            .joined(separator: "\n")
    }

    private static func gallery(for post: Post) -> String {
        let images = post.sortedAssets.filter { $0.assetType == .image && $0.fileExists }
        guard !images.isEmpty else { return "" }

        let figures = images.map { asset -> String in
            let name = URL(fileURLWithPath: asset.localPath ?? "").lastPathComponent
            let feature = asset.isFeatureTile ? " class=\"feature\"" : ""
            return """
                  <figure\(feature)>
                    <img src="../media/\(escapeAttribute(name))" alt="\(escapeAttribute(asset.accessibleDescription))" loading="lazy">
                  </figure>
                """
        }.joined(separator: "\n")

        return """
          <div class="gallery count-\(images.count)">
        \(figures)
          </div>
        """
    }

    private static func videoTag(for post: Post) -> String {
        guard
            let asset = post.sortedAssets.first(where: { $0.assetType == .video }),
            asset.fileExists,
            let path = asset.localPath
        else { return "" }

        let name = URL(fileURLWithPath: path).lastPathComponent
        return """
          <figure class="video">
            <video controls preload="metadata" src="../media/\(escapeAttribute(name))"></video>
          </figure>
        """
    }

    private static func linkCard(for post: Post) -> String {
        guard
            let asset = post.sortedAssets.first(where: { $0.assetType == .linkPreview }),
            let url = asset.url
        else { return "" }

        let host = url.host() ?? url.absoluteString
        let title = asset.previewTitle ?? host
        let description = asset.previewDescription
        let image = asset.previewImageURL

        return """
          <a class="link-card" href="\(escapeAttribute(url.absoluteString))" rel="noopener">
            \(image.map { "<img src=\"\(escapeAttribute($0))\" alt=\"\" loading=\"lazy\">" } ?? "")
            <span class="link-body">
              <strong>\(escape(title))</strong>
              \(description.map { "<span class=\"link-description\">\(escape($0))</span>" } ?? "")
              <span class="link-host">\(escape(host))</span>
            </span>
          </a>
        """
    }

    // MARK: - Feed

    private static func feed(for pages: [(post: Post, slug: String)]) -> String {
        let items = pages.map { page -> String in
            """
                {
                  "id": "\(page.post.id.uuidString)",
                  "url": "posts/\(page.slug).html",
                  "title": \(jsonString(page.post.previewTitle)),
                  "content_text": \(jsonString(page.post.previewExcerpt)),
                  "date_published": "\(page.post.createdAt.isoDescription)",
                  "tags": [\(page.post.tags.map(jsonString).joined(separator: ", "))]
                }
            """
        }.joined(separator: ",\n")

        return """
        {
          "version": "https://jsonfeed.org/version/1.1",
          "title": \(jsonString(siteTitle)),
          "description": \(jsonString(siteTagline)),
          "items": [
        \(items)
          ]
        }
        """
    }

    // MARK: - Shell

    private static func document(title: String, stylePath: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escape(title))</title>
          <link rel="stylesheet" href="\(escapeAttribute(stylePath))">
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static var styleSheet: String {
        """
        :root {
          --accent: #007aff;
          --ink: #1c1c1e;
          --muted: #6e6e73;
          --hairline: rgba(0, 0, 0, 0.10);
          --card: rgba(0, 0, 0, 0.04);
          --bg: #fdfdfb;
          --radius: 12px;
        }

        @media (prefers-color-scheme: dark) {
          :root {
            --accent: #0a84ff;
            --ink: #f2f2f7;
            --muted: #9a9aa0;
            --hairline: rgba(255, 255, 255, 0.14);
            --card: rgba(255, 255, 255, 0.06);
            --bg: #131315;
          }
        }

        * { box-sizing: border-box; }

        body {
          margin: 0 auto;
          padding: 48px 24px 96px;
          max-width: 720px;
          background: var(--bg);
          color: var(--ink);
          font: 17px/1.6 ui-serif, "New York", Georgia, serif;
          -webkit-font-smoothing: antialiased;
        }

        a { color: var(--accent); text-decoration: none; }
        a:hover { text-decoration: underline; }

        header.site { margin-bottom: 40px; }
        header.site h1 { font-size: 2.2rem; margin: 0; letter-spacing: -0.02em; }
        .tagline, .kind, .link-host, footer.site, .back {
          font-family: ui-sans-serif, -apple-system, system-ui, sans-serif;
        }
        .tagline { color: var(--muted); margin: 6px 0 0; }
        .back { font-size: 0.85rem; }

        .kind {
          font-size: 0.72rem;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: var(--accent);
          margin: 0 0 6px;
        }

        ul.cards { list-style: none; margin: 0; padding: 0; display: grid; gap: 16px; }

        .card {
          border: 1px solid var(--hairline);
          border-radius: var(--radius);
          background: var(--card);
          padding: 20px 22px;
          transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .card:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0, 0, 0, 0.10); }
        .card a.card-link { color: inherit; text-decoration: none; display: block; }
        .card h2 { font-size: 1.25rem; margin: 0 0 8px; }
        .card .excerpt { color: var(--muted); margin: 0; }
        .card footer {
          display: flex; flex-wrap: wrap; gap: 10px; align-items: center;
          margin-top: 14px; font-size: 0.78rem; color: var(--muted);
          font-family: ui-sans-serif, -apple-system, system-ui, sans-serif;
        }

        ul.tags { list-style: none; display: flex; flex-wrap: wrap; gap: 6px; margin: 16px 0 0; padding: 0; }
        ul.tags li {
          font-family: ui-sans-serif, -apple-system, system-ui, sans-serif;
          font-size: 0.75rem; color: var(--accent);
          background: color-mix(in srgb, var(--accent) 14%, transparent);
          border-radius: 999px; padding: 3px 9px;
        }

        article.post header { margin-bottom: 28px; color: var(--muted); font-size: 0.8rem; }
        article.post .block + .block { margin-top: 1.4em; }
        article.post p { margin: 0 0 1em; }

        .gallery { display: grid; gap: 10px; margin: 0 0 28px; grid-template-columns: repeat(2, 1fr); }
        .gallery.count-1 { grid-template-columns: 1fr; }
        .gallery figure { margin: 0; }
        .gallery figure.feature { grid-column: 1 / -1; }
        .gallery img, .video video {
          display: block; width: 100%; height: auto;
          border-radius: var(--radius); border: 1px solid var(--hairline);
        }
        .video { margin: 0 0 28px; }

        .link-card {
          display: flex; gap: 14px; align-items: center;
          border: 1px solid var(--hairline); border-radius: var(--radius);
          background: var(--card); padding: 14px; margin-bottom: 28px;
          color: inherit; text-decoration: none;
        }
        .link-card:hover { text-decoration: none; border-color: var(--accent); }
        .link-card img { width: 88px; height: 88px; object-fit: cover; border-radius: 8px; flex: none; }
        .link-body { display: flex; flex-direction: column; gap: 4px; }
        .link-description { color: var(--muted); font-size: 0.92rem; }
        .link-host { color: var(--accent); font-size: 0.76rem; }

        footer.site { margin-top: 56px; color: var(--muted); font-size: 0.78rem; }
        """
    }

    // MARK: - Escaping

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ text: String) -> String {
        escape(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func jsonString(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}
