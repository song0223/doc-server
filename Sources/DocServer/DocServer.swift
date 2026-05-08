import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1

/// 文档服务器
final class DocServer {
    let port: Int
    private let host: String
    private let database: MySQLDatabase
    private var channel: Channel?
    private var group: MultiThreadedEventLoopGroup?

    init(port: Int = 8088, host: String = "0.0.0.0", database: MySQLDatabase) {
        self.port = port
        self.host = host
        self.database = database
    }

    func start() throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        guard let group else {
            throw DocServerError.serverStartFailed("无法创建事件循环组")
        }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [weak self] channel in
                guard let self else {
                    return channel.eventLoop.makeFailedFuture(DocServerError.serverStartFailed("服务器已释放"))
                }
                return channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(database: self.database))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        channel = try bootstrap.bind(host: host, port: port).wait()
        print("📄 文档服务器已启动: http://\(host):\(port)")
    }

    func stop() {
        try? channel?.close().wait()
        try? group?.syncShutdownGracefully()
        channel = nil
        group = nil
        print("📄 文档服务器已停止")
    }

    var accessURL: String {
        "http://localhost:\(port)"
    }
}

enum DocServerError: Error {
    case serverStartFailed(String)
}
