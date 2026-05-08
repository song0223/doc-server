import Foundation

// 从环境变量读取配置
let dbHost = ProcessInfo.processInfo.environment["DB_HOST"] ?? "127.0.0.1"
let dbPort = UInt32(ProcessInfo.processInfo.environment["DB_PORT"] ?? "3306") ?? 3306
let dbUser = ProcessInfo.processInfo.environment["DB_USERNAME"] ?? "root"
let dbPass = ProcessInfo.processInfo.environment["DB_PASSWORD"] ?? "Netime@2023"
let dbName = ProcessInfo.processInfo.environment["DB_DATABASE"] ?? "mac_api_tester"
let serverPort = Int(ProcessInfo.processInfo.environment["SERVER_PORT"] ?? "8088") ?? 8088

print("🚀 正在启动文档服务器...")
print("📊 数据库: \(dbHost):\(dbPort)/\(dbName)")

do {
    let database = try MySQLDatabase(
        host: dbHost,
        port: dbPort,
        username: dbUser,
        password: dbPass,
        database: dbName
    )
    print("✅ 数据库连接成功")

    let server = DocServer(port: serverPort, database: database)
    try server.start()

    print("✅ 文档服务器已就绪")
    print("🌐 访问地址: http://0.0.0.0:\(serverPort)")

    // 保持运行
    RunLoop.main.run()
} catch {
    print("❌ 启动失败: \(error)")
    exit(1)
}
