import XCTest

@testable import SportCore

final class VaultAccessGateTests: XCTestCase {
  func testBackgroundAndOldCompletionsCannotUnlock() throws {
    var gate = VaultAccessGate()
    let old = try XCTUnwrap(gate.begin())
    gate.cover()
    gate.lock()
    XCTAssertFalse(gate.accepts(old))
    XCTAssertFalse(gate.complete(old))
    XCTAssertEqual(gate.phase, .locked)
    gate.foreground()
    let current = try XCTUnwrap(gate.begin())
    XCTAssertFalse(gate.complete(old))
    gate.fail(old)
    XCTAssertEqual(gate.phase, .authenticating)
    XCTAssertTrue(gate.complete(current))
  }

  func testFaceIDInactivePhaseCoversWithoutCancellingAuthentication() throws {
    var gate = VaultAccessGate()
    let token = try XCTUnwrap(gate.begin())
    XCTAssertNil(gate.begin())
    gate.cover()
    XCTAssertTrue(gate.covered)
    XCTAssertTrue(gate.complete(token))
    XCTAssertTrue(gate.covered, "Authentication alone must not unmask an inactive scene")
    gate.foreground()
    XCTAssertFalse(gate.covered)
    gate.lock()
    XCTAssertEqual(gate.phase, .locked)
    XCTAssertFalse(gate.complete(token))
  }
}
