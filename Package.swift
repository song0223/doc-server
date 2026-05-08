// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "doc-server",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.40.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CMySQL",
            pkgConfig: "mysqlclient",
            providers: [
                .brew(["mysql-client"]),
                .apt(["libmysqlclient-dev"])
            ]
        ),
        .executableTarget(
            name: "DocServer",
            dependencies: [
                "CMySQL",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            path: "Sources/DocServer"
        ),
    ]
)
