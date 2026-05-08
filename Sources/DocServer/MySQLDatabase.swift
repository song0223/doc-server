import Foundation
import CMySQL

/// MySQL数据库封装类
final class MySQLDatabase: @unchecked Sendable {
    private let host: String
    private let port: UInt32
    private let username: String
    private let password: String
    private let database: String
    private var connection: UnsafeMutablePointer<MYSQL>?
    private let lock = NSLock()

    init(
        host: String = "127.0.0.1",
        port: UInt32 = 3306,
        username: String = "root",
        password: String = "Netime@2023",
        database: String = "mac_api_tester"
    ) throws {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        try connect()
    }

    deinit {
        disconnect()
    }

    private func connect() throws {
        guard let conn = mysql_init(nil) else {
            throw MySQLError.connectionFailed("无法初始化MySQL连接")
        }

        var timeout: UInt32 = 10
        mysql_options(conn, MYSQL_OPT_CONNECT_TIMEOUT, &timeout)

        let result = mysql_real_connect(conn, host, username, password, database, port, nil, 0)

        guard result != nil else {
            let errorMessage = String(cString: mysql_error(conn))
            mysql_close(conn)
            throw MySQLError.connectionFailed(errorMessage)
        }

        self.connection = conn
        mysql_set_character_set(conn, "utf8mb4")
    }

    private func disconnect() {
        lock.lock()
        if let connection {
            mysql_close(connection)
        }
        connection = nil
        lock.unlock()
    }

    func query(_ sql: String) throws -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }

        guard let connection else {
            throw MySQLError.connectionFailed("数据库连接未建立")
        }

        let result = mysql_query(connection, sql)
        guard result == 0 else {
            let errorMessage = String(cString: mysql_error(connection))
            throw MySQLError.queryFailed(errorMessage)
        }

        guard let resultset = mysql_store_result(connection) else {
            let errorMessage = String(cString: mysql_error(connection))
            if !errorMessage.isEmpty {
                throw MySQLError.queryFailed(errorMessage)
            }
            return []
        }
        defer { mysql_free_result(resultset) }

        var rows: [[String: Any]] = []
        let numFields = mysql_num_fields(resultset)

        guard let fields = mysql_fetch_fields(resultset) else {
            throw MySQLError.queryFailed("无法获取字段信息")
        }

        var columnNames: [String] = []
        for i in 0..<numFields {
            let field = fields[Int(i)]
            columnNames.append(String(cString: field.name))
        }

        while let row = mysql_fetch_row(resultset) {
            guard let lengths = mysql_fetch_lengths(resultset) else {
                throw MySQLError.queryFailed("无法获取行数据长度")
            }
            var dictionary: [String: Any] = [:]

            for i in 0..<numFields {
                let columnName = columnNames[Int(i)]
                if let value = row[Int(i)] {
                    let length = Int(lengths[Int(i)])
                    let data = Data(bytes: value, count: length)
                    if let string = String(data: data, encoding: .utf8) {
                        dictionary[columnName] = string
                    } else {
                        dictionary[columnName] = data
                    }
                } else {
                    dictionary[columnName] = NSNull()
                }
            }

            rows.append(dictionary)
        }

        return rows
    }
}

enum MySQLError: Error {
    case connectionFailed(String)
    case queryFailed(String)
}
