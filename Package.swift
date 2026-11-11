// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PatientPalCodeSample",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PatientPalSample", targets: ["PatientPalSample"]),
        .executable(name: "patientpal-demo", targets: ["PatientPalDemo"])
    ],
    targets: [
        .target(name: "PatientPalSample"),
        .executableTarget(name: "PatientPalDemo", dependencies: ["PatientPalSample"]),
        .testTarget(name: "PatientPalSampleTests", dependencies: ["PatientPalSample"])
    ]
)
