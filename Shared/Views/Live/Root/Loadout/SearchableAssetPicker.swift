import SwiftUI
import ValorantAPI

struct SearchableAssetPicker<Item: SearchableAsset, RowContent: View>: View {
	var allItems: [Item.ID: Item]
	var ownedItems: Set<Item.ID>
	@ViewBuilder var rowContent: (Item) -> RowContent
	
	@State private var search = ""
	
	@Environment(\.assets) private var assets
	
	var body: some View {
		let lowerSearch = search.lowercased()
		let results = ownedItems
			.lazy
			.compactMap { allItems[$0] }
			.filter { $0.searchableText.lowercased().hasPrefix(lowerSearch) }
			.sorted(on: \.searchableText)
		
		List {
			Section {
				ForEach(results) { item in
					rowContent(item)
				}
			} footer: {
				VStack(alignment: .leading) {
					Text("\(ownedItems.count)/\(allItems.count) owned")
					let missing = ownedItems.lazy.filter { allItems[$0] == nil }.count
					if missing > 0 {
						Text("\(missing) hidden due to outdated assets")
					}
				}
			}
		}
		.searchable(text: $search)
	}
}

struct SimpleSearchableAssetPicker<Item: SimpleSearchableAsset, RowContent: View>: View {
	var inventory: Inventory
	@Binding var selected: Item.ID
	@ViewBuilder var rowContent: (Item) -> RowContent
	
	@Environment(\.assets) private var assets
	
	var body: some View {
		if let assets = assets {
			SearchableAssetPicker(
				allItems: assets[keyPath: Item.assetPath],
				ownedItems: inventory[keyPath: Item.inventoryPath]
			) { item in
				Button {
					selected = item.id
				} label: {
					HStack {
						rowContent(item)
							.foregroundColor(.primary)
						Spacer()
						Image(systemName: "checkmark")
							.opacity(selected == item.id ? 1 : 0)
					}
				}
			}
		} else {
			Text("Assets not loaded!")
				.foregroundColor(.secondary)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}
}

protocol SearchableAsset: Identifiable {
	var searchableText: String { get }
}

protocol SimpleSearchableAsset: SearchableAsset {
	static var assetPath: KeyPath<AssetCollection, [ID: Self]> { get }
	static var inventoryPath: KeyPath<Inventory, Set<ID>> { get }
}