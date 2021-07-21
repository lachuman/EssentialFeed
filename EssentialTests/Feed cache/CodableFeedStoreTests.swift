//
//  CodableFeedStoreTests.swift
//  EssentialTests
//
//  Created by lakshman-7016 on 07/07/21.
//

import XCTest
import Essential

class CodableFeedStoreTests: XCTestCase, FailableFeedStore {

	override func setUp() {
		super.setUp()

		setUpEmptyStoreState()
	}

	override func tearDown() {
		super.tearDown()

		undoStoreSideEffects()
	}

	func test_retrieve_deliversEmptyOnEmptyCache() {
		let sut = makeSUT()

		expect(sut, toRetrieve: .empty)
	}

	func test_retrieve_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		expect(sut, toRetrieveTwice: .empty)
	}

	func test_retrieve_deliversFoundValuesOnNonEmptyCache() {
		let sut = makeSUT()
		let feed = uniqueImageFeed().locals
		let timestamp = Date()

		insert((feed, timestamp), to: sut)

		expect(sut, toRetrieve: .found(feed: feed, timeStamp: timestamp))
	}

	func test_retrieve_hasNoSideEffectsOnNonEmptyCache() {
		let sut = makeSUT()
		let feed = uniqueImageFeed().locals
		let timestamp = Date()

		insert((feed, timestamp), to: sut)

		expect(sut, toRetrieveTwice: .found(feed: feed, timeStamp: timestamp))
	}

	func test_retrieve_deliversFailureOnRetrievalError() {
		let storeURL = testSpecificStoreURL()
		let sut = makeSUT(storeURL: storeURL)

		try! "invalid data".write(to: storeURL, atomically: false, encoding: .utf8)

		expect(sut, toRetrieve: .failure(anyNSError()))
	}

	func test_retrieve_hasNoSideEffectsOnFailure() {
		let storeURL = testSpecificStoreURL()
		let sut = makeSUT(storeURL: storeURL)

		try! "invalid data".write(to: storeURL, atomically: false, encoding: .utf8)

		expect(sut, toRetrieveTwice: .failure(anyNSError()))
	}

	func test_insert_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		let insertionError = insert((uniqueImageFeed().locals, Date()), to: sut)

		XCTAssertNil(insertionError, "successfull insertion to cache")
	}

	func test_insert_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		insert((uniqueImageFeed().locals, Date()), to: sut)
		let insertionError = insert((uniqueImageFeed().locals, Date()), to: sut)

		XCTAssertNil(insertionError, "successfull insertion to cache")
	}

	func test_insert_overridesPreviouslyInsertedCacheValues() {
		let sut = makeSUT()

		insert((uniqueImageFeed().locals, Date()), to: sut)

		let latestFeed = uniqueImageFeed().locals
		let latestTimestamp = Date()
		insert((latestFeed, latestTimestamp), to: sut)

		expect(sut, toRetrieve: .found(feed: latestFeed, timeStamp: latestTimestamp))
	}

	func test_insert_deliversErrorOnInsertionError() {
		let invalidStoreURL = URL(string: "invalid://store-url")!
		let sut = makeSUT(storeURL: invalidStoreURL)
		let feed = uniqueImageFeed().locals
		let timeStamp = Date()

		let insertionError = insert((feed, timeStamp), to: sut)

		XCTAssertNotNil(insertionError, "Expected Cache insertion to fail with an error")
	}

	func test_insert_HasNoSideEffectsOnInsertionError() {
		let invalidStoreURL = URL(string: "invalid://store-url")!
		let sut = makeSUT(storeURL: invalidStoreURL)
		let feed = uniqueImageFeed().locals
		let timeStamp = Date()

		insert((feed, timeStamp), to: sut)

		expect(sut, toRetrieve: .empty)
	}

	func test_delete_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		let deletionError = deleteCache(from: sut)

		XCTAssertNil(deletionError, "Expected cache deletion successfully.")
	}

	func test_delete_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		deleteCache(from: sut)

		expect(sut, toRetrieve: .empty)
	}

	func test_delete_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		insert((uniqueImageFeed().locals, Date()), to: sut)
		let deletionError = deleteCache(from: sut)

		XCTAssertNil(deletionError, "Expected cache deletion successfully.")
	}

	func test_delete_emptiesPreviouslyInsertedCache() {
		let sut = makeSUT()

		insert((uniqueImageFeed().locals, Date()), to: sut)
		deleteCache(from: sut)

		expect(sut, toRetrieve: .empty)
	}

	func test_delete_deliversErrorOnDeletionError() {
		let noDeletePermissionURL = cachesDirectory()
		let sut = makeSUT(storeURL: noDeletePermissionURL)

		let deletionError = deleteCache(from: sut)

		XCTAssertNotNil(deletionError, "Expected deletion to complete with error")
	}

	func test_delete_hasNoSideEffectsOnDeletionError() {
		let noDeletePermissionURL = cachesDirectory()
		let sut = makeSUT(storeURL: noDeletePermissionURL)

		deleteCache(from: sut)

		expect(sut, toRetrieve: .empty)
	}

	func test_storeSideEffects_runSerially() {
		let sut = makeSUT()
		var completedOperationsInOrder = [XCTestExpectation]()

		let op1 = expectation(description: "Operation 1")
		sut.insertFeed(uniqueImageFeed().locals, timeStamp: Date()) { _ in
			completedOperationsInOrder.append(op1)
			op1.fulfill()
		}

		let op2 = expectation(description: "Operation 2")
		sut.deleteCachedFeed() { _ in
			completedOperationsInOrder.append(op2)
			op2.fulfill()
		}

		let op3 = expectation(description: "Operation 3")
		sut.retrieve() { _ in
			completedOperationsInOrder.append(op3)
			op3.fulfill()
		}

		waitForExpectations(timeout: 5.0)

		XCTAssertEqual(completedOperationsInOrder, [op1, op2, op3], "Expected side-effects to run serially but operations finished in the wrong order")
	}

	// MARK: - Helpers

	private func makeSUT(storeURL: URL? = nil,file: StaticString = #filePath, line: UInt = #line) -> FeedStore {
		let sut = CodableFeedStore(storeURL: storeURL ?? self.testSpecificStoreURL())
		trackForMemoryLeaks(sut, file: file, line: line)
		return sut
	}

	@discardableResult
	private func deleteCache(from sut: FeedStore) -> Error? {
		var deletionError: Error?
		let exp = expectation(description: "Wait for deletion completion.")
		sut.deleteCachedFeed() { error in
			deletionError = error
			exp.fulfill()
		}
		wait(for: [exp], timeout: 10.0) // Reduce the time to 1.0 seconds
		return deletionError
	}

	@discardableResult
	func insert(_ cache: (feed: [LocalFeedImage], timeStamp: Date), to sut: FeedStore) -> Error? {
		var insertionError: Error?
		let exp = expectation(description: "Wait for cache retrieval")
		sut.insertFeed(cache.feed, timeStamp: cache.timeStamp) { error in
			insertionError = error
			exp.fulfill()
		}
		wait(for: [exp], timeout: 1.0)
		return insertionError
	}

	func expect(_ sut: FeedStore, toRetrieveTwice expectedResult: RetrieveCachedFeedResult, file: StaticString = #filePath, line: UInt = #line) {
		expect(sut, toRetrieve: expectedResult)
		expect(sut, toRetrieve: expectedResult)
	}

	func expect(_ sut: FeedStore, toRetrieve expectedResult: RetrieveCachedFeedResult, file: StaticString = #filePath, line: UInt = #line) {
		let exp = expectation(description: "Wait for cache retrieval")

		sut.retrieve() { receivedResult in
			switch (expectedResult, receivedResult) {
			case (.empty, .empty),
				 (.failure, .failure):
				break

			case let (.found(expectedFeed, expectedTimeStamp), .found(receivedFeed, receivedTimeStamp)):
				XCTAssertEqual(expectedFeed, receivedFeed)
				XCTAssertEqual(expectedTimeStamp, receivedTimeStamp)

			default:
				XCTFail("Expected \(expectedResult), got \(receivedResult) instead")
			}
			exp.fulfill()
		}

		wait(for: [exp], timeout: 1.0)
	}

	private func cachesDirectory() -> URL {
		return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
	}

	func setUpEmptyStoreState() {
		self.deleteStoreArtifacts()
	}

	func undoStoreSideEffects() {
		self.deleteStoreArtifacts()
	}

	func deleteStoreArtifacts() {
		try? FileManager.default.removeItem(at: self.testSpecificStoreURL())
	}

	private func testSpecificStoreURL() -> URL {
		return self.cachesDirectory().appendingPathComponent("\(type(of: self)).store")
	}
}
