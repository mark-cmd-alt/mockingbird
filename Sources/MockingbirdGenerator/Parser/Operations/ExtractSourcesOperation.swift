import Foundation
import PathKit
import XcodeProj

public struct SourcePath: Hashable, Equatable {
  public let path: Path
  public let moduleName: String
}

public class ExtractSourcesOperationResult {
  fileprivate(set) public var targetPaths = Set<SourcePath>()
  fileprivate(set) public var dependencyPaths = Set<SourcePath>()
  fileprivate(set) public var supportPaths = Set<SourcePath>() // Mainly used for caching.
  fileprivate(set) public var moduleDependencies = [String: Set<String>]()
}

public protocol ExtractSourcesAbstractOperation: Runnable {
  var result: ExtractSourcesOperationResult { get }
}

public struct ExtractSourcesOptions: OptionSet {
  public let rawValue: Int
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
  
  public static let dependencyPaths = ExtractSourcesOptions(rawValue: 1 << 1)
  
  public static let all: ExtractSourcesOptions = [.dependencyPaths]
}

/// Given a target, find all related source files including those compiled by dependencies.
public class ExtractSourcesOperation<T: Target>: ExtractSourcesAbstractOperation {
  public let target: T
  let sourceRoot: Path
  let supportPath: Path?
  let options: ExtractSourcesOptions
  let environment: () -> [String: Any]
  
  public let result = ExtractSourcesOperationResult()
  public var description: String { "Extract Sources" }
  
  public init(target: T,
              sourceRoot: Path,
              supportPath: Path?,
              options: ExtractSourcesOptions,
              environment: @escaping () -> [String: Any]) {
    self.target = target
    self.sourceRoot = sourceRoot
    self.supportPath = supportPath
    self.options = options
    self.environment = environment
  }
  
  private weak var context: RunnableContext?
  public func run(context: RunnableContext) throws {
    try time(.extractSources) {
      self.context = context
      result.targetPaths = sourceFilePaths(for: target)
      
      if options.contains(.dependencyPaths) {
        let supportSourcePaths: Set<SourcePath>
        if let supportPath = supportPath {
          supportSourcePaths = try findSupportSourcePaths(at: supportPath)
        } else {
          supportSourcePaths = []
        }
        result.supportPaths = supportSourcePaths
      
        result.dependencyPaths =
          Set(allTargets(for: target).flatMap({ sourceFilePaths(for: $0) }))
            .union(supportSourcePaths)
            .subtracting(result.targetPaths)
      }
    }
    log("Found \(result.targetPaths.count) source file\(result.targetPaths.count != 1 ? "s" : "") and \(result.dependencyPaths.count) dependency source file\(result.dependencyPaths.count != 1 ? "s" : "") for target \(target.name.singleQuoted)")
  }
  
  /// Returns the compiled source file paths for a single given target.
  private var memoizedSourceFilePaths = [String: Set<SourcePath>]()
  private func sourceFilePaths(for target: T) -> Set<SourcePath> {
    if let memoized = memoizedSourceFilePaths[target.name] { return memoized }
    
    let moduleName = resolveProductModuleName(for: target)
    let paths = target.findSourceFilePaths(sourceRoot: sourceRoot)
      .filter({ !$0.string.hasSuffix(".generated.swift") })
      .map({ SourcePath(path: $0, moduleName: moduleName) })
    
    let includedPaths = Set(paths)
    memoizedSourceFilePaths[target.name] = includedPaths
    log("Got \(includedPaths.count) source file path\(includedPaths.count == 1 ? "" : "s") for " +
        "target \(target.name)")
    return includedPaths
  }
  
  /// Recursively find all targets and its dependency targets.
  private var memoizedTargets = [String: Set<T>]()
  private func allTargets(for target: T) -> Set<T> {
    if let memoized = memoizedTargets[target.name] { return memoized }
    
    let targets = Set([target]).union(
      target.dependencies
        .compactMap({ $0.target as? T })
        .flatMap({ allTargets(for: $0) }))
    let productModuleName = resolveProductModuleName(for: target)
    
    result.moduleDependencies[productModuleName] = Set(targets.map({
      resolveProductModuleName(for: $0)
    }))
    memoizedTargets[target.name] = targets
    
    return targets
  }
  
  /// Recursively find support module sources, taking each directory as the module name. Nested
  /// directories are treated as submodules and can be accessed as a source from each parent module.
  private func findSupportSourcePaths(at root: Path,
                                      isTopLevel: Bool = true) throws -> Set<SourcePath> {
    guard root.isDirectory else { return [] }
    let moduleName = root.lastComponent
    
    return try Set(root.children().flatMap({ path throws -> [SourcePath] in
      if path.isDirectory {
        let childSourcePaths = try findSupportSourcePaths(at: path, isTopLevel: false)
        // Parent modules inherit all submodule source paths.
        let inheritedSourcePaths = isTopLevel ? [] : childSourcePaths.map({
          SourcePath(path: $0.path, moduleName: moduleName)
        })
        return childSourcePaths + inheritedSourcePaths
      } else if !isTopLevel, path.isFile, path.extension == "swift" {
        return [SourcePath(path: path, moduleName: moduleName)]
      } else {
        return []
      }
    }))
  }
  
  private var memoizedProductModuleNames = [String: String]()
  private func resolveProductModuleName(for target: T) -> String {
    if let memoized = memoizedProductModuleNames[target.name] { return memoized }
    let productModuleName = target.resolveProductModuleName(environment: environment)
    memoizedProductModuleNames[target.name] = productModuleName
    return productModuleName
  }
}
