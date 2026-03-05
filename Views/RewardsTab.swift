//
//  RewardsTab.swift
//  ActivTimer (Rough Draft)
//
//  Created by Katelyn on 1/16/26.
//

import SwiftUI
import SwiftData
import Charts

struct RewardsTab: View {
    @Environment(\.modelContext) private var context
    @Query private var pointsList: [Points]
    @Query private var rewardsList: [Reward]
    @AppStorage("appThemeName") var appThemeName: String = "Default"

    @State private var showPointsChart: Bool = false
    @State private var recentlyAwarded: Set<DemoActivityKind> = []
    @State private var showingThemeAlert = false
    @State private var isCelebrating = false
    @State private var pendingThemeToApply: String? = nil

    // Computed property to get or create the single Points object
    private var currentPoints: Points {
        if let existing = pointsList.first { return existing }
        let newPoints = Points()
        context.insert(newPoints)
        try? context.save()
        return newPoints
    }

    private func updatePoints(by amount: Int) {
        currentPoints.total += amount
        saveChanges()
    }

    private func addScreenTimeMinutes(_ minutes: Int) {
        currentPoints.screenTimeBalanceMinutes += max(0, minutes)
        saveChanges()
    }

    enum DemoActivityKind: Hashable {
        case mindfulness
        case walkRunShort
        case walkRunLong
        case strengthShort
        case strengthLong
        case flexibilityShort
        case flexibilityLong
        case letterLegs
    }

    private func canReward(kind: DemoActivityKind) -> Bool {
        switch kind {
        case .mindfulness, .letterLegs, .walkRunShort, .walkRunLong,
             .strengthShort, .strengthLong, .flexibilityShort, .flexibilityLong:
            return true
        }
    }

    private func awardScreenTime(for kind: DemoActivityKind) {
        // No-op: Activity-based awards are handled exclusively by ActivitiesTab via PointsEngine
        // to avoid double-counting. RewardsTab should not grant points/minutes for activities.
    }

    private func seedDefaultRewardsIfNeeded() {
        if rewardsList.isEmpty {
            let r1 = Reward(title: "+15 minutes screen time", costPoints: 100, effect: .screenTime(minutes: 15))
            let r2 = Reward(title: "+25 minutes screen time", costPoints: 500, effect: .screenTime(minutes: 25))
            let r3 = Reward(title: "Change theme to Cosmic Orange", costPoints: 5, effect: .themeChange(themeName: "Cosmic Orange"))
            context.insert(r1)
            context.insert(r2)
            context.insert(r3)
            saveChanges()
        }
    }

    private func redeem(_ reward: Reward) {
        guard currentPoints.total >= reward.costPoints else { return }
        currentPoints.total -= reward.costPoints
        switch reward.effect {
        case .screenTime(let minutes):
            addScreenTimeMinutes(minutes)
        case .themeChange(let themeName):
            appThemeName = themeName ?? (appThemeName == "Default" ? "Alt" : "Default")
        }
        saveChanges()
    }

    private func saveChanges() {
        do { try context.save() } catch { print("Error saving points: \(error.localizedDescription)") }
    }

    //Cosmic orange theme modifier
    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if appThemeName == "Cosmic Orange" {
                        // Theme-enabled: let black show through; no blue overlay or material
                        Color.clear
                    } else {
                        Color.blue.opacity(0.15)
                            .overlay(
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .blur(radius: 8)
                                    .mask(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .white, location: 0.0),
                                                .init(color: .clear, location: 0.2),
                                                .init(color: .clear, location: 0.8),
                                                .init(color: .white, location: 1.0)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                    }
                }
                .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Rewards for doing your workout/mindfulness break. 🥇")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("Screen Time Bonus Points")
                            .font(.largeTitle)
                            .bold()

