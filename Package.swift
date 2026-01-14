// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOptimizer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AppUninstaller", targets: ["AppUninstaller"])
    ],
    targets: [
        .executableTarget(
            name: "AppUninstaller",
            path: "AppUninstaller",
            exclude: [
                "Info.plist",
                "compile_errors.txt"
            ],
            resources: [
                .process("AppIcon.icns"),
                .process("AppIcon_back.icns"),
                .process("ButtonClick.m4a"),
                .process("CleanDidFinish-Winter.m4a"),
                .process("CleanDidFinish.m4a"),
                .process("Intro.mp4"),
                .process("Uninstaller.jpg"),
                .process("Uninstaller@2x.jpg"),
                .process("appuploader.png"),
                .process("clean-up.866fafd0.png"),
                .process("feizhilou.png"),
                .process("kongjianshentou copy.png"),
                .process("kongjianshentou.png"),
                .process("malware.jpg"),
                .process("malware@2x.jpg"),
                .process("malware@2x.png"),
                .process("protection.80f7790f.png"),
                .process("resubscribe_welcome.png"),
                .process("resubscribe_welcome@2x.png"),
                .process("smart-scan.2f4ddf59.png"),
                .process("system-junk-mouse.png"),
                .process("system_clean.png"),
                .process("yinsi.png"),
                .process("youhua.png")
            ]
        ),
        .testTarget(
            name: "AppUninstallerTests",
            dependencies: ["AppUninstaller"]
        )
    ]
)


