import ArgumentParser
import Foundation
import MockingbirdAutomation
import PathKit

extension Build {
  struct BuildCli: ParsableCommand {
    static var configuration = CommandConfiguration(
      commandName: "cli",
      abstract: "Build the command line interface.")
    
    @Option(name: .customLong("sign"), help: "Identity used to sign the built binary.")
    var signingIdentity: String?
    
    @Option(help: "File path containing the designated requirement for codesigning.")
    var requirements: String =
      "./Sources/MockingbirdAutomationCli/Resources/CodesigningRequirements/mockingbird.txt"
    
    @Option(help: "The platform flavor for distribution.")
    var platform: Platform = .macOS
    
    @OptionGroup()
    var globalOptions: Options
    
    enum Platform: String, ExpressibleByArgument {
      case macOS = "macos"
      case centOS8 = "centos8"
      // TODO: Support other Linux distros
    }
    
    func getVersionString() throws -> String {
      return try PlistBuddy.printValue(key: "CFBundleShortVersionString",
                                       plist: Path("./Sources/MockingbirdCli/Info.plist"))
    }
    
    func fixupRpaths(_ binary: Path) throws {
      let version = try getVersionString()
      
      // Get rid of toolchain-dependent rpaths which aren't guaranteed to have a compatible version
      // of the internal SwiftSyntax parser lib.
      let developerDirectory = try XcodeSelect.printPath()
      // Swift 5.5 is used when building with Xcode 14+
      let swiftToolchainPath = developerDirectory
        + "Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx"
      try? InstallNameTool.deleteRpath(swiftToolchainPath.absolute().string, binary: binary)
      // Swift 5.5 is only present in Xcode 13.2+
      let swift5_5ToolchainPath = developerDirectory
        + "Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.5/macosx"
      try? InstallNameTool.deleteRpath(swift5_5ToolchainPath.absolute().string, binary: binary)
      
      // Add new rpaths in descending order of precedence.
      try InstallNameTool.addRpath("/usr/lib/mockingbird/\(version)", binary: binary)
      // Support environments with restricted write permissions to system resources.
      try InstallNameTool.addRpath("/var/tmp/lib/mockingbird/\(version)", binary: binary)
      try InstallNameTool.addRpath("/tmp/lib/mockingbird/\(version)", binary: binary)
    }
    
    private func codesign(_ binary: Path) throws {
      guard let identity = signingIdentity else { return }
      try Codesign.sign(binary: binary, identity: identity)
      try Codesign.verify(binary: binary, requirements: Path(requirements))
    }
    
    private func archiveMacOS(_ binary: Path) throws {
      guard let location = globalOptions.archiveLocation else { return }
      let libRoot = Path("./Sources/MockingbirdCli/Resources/Libraries")
      let libPaths = libRoot.glob("*.dylib") + [libRoot + "LICENSE.txt"]
      try archive(artifacts: [("", binary)] + libPaths.map({ ("Libraries", $0) }),
                  destination: Path(location))
    }
    
    private func archiveCentOS8(_ binary: Path) throws {
      guard let location = globalOptions.archiveLocation else { return }
      let libPaths = SharedLibraries.centOS8.map({ Path($0) })
      try archive(artifacts: [("", binary)] + libPaths.map({ ("", $0) }),
                  destination: Path(location))
    }
    
    func run() throws {
      let packagePath = Path("./Package.swift")
      let cliPath = try SwiftPackage.build(target: .product(name: "mockingbird"),
                                           configuration: .release,
                                           packageConfiguration: .executables,
                                           package: packagePath)
      
      switch platform {
      case .macOS:
        try fixupRpaths(cliPath)
        try codesign(cliPath)
        try archiveMacOS(cliPath)
      case .centOS8:
        try archiveCentOS8(cliPath)
      }
    }
  }
}

private enum SharedLibraries {
  static let centOS8 = [
    "/usr/lib/libsourcekitdInProc.so",
    "/usr/lib/swift/linux/libBlocksRuntime.so",
    "/usr/lib/swift/linux/libFoundation.so",
    "/usr/lib/swift/linux/libFoundationNetworking.so",
    "/usr/lib/swift/linux/libFoundationXML.so",
    "/usr/lib/swift/linux/lib_InternalSwiftSyntaxParser.so",
    "/usr/lib/swift/linux/libdispatch.so",
    "/usr/lib/swift/linux/libicudataswift.so.65",
    "/usr/lib/swift/linux/libicui18nswift.so.65",
    "/usr/lib/swift/linux/libicuucswift.so.65",
    "/usr/lib/swift/linux/libswiftCore.so",
    "/usr/lib/swift/linux/libswiftDispatch.so",
    "/usr/lib/swift/linux/libswiftGlibc.so",
    "/usr/lib/swift/linux/libswift_Concurrency.so",
  ]
}
