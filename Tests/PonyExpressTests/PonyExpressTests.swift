import XCTest
@testable import PonyExpress

final class PonyExpressTests: XCTestCase {
    func testExample() throws {
        let ponyExpress = PonyExpress<UserInfo>()
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        var received = 0
        let graph = TestObserver()
        graph.observe = { letter in
            guard case .specificInfo(let objectKeys) = letter.contents else {
                XCTFail()
                return
            }
            XCTAssertEqual(letter.name, .NSCalendarDayChanged)
            XCTAssertNil(letter.sender)
            XCTAssertEqual(objectKeys, Set([12, 13]))
            received += 1
        }

        ponyExpress.add(name: .NSCalendarDayChanged, observer: graph)
        ponyExpress.post(name: .NSCalendarDayChanged, sender: nil, contents: .specificInfo(objectKeys: Set([12, 13])))
        XCTAssertEqual(received, 1)
    }

    func testAsync() throws {
        let ponyExpress = PonyExpress<UserInfo>()
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        let queue = DispatchQueue(label: "any.queue")
        var received = 0
        let graph = TestObserver()
        graph.observe = { letter in
            guard case .specificInfo(let objectKeys) = letter.contents else {
                XCTFail()
                return
            }
            XCTAssertEqual(letter.name, .NSCalendarDayChanged)
            XCTAssertNil(letter.sender)
            XCTAssertEqual(objectKeys, Set([12, 13]))
            received += 1
        }

        ponyExpress.add(name: .NSCalendarDayChanged, observer: graph, queue: queue)
        ponyExpress.post(name: .NSCalendarDayChanged, sender: nil, contents: .specificInfo(objectKeys: Set([12, 13])))

        XCTAssertEqual(received, 0)

        let exp = expectation(description: "wait for notification")
        queue.async {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)

        XCTAssertEqual(received, 1)
    }
}
