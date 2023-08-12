import Foundation
import PathKit
import SourceKittenFramework

struct ParsedFile {
  let file: File
  let data: Data?
  let path: Path
  let moduleName: String
  let importDeclarations: Set<ImportDeclaration>
  let conditionalCompilationBlocks: [ConditionalCompilationBlock]
  let structure: Structure
  let shouldMock: Bool
  
  var imports: Set<String> {
    return Set(importDeclarations.map({ $0.fullDeclaration }))
  }
  var importedModuleNames: Set<String> {
    return Set(importDeclarations.map({ $0.moduleName }))
  }
  
  init(file: File,
       path: Path,
       moduleName: String,
       importDeclarations: Set<ImportDeclaration>,
       conditionalCompilationBlocks: [ConditionalCompilationBlock],
       structure: Structure,
       shouldMock: Bool) {
    self.file = file
    self.data = file.contents.data(using: .utf8, allowLossyConversion: false)
    self.path = path
    self.moduleName = moduleName
    self.importDeclarations = importDeclarations
    self.conditionalCompilationBlocks = conditionalCompilationBlocks
    self.structure = structure
    self.shouldMock = shouldMock
  }
  
  init(from other: ParsedFile, shouldMock: Bool) {
    self.init(file: other.file,
              path: other.path,
              moduleName: other.moduleName,
              importDeclarations: other.importDeclarations,
              conditionalCompilationBlocks: other.conditionalCompilationBlocks,
              structure: other.structure,
              shouldMock: shouldMock)
  }
}

struct ConditionalCompilationBlock: Comparable, Hashable {
  let directive: Directive
  let condition: Substring?
  let range: Range<Int64> // Byte offset bounds of the compilation directive declaration.
  let standaloneCondition: String

  var declaration: String { "#\(Directive.if.rawValue) \(standaloneCondition)" }
  
  enum Directive: String {
    case `if`
    case `elseif`
    case `else`
    case `endif`
  }
  
  init(directive: Directive,
       condition: Substring?,
       range: Range<Int64>,
       preceedingBlocks: [ConditionalCompilationBlock]) {
    self.directive = directive
    self.condition = condition
    self.range = range
    self.standaloneCondition = Self.generateStandaloneCondition(directive: directive,
                                                                condition: condition,
                                                                preceedingBlocks: preceedingBlocks)
  }
  
  private init(directive: Directive, condition: Substring?, range: Range<Int64>, standaloneCondition: String) {
    self.directive = directive
    self.condition = condition
    self.range = range
    self.standaloneCondition = standaloneCondition
  }
  
  static func generateStandaloneCondition(directive: Directive,
                                          condition: Substring?,
                                          preceedingBlocks: [ConditionalCompilationBlock]) -> String {
    var shouldNegate = directive != .if // Only negate conditions from blocks in the same group.
    var blockLevel = 0
    var conditionChain: [String] = []
    if let condition = condition {
      conditionChain.append(String(condition))
    }
    for i in stride(from: preceedingBlocks.count - 1, to: -1, by: -1) {
      let block = preceedingBlocks[i]
      switch (block.directive, shouldNegate) {
      case (.if, true):
        shouldNegate = false
        fallthrough
      case (.elseif, true),
           (.else, true),
           (.endif, true):
        if let condition = block.condition {
          conditionChain.append("!(\(condition))")
        }

      case (.if, false):
        if blockLevel == 0, let condition = block.condition {
          conditionChain.append(String(condition))
        }
        blockLevel = max(0, blockLevel - 1)
      case (.endif, false):
        blockLevel += 1
      case (.elseif, false),
           (.else, false):
        break
      }
    }
    return conditionChain.joined(separator: " && ")
  }

  func extendedRange(to endIndex: Int64) -> Self {
    .init(directive: directive,
          condition: condition,
          range: range.startIndex..<endIndex,
          standaloneCondition: standaloneCondition)
  }
  
  static func < (lhs: ConditionalCompilationBlock, rhs: ConditionalCompilationBlock) -> Bool {
    return lhs.range.lowerBound < rhs.range.lowerBound
  }
}

struct ImportDeclaration: Hashable {
  let moduleName: String
  let fullPath: String
  let fullDeclaration: String
  let attributes: Set<String>
  let offset: Int64
  
  init(moduleName: String,
       fullPath: String,
       fullDeclaration: String,
       attributes: Set<String>,
       offset: Int64) {
    self.moduleName = moduleName
    self.fullPath = fullPath
    self.fullDeclaration = fullDeclaration
    self.attributes = attributes
    self.offset = offset
  }

  init(_ moduleName: String, testable: Bool = false) {
    self.moduleName = moduleName
    self.fullPath = moduleName
    self.fullDeclaration = (testable ? "@testable " : "") + "import " + moduleName
    self.attributes = testable ? ["@testable"] : []
    self.offset = 0
  }
}
