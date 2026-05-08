import Foundation

/// 文档记录
struct DocRecord {
    let id: String
    let projectID: String
    let title: String
    let htmlContent: String
}

/// 文档仓库
final class DocRepository {
    private let database: MySQLDatabase

    init(database: MySQLDatabase) {
        self.database = database
    }

    /// 获取所有文档
    func fetchAllDocuments() throws -> [DocRecord] {
        let rows = try database.query("SELECT id, project_id, title, html_content FROM api_documents ORDER BY title")
        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let projectID = row["project_id"] as? String,
                  let title = row["title"] as? String,
                  let htmlContent = row["html_content"] as? String else {
                return nil
            }
            return DocRecord(id: id, projectID: projectID, title: title, htmlContent: htmlContent)
        }
    }

    /// 根据项目ID获取文档
    func fetchDocument(projectID: String) throws -> DocRecord? {
        let rows = try database.query("SELECT id, project_id, title, html_content FROM api_documents WHERE project_id = '\(projectID)' LIMIT 1")
        guard let row = rows.first,
              let id = row["id"] as? String,
              let pid = row["project_id"] as? String,
              let title = row["title"] as? String,
              let htmlContent = row["html_content"] as? String else {
            return nil
        }
        return DocRecord(id: id, projectID: pid, title: title, htmlContent: htmlContent)
    }
}