                        Text("\(currentPoints.total)")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.blue)

                        Text("Total Points Accumulated: \(currentPoints.screenTimeBalanceMinutes) min")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button {
                            showPointsChart = true
                        } label: {
                            Label("Points Breakdown", systemImage: "chart.bar.xaxis")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)

                        

                        Divider().padding(.vertical)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Rewards")
                                .font(.title2.bold())

                            // +15 minutes for 100 points
                            Button(action: {
                                if let reward = rewardsList.first(where: { $0.title == "+15 minutes screen time" && $0.costPoints == 100 }) {
                                    redeem(reward)
                                } else {
                                    let r = Reward(title: "+15 minutes screen time", costPoints: 100, effect: .screenTime(minutes: 15))
                                    context.insert(r)
                                    saveChanges()
                                    redeem(r)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "app.badge.clock")
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                        .symbolEffect(.bounce, options: .repeating, value: currentPoints.total >= 100)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Extra 15 Minutes")
                                            .font(.system(.subheadline, weight: .semibold).width(.expanded))
                                        Text("100 Points")
                                            .font(.system(.caption, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.quaternarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .disabled(currentPoints.total < 100)

                            // +25 minutes for 500 points
                            Button(action: {
                                if let reward = rewardsList.first(where: { $0.title == "+25 minutes screen time" && $0.costPoints == 500 }) {
                                    redeem(reward)
                                } else {
                                    let r = Reward(title: "+25 minutes screen time", costPoints: 500, effect: .screenTime(minutes: 25))
                                    context.insert(r)
                                    saveChanges()
                                    redeem(r)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "apps.iphone.badge.plus")
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                        .symbolEffect(.bounce, options: .repeating, value: currentPoints.total >= 500)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Extra 25 Minutes")
                                            .font(.system(.subheadline, weight: .semibold).width(.expanded))
                                        Text("500 Points")
                                            .font(.system(.caption, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.quaternarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .disabled(currentPoints.total < 500)

                            // Theme change to Cosmic Orange for 5 points
                            Button(action: {
                                // Find existing reward or create it
                                let reward: Reward
                                if let existing = rewardsList.first(where: { $0.title == "Change theme to Cosmic Orange" && $0.costPoints == 5 }) {
                                    reward = existing
                                } else {
                                    let r = Reward(title: "Change theme to Cosmic Orange", costPoints: 5, effect: .themeChange(themeName: "Cosmic Orange"))
                                    context.insert(r)
                                    saveChanges()
                                    reward = r
                                }

                                // Ensure enough points
                                guard currentPoints.total >= reward.costPoints else { return }

                                // Redeem, but don't auto-apply theme; show alert asking user
                                currentPoints.total -= reward.costPoints
                                saveChanges()

                                // Fire confetti celebration
                                isCelebrating = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    isCelebrating = false
                                }

                                // Trigger alert; remember the theme to offer applying now
                                pendingThemeToApply = "Cosmic Orange"
                                showingThemeAlert = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "iphone.gen3")
                                        .foregroundStyle(.orange)
                                        .frame(width: 24)
                                        .symbolEffect(.bounce, options: .repeating, value: currentPoints.total >= 5)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Cosmic Orange Theme")
                                            .font(.system(.subheadline, weight: .semibold).width(.expanded))
                                        Text("5 Points")
                                            .font(.system(.caption, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.quaternarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .disabled(currentPoints.total < 5)
                        }
                    }
                    .padding()
                }
                .coordinateSpace(name: "RewardsScrollSpace")
                
                // Confetti overlay matching ActivitiesTab
                ConfettiView(isAnimating: $isCelebrating)
                    .allowsHitTesting(false)
            }
            .navigationTitle("Rewards")
            .onAppear {
                if pointsList.isEmpty { _ = currentPoints }
                seedDefaultRewardsIfNeeded()
            }
            .sheet(isPresented: $showPointsChart) {
                PointsChartSheet()
            }
            .alert("Congratulations!", isPresented: $showingThemeAlert) {
                Button("Apply Now") {
                    if let theme = pendingThemeToApply {
                        appThemeName = theme
                    }
                    pendingThemeToApply = nil
                }
                Button("Later", role: .cancel) {
                    pendingThemeToApply = nil
                }
            } message: {
                Text("You redeemed the Cosmic Orange iPhone 17 Pro theme! Would you like to apply it right now? You can always change themes later in Settings.")
            }
        }
    }
}

private struct PointsChartSheet: View {
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Earning/Redeeming points")
                    .font(.title.bold())
                PointsChartView()
                    .frame(height: 200)
                    .padding()
                    .background(
                        Group {
                            if #available(iOS 18.0, *) {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Breakdown of points awarded from workouts/mindfulness breaks: ")
                        .font(.title.italic())
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Mindfulness break, meditations only: ")
                            Spacer()
                            Text("+5 pts")
                        }
                        HStack {
                            Text("Short workout, weights/gymnastics/yoga: ")
                            Spacer()
                            Text("+15 pts")
                        }
                        HStack {
                            Text("Long workouts, full yoga flows, runs, walks: ")
                            Spacer()
                            Text("+30 pts")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Text("Points are automatically awarded when you complete a screen time break from the Activities tab. 1 point per minute. ")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PointsChartView: View {
    @Query private var pointsList: [Points]

    struct Sample: Identifiable { let id = UUID(); let day: Int; let value: Int }

    private var samples: [Sample] {
        let total = pointsList.first?.total ?? 0
        // Intervals of data
        let base = max(0, total - 60)
        return [0, 15, 30, 45, 60].map { step in
            Sample(day: step, value: min(base + step, total))
        }
    }

    var body: some View {
        if samples.isEmpty {
            Text("Data unavailable. Please complete a workout or mindfulness break first.")
                .foregroundStyle(.secondary)
        } else {
            Chart(samples) { s in
                LineMark(
                    x: .value("Day", s.day),
                    y: .value("Points", s.value)
                )
                PointMark(
                    x: .value("Day", s.day),
                    y: .value("Points", s.value)
                )
            }
        }
    }
}
 
#Preview {
    ContentView()
}

