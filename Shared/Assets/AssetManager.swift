import SwiftUI
import ValorantAPI
import UserDefault
import HandyOperators

@MainActor
final class AssetManager: ObservableObject {
	@Published private(set) var assets: AssetCollection?
	@Published private(set) var error: Error?
	private var isDownloading = false
	
	convenience init() {
		self.init(assets: Self.stored)
	}
	
	private init(assets: AssetCollection?) {
		_assets = .init(wrappedValue: assets)
		
		Task { await loadAssets() }
	}
	
	func loadAssets() async {
		guard !isDownloading else { return }
		isDownloading = true
		defer { isDownloading = false }
		
		self.error = nil
		do {
			assets = try await Self.loadAssets()
		} catch {
			self.error = error
		}
	}
	
	func reset() async {
		error = nil
		assets = nil
		Self.stored = nil
	}
	
	#if DEBUG
	static let forPreviews = AssetManager()
	static let mockEmpty = AssetManager(assets: nil)
	#endif
	
	static func loadAssets() async throws -> AssetCollection {
		let client = AssetClient.shared
		let version = try await client.getCurrentVersion()
		if let stored, stored.version == version, stored.language == client.language {
			return stored
		} else {
			return try await client.collectAssets(for: version)
			<- { Self.stored = $0 }
		}
	}
	
	@UserDefault("AssetManager.stored")
	fileprivate static var stored: AssetCollection?
}

extension AssetCollection: DefaultsValueConvertible {}

extension EnvironmentValues {
	var assets: AssetCollection? {
		get { self[Key.self] }
		set { self[Key.self] = newValue }
	}
	
	private enum Key: EnvironmentKey {
		#if WIDGETS
		@MainActor static let defaultValue: AssetCollection? = Managers.assets.assets
		#elseif DEBUG
		@MainActor static let defaultValue = isInSwiftUIPreview ? AssetManager.forPreviews.assets : nil
		#else
		@MainActor static let defaultValue: AssetCollection? = nil
		#endif
	}
}
