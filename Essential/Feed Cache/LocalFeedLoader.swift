//
//  LocalFeedLoader.swift
//  Essential
//
//  Created by lakshman-7016 on 20/06/21.
//

import Foundation

public class LocalFeedLoader {
	private let store: FeedStore
	private let currentDate: () -> Date

	public typealias SaveResult = Error?

	public init(store: FeedStore, currentDate: @escaping () -> Date) {
		self.store = store
		self.currentDate = currentDate
	}

	public func save(_ feed: [FeedImage], completion: @escaping (SaveResult) -> Void) {
		store.deleteCachedFeed { [weak self] error in
			guard let self = self else { return }

			if let cacheDeletionError = error {
				completion(cacheDeletionError)
			} else {
				self.cache(feed, with: completion)
			}
		}
	}

	public func load(completion: @escaping (LoadFeedResult) -> Void) {
		store.retrieve() { retrievedResult in
			switch retrievedResult {
			case .empty:
				completion(.success([]))
			case let .found(feed, _):
				completion(.success(feed.toModels()))
			case let .failure(error):
				completion(.failure(error))
			}
		}
	}

	private func cache(_ feed: [FeedImage], with completion: @escaping (SaveResult) -> Void) {
		store.insertFeed(feed.toLocal(), timeStamp: currentDate()) { [weak self] error in
			guard self != nil else { return }
			completion(error)
		}
	}
}

extension Array where Element == FeedImage {
	func toLocal() -> [LocalFeedImage] {
		map { LocalFeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.url) }
	}
}

extension Array where Element == LocalFeedImage {
	func toModels() -> [FeedImage] {
		map { FeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.url) }
	}
}
