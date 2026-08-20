import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var profileStore: CreatorProfileStore
    @State private var showsRestoreConfirmation = false
    @State private var presetName = ""
    @State private var showsToneControls = false
    @State private var showsAdvancedPrompt = false

    var body: some View {
        Form {
            Section {
                ForEach(profileStore.presets) { preset in
                    Button {
                        profileStore.apply(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.name).foregroundStyle(.primary)
                                Text("\(preset.controls.characterCount)자")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                        }
                    }
                }
                .onDelete(perform: profileStore.deletePreset)
            } header: {
                Text("내 프리셋")
            }

            Section("기본 설정") {
                labeledField("주제", text: $profileStore.profile.accountTopic)
                labeledField("독자", text: $profileStore.profile.audience)
                labeledField("말투", text: $profileStore.profile.voice)
                controlSlider("글자 수", value: controlBinding(\.characterCount), range: 50...500, step: 10, suffix: "자")
                Toggle("이모지 사용", isOn: $profileStore.profile.usesEmoji)
            }

            Section {
                DisclosureGroup("분위기 조절", isExpanded: $showsToneControls) {
                    controlSlider("감동", value: controlBinding(\.emotion))
                    controlSlider("친절함", value: controlBinding(\.kindness))
                    controlSlider("참신함", value: controlBinding(\.originality))
                    controlSlider("단단함", value: controlBinding(\.masculinity))
                    controlSlider("시크함", value: controlBinding(\.chic))

                    HStack {
                        Text("합계")
                        Spacer()
                        Text("\(profileStore.profile.controls.toneTotal)%")
                            .foregroundStyle(profileStore.profile.controls.toneTotal == 100 ? Color.secondary : Color.orange)
                            .monospacedDigit()
                    }
                    .font(.footnote)
                }
            }

            Section {
                TextField(
                    "추가 지침",
                    text: Binding(
                        get: { profileStore.profile.additionalInstructions ?? "" },
                        set: { profileStore.profile.additionalInstructions = $0 }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...8)
                TextField("금지 표현", text: $profileStore.profile.prohibitedPhrases, axis: .vertical)
                TextField("해시태그", text: $profileStore.profile.hashtagStyle)
            } header: {
                Text("추가 옵션")
            }

            Section {
                HStack {
                    TextField("새 프리셋 이름", text: $presetName)
                    Button("저장") {
                        profileStore.savePreset(named: presetName)
                        presetName = ""
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("프리셋 저장")
            }

            Section {
                DisclosureGroup("직접 편집", isExpanded: $showsAdvancedPrompt) {
                    TextEditor(text: $profileStore.profile.writingGuidelines)
                        .font(.callout)
                        .frame(minHeight: 360)

                    Button("기본값으로 되돌리기", role: .destructive) {
                        showsRestoreConfirmation = true
                    }
                }
            } header: {
                Text("작성 원칙")
            }

        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .navigationTitle("내 설정")
        .confirmationDialog(
            "기본 작성 지침으로 되돌릴까요?",
            isPresented: $showsRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("되돌리기", role: .destructive) {
                profileStore.restoreDefaultWritingGuidelines()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("직접 수정한 내용은 사라집니다.")
        }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func controlBinding(_ keyPath: WritableKeyPath<GenerationControls, Int>) -> Binding<Double> {
        Binding(
            get: { Double(profileStore.profile.controls[keyPath: keyPath]) },
            set: { newValue in
                var controls = profileStore.profile.controls
                controls[keyPath: keyPath] = Int(newValue)
                profileStore.profile.controls = controls
            }
        )
    }

    private func controlSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...100,
        step: Double = 5,
        suffix: String = "%"
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
    }
    .environmentObject(CreatorProfileStore())
}
