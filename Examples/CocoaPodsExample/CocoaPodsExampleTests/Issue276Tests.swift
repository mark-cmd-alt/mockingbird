import XCTest
import Mockingbird
@testable import CocoaPodsExample

class Issue276Tests: XCTestCase {
  func testWasCalled() {
    let myMock = mock(Issue276.self)
    guard let scene = UIApplication.shared.connectedScenes.first else {
      XCTFail("No available scene")
      return
    }
    (myMock as Issue276).scene(scene, continue: NSUserActivity(activityType: "co.bird"))
    verify(myMock.scene(any(), continue: any())).wasCalled()
  }
  
  func testWasNeverCalled() {
    let myMock = mock(Issue276.self)
    verify(myMock.scene(any(), continue: any())).wasNeverCalled()
  }
}
