import XCTest
@testable import Random

final class randomTests: XCTestCase {
    func testExample() throws {
        // WHEN
        let date = Date.random()

        // THEN
        XCTAssertNotNil(date)
    }
}
