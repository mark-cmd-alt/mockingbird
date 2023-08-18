import Foundation

protocol ExistentialAny {
  var unwrapped: any ChildProtocol { get }
  var wrapped: (any ChildProtocol) { get }
}

class ExistentialAnyClass {
  var unwrapped: any ChildProtocol { fatalError() }
  var wrapped: (any ChildProtocol) { fatalError() }
}
