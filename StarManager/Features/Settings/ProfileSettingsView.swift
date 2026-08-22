import SwiftUI
import UIKit

struct ProfileSettingsView: View {
    @EnvironmentObject private var profileStore: CreatorProfileStore
    @Environment(\.brandTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(BrandTheme.appearanceStorageKey) private var appearanceStyleRaw = AppearanceStyle.bk.rawValue
    @AppStorage(SharedGenerationSettings.moodKey) private var mood = PostMood.witty
    @AppStorage(SharedGenerationSettings.storyWeightKey) private var length = PostLength.medium
    @AppStorage(SharedGenerationSettings.stylePresetKey) private var selectedGenerationStyleRaw = GenerationStylePreset.generation386.rawValue
    @State private var showsRestoreConfirmation = false
    @State private var presetName = ""
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
                BrandSectionTitle(title: "내 프리셋", systemImage: "bookmark.fill", tone: .leather)
            }

            Section {
                labeledField("주제", text: $profileStore.profile.accountTopic)
                labeledField("독자", text: $profileStore.profile.audience)
                labeledField("말투", text: $profileStore.profile.voice)
                Toggle("이모지 사용", isOn: $profileStore.profile.usesEmoji)
            } header: {
                BrandSectionTitle(title: "기본 설정", systemImage: "slider.horizontal.3")
            }

            Section {
                LazyVGrid(columns: generationPresetColumns, spacing: 10) {
                    ForEach(GenerationStylePreset.allCases) { preset in
                        Button {
                            selectedGenerationStyleRaw = preset.rawValue
                            profileStore.profile = preset.applying(to: profileStore.profile)
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: preset.symbolName)
                                    .font(.system(size: 17, weight: .regular))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(theme.style == .bk ? theme.leather : BrandTheme.accent)
                                    .frame(width: 30, height: 30)
                                    .background(theme.paper, in: Circle())
                                    .accessibilityHidden(true)
                                Text(preset.title).font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .padding(.vertical, 6)
                            .background(
                                selectedGenerationStyle == preset ? theme.selectionFill : theme.canvas,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedGenerationStyle == preset ? BrandTheme.accent : Color.clear, lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("선택하면 글자 수를 제외한 말투와 분위기 설정이 적용됩니다")
                        .accessibilityValue(selectedGenerationStyle == preset ? "선택됨" : "선택 안 됨")
                    }
                }
                .padding(.vertical, 4)

                Picker("분위기", selection: $mood) {
                    ForEach(PostMood.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("분위기")

                Picker("이야기 비중", selection: $length) {
                    ForEach(PostLength.allCases) { Text($0.storyWeightTitle).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("이야기 비중")

                controlSlider("글자 수", value: controlBinding(\.characterCount), range: 50...500, step: 10, suffix: "자")
                controlSlider("감동", value: controlBinding(\.emotion))
                controlSlider("친절함", value: controlBinding(\.kindness))
                controlSlider("참신함", value: controlBinding(\.originality))
                controlSlider("단단함", value: controlBinding(\.masculinity))
                controlSlider("시크함", value: controlBinding(\.chic))

                HStack {
                    Text("느낌 합계")
                    Spacer()
                    Text("\(profileStore.profile.controls.toneTotal)%")
                        .foregroundStyle(profileStore.profile.controls.toneTotal == 100 ? Color.secondary : Color.orange)
                        .monospacedDigit()
                }
                .font(.footnote)
            } header: {
                BrandSectionTitle(title: "글쓰기 취향", systemImage: "paintpalette.fill", tone: .leather)
            } footer: {
                Text("여기서 고른 모든 값이 스튜디오의 게시물 생성에 바로 적용됩니다.")
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
                BrandSectionTitle(title: "추가 옵션", systemImage: "text.badge.plus")
            }

            Section {
                HStack {
                    TextField("새 프리셋 이름", text: $presetName)
                    Button("이 기기에 보관") {
                        profileStore.savePreset(named: presetName)
                        presetName = ""
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                BrandSectionTitle(title: "프리셋 보관", systemImage: "tray.and.arrow.down.fill", tone: .leather)
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
                BrandSectionTitle(title: "작성 원칙", systemImage: "text.book.closed.fill")
            }

            Section {
                Picker("테마", selection: $appearanceStyleRaw) {
                    ForEach(AppearanceStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                BrandSectionTitle(title: "테마", systemImage: "paintbrush.pointed.fill")
            } footer: {
                Text("클래식을 고르면 예전 모습으로 볼 수 있어요.")
            }

        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .scrollContentBackground(.hidden)
        .background(theme.canvasGradient)
        .navigationTitle("나의 취향")
        .onChange(of: appearanceStyleRaw) { _, newValue in
            updateAppIcon(for: newValue)
        }
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

    private var selectedGenerationStyle: GenerationStylePreset? {
        GenerationStylePreset(rawValue: selectedGenerationStyleRaw)
    }

    private func updateAppIcon(for rawValue: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let iconName = AppearanceStyle(rawValue: rawValue) == .classic ? "AppIconClassic" : nil
        guard UIApplication.shared.alternateIconName != iconName else { return }
        UIApplication.shared.setAlternateIconName(iconName)
    }

    private var generationPresetColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
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
