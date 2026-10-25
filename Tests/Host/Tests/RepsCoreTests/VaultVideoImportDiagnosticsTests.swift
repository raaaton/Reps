import XCTest

@testable import RepsCore

final class VaultVideoImportDiagnosticsTests: XCTestCase, @unchecked Sendable {
  func testOriginalFailureSurvivesProviderWrapping() async {
    let diagnostics = VaultVideoImportDiagnostics()
    await diagnostics.record("Duration validation failed: source 48 s, output 24 s; V74.")
    await diagnostics.record("CoreTransferable wrapper code 0")
    let report = await diagnostics.report
    XCTAssertEqual(report, "Duration validation failed: source 48 s, output 24 s; V74.")
  }

  func testEachImportHasItsOwnReportAndProviderOnlyFailuresRemainVisible() async {
    let first = VaultVideoImportDiagnostics()
    let second = VaultVideoImportDiagnostics()
    await first.record("Old import failure")
    let empty = await second.report
    XCTAssertNil(empty)
    await second.record("Photos provider failed: NSItemProviderErrorDomain -1000")
    let firstReport = await first.report
    let secondReport = await second.report
    XCTAssertEqual(firstReport, "Old import failure")
    XCTAssertEqual(secondReport, "Photos provider failed: NSItemProviderErrorDomain -1000")
  }
}
