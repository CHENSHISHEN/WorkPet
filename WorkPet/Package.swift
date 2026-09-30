// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WorkPet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WorkPet", targets: ["WorkPet"])
    ],
    targets: [
        .executableTarget(
            name: "WorkPet",
            path: "Sources/WorkPet",
            resources: [
                .process("Resources/source-rules.json"),
                .copy("Resources/PetPacks")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "WorkPetTests",
            dependencies: ["WorkPet"],
            path: "Tests/WorkPetTests"
        )
    ]
)
