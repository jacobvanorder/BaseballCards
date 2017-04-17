// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "BaseballCards",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/jacobvanorder/Kitura-CredentialsTwitter.git", Version(0,2,1))
    ]
)
