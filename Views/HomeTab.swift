//
//  SwiftUIView.swift
//  ActivTimer (Rough Draft)
//
//  Created by Katelyn on 1/15/26.
//

import SwiftUI
import Combine
import AVFoundation
import AudioToolbox
import UIKit
import CoreHaptics
import SwiftData
import UserNotifications

struct HomeTab: View {
    @Environment(\.modelContext) private var context
    @Query private var pointsList: [Points]
    
    // Store total seconds in persistent storage
    @AppStorage("totalSeconds") private var totalSeconds: Int = 0
    @AppStorage("disableAlarmSound") private var disableAlarmSound: Bool = false
    @AppStorage("nextCountdownBaseSeconds") private var nextCountdownBaseSeconds: Int = 15
    @AppStorage("appThemeName") private var appThemeName: String = "Default"
    
    //Tracking screen time continously
    @State private var isTracking = false
    @State private var timer: Timer? = nil
    @State private var selectedTab: Tabs = .home
    
    @State private var searchString = ""
    @State private var showingAlert = false
    
    // Countdown timer @States.
    // Initial countdown duration in seconds (e.g., 1 hour = 3600)
    @State private var countdownSeconds: Int = 15 // initialized from nextCountdownBaseSeconds onAppear
    @State private var breakSeconds: Int = 0
    @State private var isCountingDown = true
    @State private var timerCancellable: AnyCancellable?
    @State private var isBreakAlertPresented: Bool = false
    @State private var showSkipExtendAlert: Bool = false
    @State private var navigateToActivities: Bool = false
    
    // New toast state for bonus minutes redeemed.
    @State private var showBonusToast = false
    @State private var lastAppliedBonusMinutes: Int = 0
    
