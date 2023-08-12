import XCTest
@testable import MockingbirdGenerator

class ConditionalCompilationBlockTests: XCTestCase {
  
  // MARK: - Single blocks
  
  func testSingleIfBlock() {
    let block = ConditionalCompilationBlock(directive: .if,
                                            condition: "DEBUG",
                                            range: 0..<1,
                                            preceedingBlocks: [])
    XCTAssertEqual(block.declaration, "#if DEBUG")
  }
  
  func testSingleElseIfBlock() {
    let block = ConditionalCompilationBlock(directive: .elseif,
                                            condition: "DEBUG",
                                            range: 0..<1,
                                            preceedingBlocks: [])
    XCTAssertEqual(block.declaration, "#if DEBUG")
  }
  
  func testSingleElseBlock() {
    let block = ConditionalCompilationBlock(directive: .else,
                                            condition: "DEBUG",
                                            range: 0..<1,
                                            preceedingBlocks: [])
    XCTAssertEqual(block.declaration, "#if DEBUG")
  }
  
  // MARK: - Preceeding blocks
  
  func testChainedBlocks() {
    /*
     #if DEBUG
     #elseif RELEASE
     #elseif TEST
     #else
     #endif
     */
    let ifBlock = ConditionalCompilationBlock(
      directive: .if,
      condition: "DEBUG",
      range: 0..<1,
      preceedingBlocks: [])
    let elseIfBlock1 = ConditionalCompilationBlock(
      directive: .elseif,
      condition: "RELEASE",
      range: 0..<1,
      preceedingBlocks: [ifBlock])
    let elseIfBlock2 = ConditionalCompilationBlock(
      directive: .elseif,
      condition: "TEST",
      range: 0..<1,
      preceedingBlocks: [ifBlock, elseIfBlock1])
    let elseBlock = ConditionalCompilationBlock(
      directive: .elseif,
      condition: nil,
      range: 0..<1,
      preceedingBlocks: [ifBlock, elseIfBlock1, elseIfBlock2])
    
    XCTAssertEqual(ifBlock.declaration, "#if DEBUG")
    XCTAssertEqual(elseIfBlock1.declaration, "#if RELEASE && !(DEBUG)")
    XCTAssertEqual(elseIfBlock2.declaration, "#if TEST && !(RELEASE) && !(DEBUG)")
    XCTAssertEqual(elseBlock.declaration, "#if !(TEST) && !(RELEASE) && !(DEBUG)")
  }
  
  func testAdjacentBlocks() {
    /*
     #if DEBUG
     #endif
     #if RELEASE
     #endif
     */
    let ifBlock1 = ConditionalCompilationBlock(
      directive: .if,
      condition: "DEBUG",
      range: 0..<1,
      preceedingBlocks: [])
    let endIfBlock1 = ConditionalCompilationBlock(
      directive: .endif,
      condition: nil,
      range: 0..<1,
      preceedingBlocks: [ifBlock1])
    let ifBlock2 = ConditionalCompilationBlock(
      directive: .if,
      condition: "RELEASE",
      range: 0..<1,
      preceedingBlocks: [ifBlock1, endIfBlock1])
    
    XCTAssertEqual(ifBlock2.declaration, "#if RELEASE")
  }
  
  func testNestedBlocks() {
    /*
     #if DEBUG
       #if RELEASE
         #if TEST
         #endif
       #endif
     #endif
     */
    let ifBlock1 = ConditionalCompilationBlock(
      directive: .if,
      condition: "DEBUG",
      range: 0..<1,
      preceedingBlocks: [])
    let ifBlock2 = ConditionalCompilationBlock(
      directive: .if,
      condition: "RELEASE",
      range: 0..<1,
      preceedingBlocks: [ifBlock1])
    let ifBlock3 = ConditionalCompilationBlock(
      directive: .if,
      condition: "TEST",
      range: 0..<1,
      preceedingBlocks: [ifBlock1, ifBlock2])
    
    XCTAssertEqual(ifBlock1.declaration, "#if DEBUG")
    XCTAssertEqual(ifBlock2.declaration, "#if RELEASE && DEBUG")
    XCTAssertEqual(ifBlock3.declaration, "#if TEST && RELEASE && DEBUG")
  }
}
