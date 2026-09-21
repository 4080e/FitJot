import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox
import OSLog

@MainActor
final class IntervalNotifications {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "FitJot", category: "IntervalNotifications")
    private var pendingIDs: [String] = []
    private var generation = UUID()
    private var schedulingTask: Task<Void, Never>?
    private var permissionTask: Task<Void, Never>?
    private var player: AVAudioPlayer?
    private var tickPlayer: AVAudioPlayer?
    var isActive = true {
        didSet { if !isActive { stopCountdownTick() } }
    }

    private func enabled(_ key: String) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    func prepare() {
        guard enabled("intervalBackgroundNotificationEnabled") else { return }
        permissionTask = Task {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
            catch { logger.error("Notification authorization failed: \(error.localizedDescription)") }
        }
    }

    func schedule(events: [TrainingSession.CountdownNotification]) {
        cancel()
        let events = events.filter { $0.date > .now }
        guard !events.isEmpty, enabled("intervalBackgroundNotificationEnabled") else { return }
        let token = generation
        let identifiers = events.map { _ in "FitJot.countdown.\(UUID().uuidString)" }
        pendingIDs = identifiers
        schedulingTask = Task {
            await permissionTask?.value
            guard !Task.isCancelled, generation == token else { return }
            let settings = await center.notificationSettings()
            guard !Task.isCancelled, generation == token,
                  settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            for (event, identifier) in zip(events, identifiers) {
                guard !Task.isCancelled, generation == token else { return }
                let delay = event.date.timeIntervalSinceNow
                guard delay > 0 else { continue }
                let content = UNMutableNotificationContent()
                content.title = event.kind == .interval ? "インターバル終了" : "時間制トレーニング終了"
                content.body = event.kind == .interval ? "次のセットを始めましょう" : "セットが完了しました"
                content.sound = enabled("intervalSoundEnabled") ? .default : nil
                let request = UNNotificationRequest(identifier: identifier, content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))
                do {
                    try await center.add(request)
                    // Cancellation can race with the asynchronous add operation.
                    if Task.isCancelled || generation != token {
                        center.removePendingNotificationRequests(withIdentifiers: [identifier])
                    }
                } catch {
                    logger.error("Interval notification scheduling failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancel() {
        schedulingTask?.cancel()
        schedulingTask = nil
        generation = UUID()
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        pendingIDs = []
    }

    func stopCountdownTick() { tickPlayer?.stop() }

    func countdownTick() {
        guard isActive, enabled("intervalSoundEnabled") else { return }
        do {
            if tickPlayer == nil {
                tickPlayer = try AVAudioPlayer(data: Self.tickSound())
                tickPlayer?.prepareToPlay()
            }
            tickPlayer?.currentTime = 0
            tickPlayer?.play()
        } catch { logger.error("Countdown sound failed: \(error.localizedDescription)") }
    }

    // A short 660 Hz tone, below the existing 880 Hz end sound. No bundled file is needed.
    private static func tickSound() -> Data {
        let rate = 22050
        let count = 2205
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func number<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        text("RIFF"); number(UInt32(36 + count * 2)); text("WAVEfmt ")
        number(UInt32(16)); number(UInt16(1)); number(UInt16(1))
        number(UInt32(rate)); number(UInt32(rate * 2))
        number(UInt16(2)); number(UInt16(16))
        text("data"); number(UInt32(count * 2))
        for index in 0..<count {
            let time = Double(index) / Double(rate)
            let envelope = min(1, time / 0.01) * min(1, (0.1 - time) / 0.025)
            number(Int16(8000 * envelope * sin(2 * .pi * 660 * time)))
        }
        return data
    }

    func countdownEnded() {
        tickPlayer?.stop()
        cancel()
        guard isActive else { return }
        if enabled("intervalSoundEnabled"), let url = Bundle.main.url(forResource: "IntervalEnd", withExtension: "wav") {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()
            } catch { logger.error("Interval sound failed: \(error.localizedDescription)") }
        }
        #if os(iOS)
        if enabled("intervalVibrationEnabled") {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        #endif
    }
}