    //MARK: ALARM Sounds and Haptics
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var breakSystemSoundID: SystemSoundID = 0
    @State private var engine: CHHapticEngine?
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }
    
    private func applyAvailableBonusMinutes() {
        guard let points = pointsList.first else { return }
        let bonusMinutes = max(0, points.screenTimeBalanceMinutes)
        guard bonusMinutes > 0 else { return }
        // Add to countdown (seconds)
        countdownSeconds += bonusMinutes * 60
        // Consume the minutes so they are not reapplied repeatedly
        points.screenTimeBalanceMinutes = 0
        do {
            try context.save()
            // Show toast
            lastAppliedBonusMinutes = bonusMinutes
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                showBonusToast = true
            }
            // Hide after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut) {
                    showBonusToast = false
                }
            }
        } catch {
            print("Failed to consume bonus minutes: \(error)")
        }
    }
    
    private func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error { print("Notification auth error: \(error)") }
                else { print("Notification auth granted: \(granted)") }
            }
        }
    }

    private func scheduleBreakTimeNotificationIfBackground() {
        // Only schedule if app not active to avoid duplicate in-app alert + banner
        if UIApplication.shared.applicationState == .active { return }
        let content = UNMutableNotificationContent()
        content.title = "Your break is here!"
        content.body = "Your screen time has reached the limit. Please select an option to take a break."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: "BreakTimeNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Failed to schedule break time notification: \(error)") }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                NavigationLink(destination: ActivitiesTab(), isActive: $navigateToActivities) { EmptyView() }
                
                Group {
                    if appThemeName == "Cosmic Orange" {
                        Color.clear
                    } else {
                        Color.blue.opacity(0.15)
                    }
                }
                .ignoresSafeArea()
                
                VStack(alignment: .center, spacing: 24) {
                    VStack (spacing: 15){

                        Text("\(Image(systemName: "hourglass"))")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("📱Total Time on Screen Today: ")
                            .font(.system(size: 25, weight: .bold))
                            .bold()
                        
                        Text("Time spent: \(formatTime(totalSeconds))")
                            .font(.title2)
                            .monospacedDigit()
                        
                        Button(role: .destructive) {
                            showingAlert = true
                        } label: {
                            Label("Restart Timer?", systemImage: "arrow.counterclockwise")
                            
                        }
                        .alert("You sure you want to reset the screen timer?", isPresented: $showingAlert) {
                            Button("Yes", role: .destructive) {
                                self.resetTime()
                            }
                            Button("No, I will keep the time.", role: .cancel) { }
                        }
                    }
                    .navigationTitle("Home")
                    .padding()
                    .onDisappear { stopTracking() }
                    
                    // Timer to break before user needs to workout or meditate
                    VStack(spacing: 15) {
                        Text("\(Image(systemName: "alarm.fill"))")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(isCountingDown ? "Next break in: " : "Break time elapsed: ")
                            .font(.system(size: 30, weight: .bold))
                        
                        Text(timeString(from: isCountingDown ? countdownSeconds : breakSeconds))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(isCountingDown ? .orange : .red)
                        
                        HStack(spacing: 12) {
                            
                            Button(action: resetTimer) {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 50)
                                    .padding(.vertical, 20)
                                    .background(
                                        ZStack {
                                            // Liquid Glass base with preserved sizing and radius
                                            RoundedRectangle(cornerRadius: 45, style: .continuous)
                                                .fill(.ultraThinMaterial)
                                            // Preserve orange brand color with translucency
                                            RoundedRectangle(cornerRadius: 45, style: .continuous)
                                                .fill(Color.orange.opacity(0.75))
                                            // Glossy highlight and subtle border
                                            RoundedRectangle(cornerRadius: 45, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.75), lineWidth: 0.75)
                                                .blendMode(.overlay)
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 45, style: .continuous))
                            }
                        }
                        /*
                        // Debug: Test alarm sound playback manually
                        Button("Test Break Timer Alarm Sound") {
                            if disableAlarmSound { playBreakHaptic() } else { playBreakAlertSystemSound() }
                        }
                        .buttonStyle(.bordered)
                        */
                        
                        Button(action: { extendBreak() }) {
                            Label("Add Time to Break", systemImage: "plus.app")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 25)
                                .padding(.vertical, 25)
                                .background(
                                    ZStack {
                                        // Liquid Glass base with preserved sizing and radius
                                        RoundedRectangle(cornerRadius: 45, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                        // Preserve orange brand color with translucency
                                        RoundedRectangle(cornerRadius: 45, style: .continuous)
                                            .fill(Color.orange.opacity(0.75))
                                        // Glossy highlight and subtle border
                                        RoundedRectangle(cornerRadius: 45, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.75), lineWidth: 0.75)
                                            .blendMode(.overlay)
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 45, style: .continuous))
                        }
                        .disabled(!isTracking)
                        .accessibilityHint("Timer starts automatically on launch")
                        .shadow(color: Color.white.opacity(0.18), radius: 12, x: 0, y: 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                }
                // Toast overlay for bonus minutes
                if showBonusToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "clock.badge.plus")
                                .imageScale(.large)
                                .foregroundStyle(.white)
                            Text("Added \(lastAppliedBonusMinutes) bonus minute\(lastAppliedBonusMinutes == 1 ? "" : "s")")
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.8))
                        )
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }
            }
            .alert("Your break is here!", isPresented: $isBreakAlertPresented) {
                
                
                Button("Get Moving! ") {
                    // Dismiss alert before navigating to avoid state mutation during presentation
                    isBreakAlertPresented = false
                    DispatchQueue.main.async {
                        navigateToActivities = true
                    }
                }
                
                Button("Mindful Moment", role: .cancel) {
                    // Dismiss the alert before navigating to avoid state mutation during presentation
                    isBreakAlertPresented = false
                    DispatchQueue.main.async {
                        navigateToActivities = true
                    }
                }
                
                // Show follow-up alert to skip/extend break 
                Button(role: .destructive) {
                    showSkipExtendAlert = true
                } label: {
                    Text("Skip/Extend Break")
                }
            } message: {
                Text("Your screen time has reached the limit. Please select an option to take a break. ")
            }
            .alert("Skip or Extend Break?", isPresented: $showSkipExtendAlert) {
                Button("Skip Break", role: .destructive) {
                    let reduced = max(5, nextCountdownBaseSeconds - 900)
                    nextCountdownBaseSeconds = reduced
                    resetTimer()
                    self.startTimer()
                }
                Button("Extend Break") {
                    // Extend current break by 5 minutes
                    extendBreak(by: 300)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("If you skip your break now, the next countdown will be shorter when it restarts, and you'll have to take another break SOONER. Or extend your current break.")
            }
        }
        .onAppear {
            //Timer automation.
            // Start the persistent continous screen time tracker in the background.
            startTracking()
            // Automatically start the break/countdown timer if not already running.
            self.startTimer()
            if isCountingDown { applyAvailableBonusMinutes() }
            
            requestNotificationAuthorizationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ActivityCompletedAwardedTime"))) { _ in
            // When an activity completes, use the updated base (15 min + awarded) and restart the countdown and then count down until the break.
            resetTimer()
            applyAvailableBonusMinutes()
            startTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BreakTimerReachedLimit"))) { _ in
            isBreakAlertPresented = true
        }
    }
    
    // MARK: - Alert Sounds.
    private func playBreakAlertSound() {
        guard let soundFileURL = Bundle.main.url(
            forResource: "breakAlert",
            withExtension: "mp3"
        ) else {
            print("breakAlert.mp3 not found in bundle")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
            print("Audio session activated for playback")

            let player = try AVAudioPlayer(contentsOf: soundFileURL)
            player.prepareToPlay()
            self.audioPlayer = player
            let success = player.play()
            print("Attempted to play break alert: \(success)")
        } catch {
            print("Failed to play break alert sound breakAlert.mp3 \(error)")
        }
    }
    
    // MARK: - System Sound (on AudioToolbox) fallback
    private func playBreakAlertSystemSound() {
        // If we already created a SystemSoundID, just play it
        if breakSystemSoundID != 0 {
            AudioServicesPlaySystemSound(breakSystemSoundID)
            return
        }

        // Prefer a short .caf, .aiff, or .wav for system sounds
        let candidates: [(name: String, ext: String)] = [
            ("breakAlert", "caf"),
            ("breakAlert", "aiff"),
            ("breakAlert", "wav"),
            ("breakAlert", "mp3")
        ]

        var foundURL: URL? = nil
        for candidate in candidates {
            if let url = Bundle.main.url(forResource: candidate.name, withExtension: candidate.ext) {
                foundURL = url
                print("Using system sound resource: \(candidate.name).\(candidate.ext)")
                break
            }
        }

        guard let soundURL = foundURL else {
            print("No suitable breakAlert sound resource found for system sound")
            return
        }

        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        if status == kAudioServicesNoError {
            breakSystemSoundID = soundID
            AudioServicesPlaySystemSound(soundID)
            print("Played system sound for break alert (id: \(soundID))")
        } else {
            print("Failed to create system sound id: \(status)")
        }
    }
    
    // MARK: - Haptics to play alarm quietly
    private func playStrongBreakHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            // Use a continuous, strong, sharp, long haptic (1.5 seconds) to notify user it's break time!
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 8.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 8.0)
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 10.5)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play strong, long haptic: \(error)")
        }
    }


        
    // MARK: - Timer Functions
    private func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            totalSeconds += 1
        }
    }

    private func stopTracking() {
        timer?.invalidate()
        timer = nil
        isTracking = false
    }

    private func extendTimer(by seconds: Int = 300) {
        guard seconds > 0 else { return }
        totalSeconds += seconds
    }
    
    private func extendBreak(by seconds: Int = 300) {
        guard seconds > 0 else { return }
        if isCountingDown {
            // Add time to the remaining countdown until next break
            countdownSeconds += seconds
        } else {
            // We're currently in break (count-up while doing the workout). Extending the break means
            // allowing more time before it ends; since this is count-up, we
            // interpret the extension as subtracting elapsed break time if possible.
            // Clamp at zero to avoid negative values.
            breakSeconds = max(0, breakSeconds - seconds)
        }
    }

    private func resetTime() {
        stopTracking()
        totalSeconds = 0
        // Restart the screen time tracker and break timer after reset
        startTracking()
        resetTimer()
        startTimer()
    }

    private func formatTime(_ seconds: Int) -> String {
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    private func timeString(from seconds: Int) -> String {
        let breakHrs = seconds / 3600
        let breakMinutes = seconds / 60
        let breakSecs = seconds % 60
        return String(format: "%02d:%02d:%02d", breakHrs, breakMinutes, breakSecs)
    }

    // MARK: - Timer Control
    private func startTimer() {
        // Safe to call multiple times (e.g., from onAppear); guarded by `timerCancellable == nil`
        guard timerCancellable == nil else { return }
        
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if isCountingDown {
                    if countdownSeconds > 0 {
                        countdownSeconds -= 1
                    } else {
                        // Switch to count-up mode and present break alert
                        isCountingDown = false
                        breakSeconds = 0
                        
                        // Broadcast a global notification so other tabs can show the same alert
                        NotificationCenter.default.post(name: Notification.Name("BreakTimerReachedLimit"), object: nil)
                        
                        if disableAlarmSound {
                            playStrongBreakHaptic()
                        } else {
                            playBreakAlertSystemSound()
                        }
                        isBreakAlertPresented = true
                        scheduleBreakTimeNotificationIfBackground()
                    }
                } else {
                    breakSeconds += 1
                }
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func resetTimer() {
        stopTimer()
        countdownSeconds = 15
        applyAvailableBonusMinutes()
        breakSeconds = 0
        isCountingDown = true
    }
}

#Preview {
    ContentView()
}

