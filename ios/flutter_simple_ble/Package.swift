// swift-tools-version: 5.9
// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import PackageDescription

let package = Package(
    name: "flutter_simple_ble",
    platforms: [.iOS("15.0")],
    products: [
        .library(name: "flutter-simple-ble", targets: ["flutter_simple_ble"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "flutter_simple_ble",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [.process("PrivacyInfo.xcprivacy")]
        ),
    ]
)
