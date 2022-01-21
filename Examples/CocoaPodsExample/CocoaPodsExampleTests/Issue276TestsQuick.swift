import XCTest
import Mockingbird
import Quick
@testable import CocoaPodsExample

class Issue276TestsQuick: QuickSpec {
  override func spec() {
    describe("mockingbird") {
      it("wasCalled") {
        let myMock = mock(Issue276.self)
        guard let scene = UIApplication.shared.connectedScenes.first else {
          XCTFail("No available scene")
          return
        }
        (myMock as Issue276).scene(scene, continue: NSUserActivity(activityType: "co.bird"))
        verify(myMock.scene(any(), continue: any())).wasCalled()
      }
      
      it("wasNeverCalled") {
        let myMock = mock(Issue276.self)
        verify(myMock.scene(any(), continue: any())).wasNeverCalled()
      }
    }
  }
}
