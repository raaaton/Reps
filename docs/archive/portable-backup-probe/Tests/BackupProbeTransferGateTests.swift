import XCTest

@testable import SportCore

final class BackupProbeTransferGateTests: XCTestCase {
  func testOnlyCurrentVisibleActivePresentationIsAccepted() throws {
    var gate = BackupProbeTransferGate()
    XCTAssertNil(gate.begin())
    gate.open(active: true)
    let first = try XCTUnwrap(gate.begin())
    XCTAssertTrue(gate.accepts(first))
    let second = try XCTUnwrap(gate.begin())
    XCTAssertFalse(gate.accepts(first))
    XCTAssertTrue(gate.finish(second))
    XCTAssertFalse(gate.finish(second))
  }
  func testInactiveInvalidatesOldCallbackEvenAfterReturning() throws {
    var gate = BackupProbeTransferGate()
    gate.open(active: true)
    let old = try XCTUnwrap(gate.begin())
    gate.setActive(false)
    XCTAssertFalse(gate.accepts(old))
    XCTAssertNil(gate.begin())
    gate.setActive(true)
    XCTAssertFalse(gate.accepts(old))
    let new = try XCTUnwrap(gate.begin())
    XCTAssertTrue(gate.accepts(new))
  }
  func testCloseAndReopenNeverAcceptsPreviousCallback() throws {
    var gate = BackupProbeTransferGate()
    gate.open(active: true)
    let old = try XCTUnwrap(gate.begin())
    gate.close()
    XCTAssertFalse(gate.accepts(old))
    gate.open(active: true)
    let new = try XCTUnwrap(gate.begin())
    XCTAssertFalse(gate.finish(old))
    XCTAssertTrue(gate.finish(new))
  }
}
