import SwiftUI
import ValorantAPI

struct AgentSelectView: View {
	@Binding var pregameInfo: LivePregameInfo
	let user: User
	let inventory: Inventory
	
	var body: some View {
		ZStack(alignment: .top) {
			ScrollView {
				VStack(spacing: 0) {
					hero
					
					VStack {
						VStack {
							ForEach(pregameInfo.team.players) { player in
								PlayerView(player: player, user: user)
							}
						}
						.padding()
						
						Divider()
						
						HStack {
							lockInIndicators(
								count: pregameInfo.team.players.count,
								lockCount: pregameInfo.team.players.filter(\.isLockedIn).count,
								shouldReverse: false
							)
							.foregroundColor(.valorantBlue)
							
							Spacer()
							
							lockInIndicators(
								count: pregameInfo.enemyTeamSize,
								lockCount: pregameInfo.enemyTeamLockCount,
								shouldReverse: false
							)
							.foregroundColor(.valorantRed)
							.environment(\.layoutDirection, .rightToLeft)
							//.scaleEffect(x: -1, y: 1)
						}
						.padding()
						
						Divider()
						
						AgentPickerView(pregameInfo: $pregameInfo, user: user, inventory: inventory)
					}
				}
			}
			
			infoBox
				.padding()
		}
	}
	
	@ViewBuilder
	private func lockInIndicators(count: Int, lockCount: Int, shouldReverse: Bool) -> some View {
		HStack {
			ForEach(0..<count) { index in
				if index < lockCount {
					Image(systemName: "lock")
				} else {
					Image(systemName: "lock.open")
						.foregroundStyle(.secondary)
				}
			}
		}
		.symbolVariant(.fill)
	}
	
	@ViewBuilder
	private var hero: some View {
		MapImage.splash(pregameInfo.mapID)
			.aspectRatio(contentMode: .fill)
			.frame(height: 150)
			.clipped()
			// TODO: this doesn't do anything—probably a bug?
			//.ignoresSafeArea()
			.overlay(MapImage.Label(mapID: pregameInfo.mapID).padding(6))
	}
	
	@ViewBuilder
	private var infoBox: some View {
		VStack(spacing: 10) {
			if let queueID = pregameInfo.queueID {
				Text(queueID.name)
					.fontWeight(.medium)
					.foregroundStyle(.secondary)
			}
			
			Group {
				if pregameInfo.state == .provisioned {
					Text("Game Started")
				} else {
					let remainingSeconds = Int(pregameInfo.timeRemainingInPhase.rounded())
					Label("\(remainingSeconds)", systemImage: "timer")
						.monospacedDigit()
				}
			}
			.font(.title2.weight(.bold))
			.foregroundStyle(.primary)
			
			Text("\(pregameInfo.team.id.rawID) Team")
				.foregroundColor(pregameInfo.team.id.color)
		}
		.padding()
		.background(Material.thin)
		.cornerRadius(8)
		.shadow(radius: 10)
	}
	
	struct PlayerView: View {
		let player: LivePregameInfo.PlayerInfo
		let user: User
		
		@State var playerUser: User?
		@State var summary: CompetitiveSummary?
		@Environment(\.assets) private var assets
		
		var body: some View {
			let relativeColor = player.id == user.id ? Color.valorantSelf : .valorantBlue
			let isLockedIn = player.isLockedIn
			let iconSize = 48.0
			
			HStack {
				Group {
					if let agentID = player.agentID {
						AgentImage.displayIcon(agentID)
							.dynamicallyStroked(radius: 1.5, color: .white)
					} else {
						Image(systemName: "questionmark")
							.font(.system(size: iconSize / 2, weight: .bold))
							.foregroundColor(.white)
							.opacity(0.25)
							.blendMode(.plusLighter)
					}
				}
				.frame(width: iconSize, height: iconSize)
				.mask(Circle())
				.padding(isLockedIn ? 1 : 0)
				.background(
					Circle()
						.fill(relativeColor)
						.opacity(isLockedIn ? 0.5 : 0.25)
						.padding(2)
				)
				.padding(2)
				.overlay(
					Circle()
						.strokeBorder(relativeColor, lineWidth: isLockedIn ? 2 : 1)
						.opacity(isLockedIn ? 1 : 0.75)
				)
				.padding(isLockedIn ? 0 : 1) // constant size
				
				VStack(alignment: .leading, spacing: 4) {
					if !player.identity.isIncognito, let playerUser = playerUser {
						HStack {
							Text(playerUser.gameName)
							Text("#\(playerUser.tagLine)")
								.foregroundColor(.secondary)
						}
					}
					
					if isLockedIn {
						let agentName = assets?.agents[player.agentID!]?.displayName
						Text(agentName ?? "Unknown Agent!")
							.fontWeight(.semibold)
					} else {
						Text("Picking…")
							.foregroundColor(.secondary)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				
				if player.id != user.id, let playerUser = playerUser {
					NavigationLink(destination: UserView(for: playerUser)) {
						Image(systemName: "person.crop.circle.fill")
							.padding(.horizontal, 4)
					}
				}
				
				RankInfoView(summary: summary)
					.frame(width: iconSize, height: iconSize)
			}
			.accentColor(relativeColor)
			.withLocalData($playerUser) { $0.user(for: player.id) }
			.withLocalData($summary) { $0.competitiveSummary(for: player.id) }
			.valorantLoadTask {
				try await LocalDataProvider.shared.fetchCompetitiveSummary(for: player.id, using: $0)
			}
		}
	}
}

#if DEBUG
struct AgentSelectView_Previews: PreviewProvider {
	static var previews: some View {
		AgentSelectView(
			pregameInfo: .constant(PreviewData.pregameInfo),
			user: PreviewData.user,
			inventory: PreviewData.inventory
		)
		.navigationTitle("Agent Select")
		.withToolbar(allowLargeTitles: false)
		.inEachColorScheme()
		.inEachOrientation()
	}
}
#endif
