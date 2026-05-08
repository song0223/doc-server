import Foundation
import NIOCore
import NIOHTTP1

/// HTTP 请求处理器
final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let database: MySQLDatabase

    init(database: MySQLDatabase) {
        self.database = database
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)

        switch reqPart {
        case .head(let request):
            handleRequest(request: request, context: context)
        case .body:
            break
        case .end:
            break
        }
    }

    private func handleRequest(request: HTTPRequestHead, context: ChannelHandlerContext) {
        let path = request.uri

        if path == "/" || path == "/index.html" {
            serveIndexPage(context: context)
        } else if path.hasPrefix("/doc/") {
            let projectID = String(path.dropFirst(5))
            serveDocumentPage(projectID: projectID, context: context)
        } else if path == "/health" {
            sendResponse(html: "{\"status\":\"ok\"}", context: context)
        } else {
            serve404(context: context)
        }
    }

    private func serveIndexPage(context: ChannelHandlerContext) {
        do {
            let repository = DocRepository(database: database)
            let documents = try repository.fetchAllDocuments()

            var html = """
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>API文档中心</title>
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif; background: #f5f5f7; min-height: 100vh; }
                    .header { background: #fff; border-bottom: 1px solid #d2d2d7; padding: 24px 0; }
                    .header-inner { max-width: 960px; margin: 0 auto; padding: 0 24px; }
                    .header h1 { font-size: 28px; font-weight: 700; color: #1d1d1f; }
                    .header p { color: #86868b; margin-top: 8px; }
                    .container { max-width: 960px; margin: 0 auto; padding: 32px 24px; }
                    .doc-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }
                    .doc-card { background: #fff; border-radius: 12px; padding: 24px; border: 1px solid #d2d2d7; transition: all 0.2s; cursor: pointer; text-decoration: none; color: inherit; }
                    .doc-card:hover { border-color: #0071e3; box-shadow: 0 4px 12px rgba(0,0,0,0.1); transform: translateY(-2px); }
                    .doc-card h2 { font-size: 18px; font-weight: 600; color: #1d1d1f; margin-bottom: 8px; }
                    .doc-card p { color: #86868b; font-size: 14px; }
                    .empty { text-align: center; padding: 80px 0; color: #86868b; }
                    .empty svg { width: 64px; height: 64px; margin-bottom: 16px; opacity: 0.5; }
                </style>
            </head>
            <body>
                <div class="header">
                    <div class="header-inner">
                        <h1>📚 API文档中心</h1>
                        <p>浏览所有项目的API文档</p>
                    </div>
                </div>
                <div class="container">
            """

            if documents.isEmpty {
                html += """
                    <div class="empty">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                        </svg>
                        <h3>暂无文档</h3>
                        <p>请先在MacAPITester中生成API文档</p>
                    </div>
                """
            } else {
                html += '<div class="doc-grid">'
                for doc in documents {
                    html += "<a href=\"/doc/\(doc.projectID)\" class=\"doc-card\">"
                    html += "<h2>\(escapeHTML(doc.title))</h2>"
                    html += "<p>点击查看完整API文档</p>"
                    html += "</a>"
                }
                html += "</div>"
            }

            html += """
                </div>
            </body>
            </html>
            """

            sendResponse(html: html, context: context)
        } catch {
            sendResponse(html: "<h1>服务器错误</h1><p>\(error.localizedDescription)</p>", status: .internalServerError, context: context)
        }
    }

    private func serveDocumentPage(projectID: String, context: ChannelHandlerContext) {
        do {
            let repository = DocRepository(database: database)

            if let document = try repository.fetchDocument(projectID: projectID) {
                let html = wrapWithBackButton(document.htmlContent, title: document.title)
                sendResponse(html: html, context: context)
            } else {
                sendResponse(html: "<h1>文档不存在</h1><p>ProjectID: \(escapeHTML(projectID))</p>", status: .notFound, context: context)
            }
        } catch {
            sendResponse(html: "<h1>服务器错误</h1><p>\(error.localizedDescription)</p>", status: .internalServerError, context: context)
        }
    }

    private func wrapWithBackButton(_ html: String, title: String) -> String {
        if html.contains("<html") {
            return html.replacingOccurrences(
                of: "<body>",
                with: """
                <body>
                <div style="position:fixed;top:0;left:0;right:0;z-index:1000;background:#fff;border-bottom:1px solid #e0e0e0;padding:10px 20px;display:flex;align-items:center;gap:12px;">
                    <a href="/" style="color:#0066cc;text-decoration:none;font-size:14px;">← 返回首页</a>
                    <span style="color:#666;font-size:14px;">\(escapeHTML(title))</span>
                </div>
                <div style="margin-top:50px;">
                """
            )
        }
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(title))</title>
            <style>
                body { font-family: -apple-system, sans-serif; margin: 0; padding: 0; }
                .nav-bar { position: fixed; top: 0; left: 0; right: 0; z-index: 1000; background: #fff; border-bottom: 1px solid #e0e0e0; padding: 10px 20px; display: flex; align-items: center; gap: 12px; }
                .nav-bar a { color: #0066cc; text-decoration: none; font-size: 14px; }
                .nav-bar span { color: #666; font-size: 14px; }
                .content { margin-top: 50px; padding: 20px; }
            </style>
        </head>
        <body>
            <div class="nav-bar">
                <a href="/">← 返回首页</a>
                <span>\(escapeHTML(title))</span>
            </div>
            <div class="content">
                \(html)
            </div>
        </body>
        </html>
        """
    }

    private func serve404(context: ChannelHandlerContext) {
        sendResponse(html: """
        <!DOCTYPE html>
        <html><body style="font-family:sans-serif;text-align:center;padding:80px;">
        <h1>404 - 页面不存在</h1>
        <p><a href="/">返回首页</a></p>
        </body></html>
        """, status: .notFound, context: context)
    }

    private func sendResponse(html: String, status: HTTPResponseStatus = .ok, context: ChannelHandlerContext) {
        let body = ByteBuffer(string: html)

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(body.readableBytes)")

        let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)

        let bodyPart = HTTPServerResponsePart.body(.byteBuffer(body))
        context.write(wrapOutboundOut(bodyPart), promise: nil)

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}
