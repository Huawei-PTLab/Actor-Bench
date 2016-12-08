import PackageDescription

let package = Package(
    name: "Sam-Bench",
    dependencies: [
        .Package(url: "git@github.com:Huawei-PTLab/Sam.git", majorVersion: 0, minor: 1)
    ]
)
