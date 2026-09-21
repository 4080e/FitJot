import SwiftUI
import SwiftData

struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var session: TrainingSession
    @State private var confirmingFinish = false
    @State private var showingSettings = false
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 48

    @ScaledMetric(relativeTo: .largeTitle) private var statusHeight = 150
    @ScaledMetric(relativeTo: .title2) private var primaryButtonHeight = 60

    var body: some View {
        NavigationStack {
            if session.phase != .finished {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(session.current.name).font(.title.bold())
                                .multilineTextAlignment(.center)
                            Text("\(session.current.amount)\(session.current.type == .repetitions ? "回" : "秒") × \(session.current.sets)セット")
                                .font(.title.bold())
                                .multilineTextAlignment(.center)
                            Text("種目 \(session.index + 1) / \(session.exercises.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Text(session.phase == .interval ? "インターバル" : "トレーニング中")
                                    .font(.headline)
                                    .opacity(session.phase == .ready ? 0 : 1)
                                    .accessibilityHidden(session.phase == .ready)
                                Text(session.phase == .interval
                                     ? "次は \(session.current.completedSets + 1)セット目"
                                     : "\(session.current.completedSets + 1)セット目")
                                    .font(.title2.bold())
                                Text("残り \(Int(ceil(session.remaining)))秒")
                                    .font(.system(size: timerFontSize, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                    .opacity(isCountingDown ? 1 : 0)
                                    .accessibilityHidden(!isCountingDown)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: statusHeight)


                            Button {
                                if isCountingDown {
                                    session.togglePause()
                                } else if session.phase == .ready {
                                    session.start()
                                } else {
                                    session.completeRepetitionSet()
                                }
                            } label: {
                                Text(primaryButtonTitle)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: primaryButtonHeight)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            Button { session.skipInterval() } label: {
                                actionLabel("インターバルをスキップ")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .opacity(session.phase == .interval ? 1 : 0)
                            .allowsHitTesting(session.phase == .interval)
                            .accessibilityHidden(session.phase != .interval)
                        }
                        .frame(maxWidth: .infinity)

                        Button { session.endExercise() } label: {
                            actionLabel(session.current.completedSets == 0 ? "スキップ" : "この種目を終了")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .safeAreaInset(edge: .bottom) {
                    Text("経過時間：\(Int(session.elapsed))秒")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.bar)
                        .opacity(session.phase == .ready ? 0 : 1)
                        .accessibilityHidden(session.phase == .ready)
                }
                .navigationTitle(session.planName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("ここで終了", role: .destructive) { confirmingFinish = true }
                    }
                    if session.phase == .ready {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("今回の設定を変更")
                        }
                    }
                }
                .confirmationDialog("トレーニングをここで終了しますか？", isPresented: $confirmingFinish, titleVisibility: .visible) {
                    Button("ここで終了", role: .destructive) { session.finish() }
                    Button("続ける", role: .cancel) {}
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                Form {
                    Stepper(value: $session.exercises[session.index].amount, in: 1...Int.max) {
                        Text(session.current.type == .repetitions
                             ? "回数：\(session.current.amount)回" : "時間：\(session.current.amount)秒")
                    }
                    Stepper("セット数：\(session.current.sets)", value: $session.exercises[session.index].sets, in: 1...Int.max)
                    Stepper("インターバル：\(session.current.interval)秒", value: $session.exercises[session.index].interval, in: 0...Int.max, step: 5)
                }
                .navigationTitle("設定を変更")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") { showingSettings = false }
                    }
                }
            }
        }
        .alert("履歴を保存できませんでした", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("再試行") { saveHistory() }
            Button("保存せず終了", role: .destructive) { dismiss() }
        } message: {
            Text(saveError ?? "")
        }
        .interactiveDismissDisabled()
        .onChange(of: session.phase) { _, phase in
            if phase == .finished { saveHistory() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.update() }
        }
        .task {
            while !Task.isCancelled {
                if scenePhase == .active { session.update() }
                do { try await Task.sleep(for: .milliseconds(200)) }
                catch { return }
            }
        }
    }

    private func saveHistory() {
        do {
            try TrainingHistory.save(session: session, in: context)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var isCountingDown: Bool {
        session.phase == .interval || (session.phase == .exercising && session.current.type == .timed)
    }

    private var primaryButtonTitle: String {
        if isCountingDown { return session.isPaused ? "再開" : "一時停止" }
        if session.phase == .ready { return "トレーニングスタート" }
        return session.current.completedSets + 1 == session.current.sets
            ? "完了" : "\(session.current.completedSets + 1)セット完了"
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }

}
