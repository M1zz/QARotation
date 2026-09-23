import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ImportController.self) private var importer
    @AppStorage(SettingsKey.artistID, store: .shared) private var artistID = SettingsDefault.artistID
    @AppStorage(SettingsKey.storefronts, store: .shared) private var storefronts = SettingsDefault.storefronts
    @AppStorage(SettingsKey.weightHigh, store: .shared) private var weightHigh = TierWeights.standard.high
    @AppStorage(SettingsKey.weightNormal, store: .shared) private var weightNormal = TierWeights.standard.normal
    @AppStorage(SettingsKey.weightLow, store: .shared) private var weightLow = TierWeights.standard.low

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("기본 체크리스트") { ChecklistEditorView() }
                } footer: {
                    Text("앱마다 따로 붙일 항목은 앱 화면에서 추가하세요.")
                }

                BreakRemindersSection()

                Section {
                    weightStepper("높음", value: $weightHigh)
                    weightStepper("보통", value: $weightNormal)
                    weightStepper("낮음", value: $weightLow)
                    if TierWeights(high: weightHigh, normal: weightNormal, low: weightLow) != .standard {
                        Button("기본값으로") {
                            weightHigh = TierWeights.standard.high
                            weightNormal = TierWeights.standard.normal
                            weightLow = TierWeights.standard.low
                        }
                    }
                } header: {
                    Text("우선순위 가중치")
                } footer: {
                    Text("추천 점수 = 마지막 QA 후 지난 날 × 가중치. 한 번도 안 한 앱은 항상 먼저 추천해요.")
                }

                Section {
                    LabeledContent("개발자 ID") {
                        TextField("artistId", text: $artistID)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("스토어") {
                        TextField("kr,us", text: $storefronts)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    Button {
                        Task { await importer.run(context: context) }
                    } label: {
                        HStack {
                            Text("App Store에서 가져오기")
                            if importer.isRunning {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(importer.isRunning)
                } header: {
                    Text("App Store")
                } footer: {
                    Text("새 앱을 더하고 이름·버전·아이콘을 맞춥니다. 로컬 기록은 지우지 않아요. 스토어는 쉼표로 나눠 여러 개를 적을 수 있어요.")
                }

                Section("정보") {
                    LabeledContent("버전", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                }
            }
            .navigationTitle("설정")
            .onChange(of: weightHigh) { PickChangeCoordinator.pickDidChange(context: context) }
            .onChange(of: weightNormal) { PickChangeCoordinator.pickDidChange(context: context) }
            .onChange(of: weightLow) { PickChangeCoordinator.pickDidChange(context: context) }
        }
    }

    private func weightStepper(_ title: String, value: Binding<Double>) -> some View {
        Stepper(value: value, in: 0.5...5, step: 0.5) {
            LabeledContent(title, value: value.wrappedValue.formatted(.number.precision(.fractionLength(1))))
        }
    }
}

private struct BreakRemindersSection: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.remindersEnabled, store: .shared) private var enabled = false
    @State private var times: [BreakTime] = BreakTimeStore.load()
    @State private var permissionDenied = false

    var body: some View {
        Section {
            Toggle("쉬는 시간 알림", isOn: $enabled)
            if enabled {
                ForEach($times) { $time in
                    DatePicker(
                        "알림 시각",
                        selection: Binding(
                            get: { time.date },
                            set: { date in
                                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                                time.hour = parts.hour ?? time.hour
                                time.minute = parts.minute ?? time.minute
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
                .onDelete { times.remove(atOffsets: $0) }

                Button("시각 추가", systemImage: "plus") {
                    let last = times.last
                    times.append(BreakTime(hour: min((last?.hour ?? 14) + (last == nil ? 0 : 1), 23), minute: last?.minute ?? 0))
                }
            }
        } header: {
            Text("알림")
        } footer: {
            if permissionDenied {
                Text("알림 권한이 꺼져 있어요. 설정 앱에서 켜 주세요.").foregroundStyle(.red)
            } else {
                Text("정한 시각에 오늘 추천 앱을 알려 줘요. 알림을 누르면 바로 QA가 시작돼요.")
            }
        }
        .onChange(of: enabled) { _, isOn in
            guard isOn else { return reschedule() }
            Task {
                let granted = await NotificationScheduler.requestAuthorization()
                permissionDenied = !granted
                if !granted { enabled = false }
                if times.isEmpty { times = [BreakTime(hour: 15, minute: 0)] }
                reschedule()
            }
        }
        .onChange(of: times) { _, newValue in
            BreakTimeStore.save(newValue)
            reschedule()
        }
    }

    private func reschedule() {
        PickChangeCoordinator.pickDidChange(context: context)
    }
}
