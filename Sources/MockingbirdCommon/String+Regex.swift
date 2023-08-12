import Foundation

public extension String {
  /// Returns all matches and capture groups given a regex pattern string.
  ///
  /// For example if "foobarbaz foobarbaz" is the string and "foo(bar(baz))" is the pattern then the
  /// return value will be the following:
  ///
  ///     [
  ///       ["foobarbaz", "barbaz", "baz"],
  ///       ["foobarbaz", "barbaz", "baz"],
  ///     ]
  ///
  /// Each top-level element is a match and each sub-element is a capture group. Note that the first
  /// capture group is at index 1, and the second element and index 2, etc. The first _element_ is
  /// the entire matched substring.
  func components(matching pattern: String) -> [[Substring?]] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    return regex
      .matches(in: self, range: NSMakeRange(0, count))
      .map({ result -> [Substring?] in
        return (0..<result.numberOfRanges)
          .map({ index -> NSRange in result.range(at: index) })
          .map({ range -> Range<Index>? in
            range.location != NSNotFound ? Range(range, in: self) : nil
          })
          .map({ range -> Substring? in
            if let range = range {
              return self[range]
            } else {
              return nil
            }
          })
      })
  }
}
