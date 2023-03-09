import SwiftUI
import WidgetKit
import ValorantAPI

protocol TimelineEntryView: View {
	associatedtype Value: FetchedTimelineValue
	associatedtype Intent: FetchingIntent
	associatedtype ValueView: View
	
	typealias Entry = FetchedTimelineEntry<Value, Intent>
	
	var entry: Entry { get }
	
	@ViewBuilder
	func contents(for value: Value) -> ValueView
}

extension TimelineEntryView {
	var body: some View {
		Group {
			switch entry.info {
			case .success(let info):
				contents(for: info)
			case .failure(let error):
				VStack(spacing: 8) {
					Text(error.localizedDescription)
					
					Text("\(Image(systemName: "arrow.clockwise")) \(entry.nextRefresh(), format: .dateTime.hour().minute())")
						.imageScale(.small)
				}
				.font(.caption)
				.multilineTextAlignment(.center)
				.foregroundColor(.secondary)
				.padding()
			}
		}
		.accentColor(Color("AccentColor"))
		.widgetURL(entry.link.makeURL())
	}
}

struct FetchedTimelineEntry<Value: FetchedTimelineValue, Intent: FetchingIntent>: TimelineEntry {
	var date = Date()
	var info: Result<Value, Error>
	var configuration = Intent()
	var link = WidgetLink()
	
	func nextRefresh() -> Date {
		do {
			return try info.get().nextRefresh
		} catch APIError.rateLimited(let retryAfter) {
			return .init(timeIntervalSinceNow: .init(retryAfter ?? 60))
		} catch APIError.sessionResumptionFailure(let error) where error is URLError {
			return .init(timeIntervalSinceNow: 120) // can't fallthrough in catch
		} catch is URLError {
			return .init(timeIntervalSinceNow: 120) // likely connection failure; retry when connection is likely to be back
		} catch is APIError {
			// TODO: trigger refresh from the app when this fails? might be hard to detect, but it might also be fine to just refresh on launch?
			return .init(timeIntervalSinceNow: 3600)
		} catch {
			return .init(timeIntervalSinceNow: 300) // decent default timeout
		}
	}
}

protocol FetchedTimelineValue {
	var nextRefresh: Date { get }
}

struct TimelineEntryView_Previews: PreviewProvider {
	static var previews: some View {
		Group {
			MockEntryView(entry: .init(
				info: .failure(StoreEntryProvider.UpdateError.unknownOffer)
			))
			.previewDisplayName("No Account")
			
			MockEntryView(entry: .init(
				info: .failure(APIError.rateLimited(retryAfter: 30))
			))
			.previewDisplayName("Rate Limited")
			
			MockEntryView(entry: .init(
				info: .failure(APIError.sessionResumptionFailure(URLError(.notConnectedToInternet)))
			))
			.previewDisplayName("Other Error")
		}
		.previewContext(WidgetPreviewContext(family: .systemSmall))
	}
	
	struct MockEntryView: TimelineEntryView {
		var entry: StoreEntryProvider.Entry
		
		func contents(for value: StorefrontInfo) -> some View {
			Text("It works!")
		}
	}
}
