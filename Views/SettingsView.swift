//
//  SwiftUIView.swift
//  ActivTimer (Rough Draft)
//
//  Created by Katelyn on 1/16/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    //ALL SETTINGS.
    @AppStorage("disableAlarmSound") private var disableAlarmSound: Bool = false
    @AppStorage("appThemeName") private var appThemeName: String = "Default"
    @AppStorage("cosmicOrangeUnlocked") private var cosmicOrangeUnlocked: Bool = false
    @AppStorage("bedtimeEnabled") private var bedtimeEnabled: Bool = false
    @AppStorage("bedtimeStart") private var bedtimeStart: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @AppStorage("bedtimeEnd") private var bedtimeEnd: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    
    @State private var showResetConfirm: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query private var pointsList: [Points]
    
    //Cosmic Orange theme
    private var isCosmicOrange: Bool { appThemeName == "Cosmic Orange" }
    private var themeTint: Color { isCosmicOrange ? .orange : .accentColor }
    private var themeForeground: Color { isCosmicOrange ? .orange : .primary }
    
#if canImport(UIKit)
    private func applyAppIcon(for theme: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        Task { @MainActor in
            do {
                if theme == "Cosmic Orange" {
                    try await UIApplication.shared.setAlternateIconName("activtimer_filledicon")
                } else {
                    try await UIApplication.shared.setAlternateIconName(nil)
                }
            } catch {
                print("error: \(error)")
            }
        }
    }
#endif
    
    var body: some View {
        
        NavigationStack {
            ZStack {
                (isCosmicOrange ? Color.black : Color.clear)
                    .ignoresSafeArea()
                
                Form {
                    Section("Alerts") {
                        Toggle(isOn: $disableAlarmSound) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Disable Alarm Sound")
                                    .font(.headline)
                                Text("When enabled, the app will use haptics instead of sound for break alerts (which will still go off quietly in Silent mode).")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            
                        }
                    }
                    
                    Section("Appearance") {
                        Toggle(isOn: Binding(
                            get: { appThemeName == "Cosmic Orange" },
                            set: { newValue in
                                if !cosmicOrangeUnlocked {
                                    cosmicOrangeUnlocked = true
                                }
                                appThemeName = newValue ? "Cosmic Orange" : "Default"
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cosmic Orange iPhone 17 Pro Theme")
                                    .font(.headline)
                                Text(cosmicOrangeUnlocked
                                     ? "Switch to a bold, warm orange accent across the app, inspired by the iPhone 17 Pro. You can also unlock and apply this from Rewards."
                                     : "Unlock this stunning, iPhone 17 Pro inspired theme from Rewards to enable it here.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                }
                            }
                        }
                        
                        Section("Do Not Disturb") {
                            Toggle(isOn: $bedtimeEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Disable Alarm During Bedtime/Do Not Disturb.")
                                        .font(.headline)
                                    Text("Silence break alarms during your bedtime or desired focus window.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if bedtimeEnabled {
                                DatePicker("Start", selection: $bedtimeStart, displayedComponents: [.hourAndMinute])
                                DatePicker("End", selection: $bedtimeEnd, displayedComponents: [.hourAndMinute])
                            }
                        }
                        
                        Section("Reset All Timers and Points") {
                            Button(role: .destructive) {
                                showResetConfirm = true
                            } label: {
                                Label {
                                    Text("Reset Break Timer & Clear Points")
                                } icon: {
                                    Image(systemName: "restart.circle.fill").foregroundStyle(.red)
                                }
                            }
                            .alert("Reset all timers and erase points?", isPresented: $showResetConfirm) {
                                Button("Reset", role: .destructive) {
                                    // 1) Reset the base countdown back to 15 seconds for demo reasons.
                                    UserDefaults.standard.set(15, forKey: "nextCountdownBaseSeconds")
                                    // 2) Erase all points from SwiftData
                                    for p in pointsList {
                                        p.total = 0
                                        p.screenTimeBalanceMinutes = 0
                                    }
                                    try? modelContext.save()
                                    // 3) Notify HomeTab to reset its running timer immediately
                                    NotificationCenter.default.post(name: Notification.Name("ActivityCompletedAwardedTime"), object: nil)
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text("WARNING! This will set the break timer back to 15 seconds and erase your rewards points (including bonus points from activities). This cannot be undone.")
                            }
                        }
                        
                        Section("Credits") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ActivTimer: Make Screen Time Work for You The Proper, Ethical Way.")
                                    .font(.headline)
                                Image( "ActivTimer_CosmicOrangeIcon") // app icon as logo of the app
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Spacer()
                                
                                Text("Made with ❤️ in SwiftUI by Katelyn Hua, for the 2026 Swift Student Challenge.")
                                    .font(.headline)
                                    .foregroundColor(isCosmicOrange ? .orange : .indigo)
                                Text("App Icon composed with SF Symbols, remixed in AutoCAD/Inkscape and then edited in Icon Composer by Katelyn Hua.")
                                    .font(.headline)
                                    .foregroundColor(isCosmicOrange ? .orange : .indigo)
                            }
                        }
                    }
                }
                .tint(themeTint)
                .onAppear {
                    // Ensure bedtime is off by default for demo
                    if bedtimeEnabled { bedtimeEnabled = false }
#if canImport(UIKit)
                    UIApplication.shared.isIdleTimerDisabled = true
#endif
                }
                .onAppear {
#if canImport(UIKit)
                    applyAppIcon(for: appThemeName)
#endif
                }
                .onDisappear {
#if canImport(UIKit)
                    UIApplication.shared.isIdleTimerDisabled = false
#endif
                }
                .navigationTitle("Settings")
                .onChange(of: appThemeName) { _, newValue in
#if canImport(UIKit)
                    applyAppIcon(for: newValue)
#endif
                }
            }
        }
    }
    

#Preview {
    SettingsView()
}

