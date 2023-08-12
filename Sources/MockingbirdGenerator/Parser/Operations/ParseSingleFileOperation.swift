import Foundation
import MockingbirdCommon
import PathKit
import SourceKittenFramework

class ParseSingleFileOperation: Runnable {
  class Result {
    fileprivate(set) var parsedFile: ParsedFile?
  }

  let result = Result()
  var description: String { "Single File" }
  
  let sourcePath: SourcePath
  let shouldMock: Bool
  let sourceKitResult: ParseSourceKitOperation.Result
  let swiftSyntaxResult: ParseSwiftSyntaxOperation.Result
  
  init(sourcePath: SourcePath,
       shouldMock: Bool,
       sourceKitResult: ParseSourceKitOperation.Result,
       swiftSyntaxResult: ParseSwiftSyntaxOperation.Result) {
    self.sourcePath = sourcePath
    self.shouldMock = shouldMock
    self.sourceKitResult = sourceKitResult
    self.swiftSyntaxResult = swiftSyntaxResult
  }
  
  private static var memoizedParsedFiles = Synchronized<[SourcePath: ParsedFile]>([:])
  
  func run(context: RunnableContext) throws {
    let sourcePath = self.sourcePath
    if let memoized = ParseSingleFileOperation.memoizedParsedFiles.read({ $0[sourcePath] }) {
      result.parsedFile = ParsedFile(from: memoized, shouldMock: shouldMock)
      return
    }
    guard let file = sourceKitResult.file, let structure = sourceKitResult.structure else {
      logWarning("Unable to parse file at \(sourcePath.path.absolute()) due to SourceKit failure")
      return // SourceKit parsing failed earlier.
    }
    
    let parsedFile = ParsedFile(file: file,
                                path: sourcePath.path,
                                moduleName: sourcePath.moduleName,
                                importDeclarations: swiftSyntaxResult.importDeclarations,
                                conditionalCompilationBlocks: swiftSyntaxResult.conditionalCompilationBlocks,
                                structure: structure,
                                shouldMock: shouldMock)
    ParseSingleFileOperation.memoizedParsedFiles.update { $0[sourcePath] = parsedFile }
    result.parsedFile = parsedFile
    
    let totalImportDeclarations = swiftSyntaxResult.importDeclarations.count
    let totalConditionalCompilationBlocks = swiftSyntaxResult.conditionalCompilationBlocks.count
    log("Parsed \(totalImportDeclarations) import declaration\(totalImportDeclarations != 1 ? "s" : "") and " +
        "\(totalConditionalCompilationBlocks) compiler directive\(totalConditionalCompilationBlocks != 1 ? "s" : "") " +
        "in source file at \(sourcePath.path)")
    if shouldMock {
      log("Parsed source structure for module \(sourcePath.moduleName.singleQuoted) at \(sourcePath.path)")
    } else {
      log("Parsed dependency source structure for module \(sourcePath.moduleName.singleQuoted) at \(sourcePath.path)")
    }
  }
}

class ParseSourceKitOperation: Runnable {
  class Result {
    fileprivate(set) var structure: Structure?
    fileprivate(set) var file: File?
  }
  
  let result = Result()
  var description: String { "Parse SourceKit \(sourcePath.path)" }
  let sourcePath: SourcePath
  
  init(sourcePath: SourcePath) {
    self.sourcePath = sourcePath
  }
  
  func run(context: RunnableContext) throws {
    let file = try sourcePath.path.getFile()
    result.file = file
    result.structure = try Structure(file: file)
  }
}

class ParseSwiftSyntaxOperation: Runnable {
  class Result {
    fileprivate(set) var importDeclarations = Set<ImportDeclaration>()
    fileprivate(set) var conditionalCompilationBlocks = [ConditionalCompilationBlock]()
  }
  
  let result = Result()
  var description: String { "Parse SwiftSyntax \(sourcePath.path)" }
  let sourcePath: SourcePath
  
  init(sourcePath: SourcePath) {
    self.sourcePath = sourcePath
  }
  
  func run(context: RunnableContext) throws {
    // File reading is not shared with the parse SourceKit operation, but parsing >> reading.
    let file = try sourcePath.path.getFile()
    
    // TODO: Handle comment blocks
    var consumed = 0
    var pendingConditionalCompilationBlock: ConditionalCompilationBlock?
    
    for line in file.contents.substringComponents(separatedBy: "\n") {
      defer { consumed += line.count + 1 }
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      
      // Handle imports.
      let importMatches = trimmedLine.components(matching: #"""
      ^((@\S+ )*)import ?(typealias|struct|class|enum|protocol|let|var|func)? ([a-zA-Z0-9_\.]+)
      """#)
      if let importMatch = importMatches.first, importMatch.count == 5,
         let fullDeclaration = importMatch[0],
         let rawAttributes = importMatch[1],
         let fullPath = importMatch[4] {
        let attributes = rawAttributes.split(separator: " ").filter({ !$0.isEmpty }).map({ String($0) })
        let moduleName = fullPath.split(separator: ".").last ?? ""
        result.importDeclarations.insert(ImportDeclaration(moduleName: String(moduleName),
                                                           fullPath: String(fullPath),
                                                           fullDeclaration: String(fullDeclaration),
                                                           attributes: Set(attributes),
                                                           offset: Int64(consumed)))
        continue
      }
      
      // Handle compilation directives.
      let conditionalCompilationBlockMatches = trimmedLine.components(matching: #"^#(if|elseif|else|endif) ?([^\/]+)?"#)
      if let conditionalCompilationBlockMatch = conditionalCompilationBlockMatches.first,
         conditionalCompilationBlockMatch.count == 3,
         let rawDirective = conditionalCompilationBlockMatch[1] {
        let condition = conditionalCompilationBlockMatch[2]
        guard let directive = ConditionalCompilationBlock.Directive(rawValue: String(rawDirective)) else { continue }
        if let pendingBlock = pendingConditionalCompilationBlock?.extendedRange(to: Int64(consumed)){
          result.conditionalCompilationBlocks.append(pendingBlock)
          pendingConditionalCompilationBlock = nil
        }
        pendingConditionalCompilationBlock = ConditionalCompilationBlock(
          directive: directive,
          condition: condition,
          range: Int64(consumed)..<Int64(consumed + 1), // Temporary range until committed.
          preceedingBlocks: result.conditionalCompilationBlocks)
        continue
      }
    }
    
    // All Swift files implicitly import the Swift standard library.
    result.importDeclarations.insert(ImportDeclaration("Swift"))
    
    // Only include acutal blocks.
    result.conditionalCompilationBlocks = result.conditionalCompilationBlocks.filter({ block in
      switch block.directive {
      case .if, .elseif, .else: return true
      case .endif: return false
      }
    })
  }
}

extension Path {
  func getFile() throws -> File {
    let url = URL(fileURLWithPath: String(describing: absolute()), isDirectory: false)
    return try File(contents: String(contentsOf: url, encoding: .utf8))
  }
}
