import Foundation
import ObjectiveC
import Foundation // Ignore duplicates (and this comment)

/// This struct will be ignored by the generator.
struct ModuleImportCases {
  let someVariable: Bool
  func someMethod() -> Bool {
    return true
  }
}

import CoreText// Ignore single line comments
import CoreAudio/* Ignore multi-line comments */
import CoreFoundation ; import CoreImage
; import CoreData ;import CoreML
  import CoreMedia

@testable import CoreVideo // Unique because of attribute

import class CoreFoundation.CFArray
import enum CoreText.CTFontUIFontType

struct ModuleImportCases2 {
  static let singleLineImport = "import singleline string import"
}

// @testable import testable single line commented out import
// import single line commented out import
