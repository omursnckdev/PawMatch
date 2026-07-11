import XCTest
@testable import PawMatch

@MainActor
final class DeleteAccountViewModelTests: XCTestCase {
    func testCannotDeleteUntilAcknowledged() {
        let vm = DeleteAccountViewModel(accountService: MockAccountService())
        XCTAssertFalse(vm.canDelete)
        vm.acknowledged = true
        XCTAssertTrue(vm.canDelete)
    }

    func testDeleteCallsServiceOnSuccess() async {
        let service = MockAccountService()
        let vm = DeleteAccountViewModel(accountService: service)
        vm.acknowledged = true

        let ok = await vm.deleteAccount()

        XCTAssertTrue(ok)
        XCTAssertEqual(service.deleteCallCount, 1)
        XCTAssertNil(vm.errorMessage)
    }

    func testDeleteSurfacesErrorOnFailure() async {
        let service = MockAccountService()
        service.error = NSError(domain: "test", code: 1)
        let vm = DeleteAccountViewModel(accountService: service)
        vm.acknowledged = true

        let ok = await vm.deleteAccount()

        XCTAssertFalse(ok)
        XCTAssertNotNil(vm.errorMessage)
    }
}
