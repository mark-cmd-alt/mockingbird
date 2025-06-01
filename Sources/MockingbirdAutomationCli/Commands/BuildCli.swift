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
      case centOS = "centos"
      // TODO: Support other Linux distros
    }

    func getVersionString() throws -> String {
      return try PlistBuddy.printValue(key: "CFBundleShortVersionString",
                                       plist: Path("./Sources/MockingbirdCli/Info.plist"))
    }

    private func codesign(_ binary: Path) throws {
      guard let identity = signingIdentity else { return }
      try Codesign.sign(binary: binary, identity: identity)
      try Codesign.verify(binary: binary, requirements: Path(requirements))
    }

    private func archiveMacOS(_ binary: Path) throws {
      guard let location = globalOptions.archiveLocation else { return }
      try archive(artifacts: [("", binary)], destination: Path(location))
    }

    private func archiveCentOS(_ binary: Path) throws {
      guard let location = globalOptions.archiveLocation else { return }
      let libPaths = SharedLibraries.centOS.map({ Path($0) })
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
        try codesign(cliPath)
        try archiveMacOS(cliPath)
      case .centOS:
        try archiveCentOS(cliPath)
      }
    }
  }
}

private enum SharedLibraries {
  static let centOS = [
    "/usr/lib/libsourcekitdInProc.so",
    "/usr/lib/swift/linux/libBlocksRuntime.so",
    "/usr/lib/swift/linux/libFoundation.so",
    "/usr/lib/swift/linux/libFoundationEssentials.so",
    "/usr/lib/swift/linux/libFoundationInternationalization.so",
    "/usr/lib/swift/linux/libFoundationNetworking.so",
    "/usr/lib/swift/linux/libFoundationXML.so",
    "/usr/lib/swift/linux/libdispatch.so",
    // "/usr/lib/swift/linux/libicudataswift.so.65",
    // "/usr/lib/swift/linux/libicui18nswift.so.65",
    // "/usr/lib/swift/linux/libicuucswift.so.65",
    "/usr/lib/swift/linux/libswiftCore.so",
    "/usr/lib/swift/linux/libswiftDispatch.so",
    "/usr/lib/swift/linux/libswiftGlibc.so",
    "/usr/lib/swift/linux/libswift_Concurrency.so",
    "/usr/lib/swift/linux/libswift_RegexParser.so",
    "/usr/lib/swift/linux/libswift_StringProcessing.so",
  ]
}
