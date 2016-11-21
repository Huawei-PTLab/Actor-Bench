import PackageDescription

let package = Package(
   name: "Benchmark",
   targets: [],
   dependencies: [
	   .Package(url: "git@github.com:Huawei-PTLab/Theater.git", versions: Version(1,2,2)..<Version(2,0,0)),
   ]
   )

let targetRing = Target(name: "Ring")
let targetRing2 = Target(name: "Ring2")
package.targets.append(targetRing)
