import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit
#if canImport(ImagePlayground)
import ImagePlayground
#endif

struct ComposerView: View {
    private static let maxMediaItems = 8

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var profileStore: CreatorProfileStore

    @State private var idea = ""
    @State private var mood = PostMood.witty
    @State private var length = PostLength.medium
    @State private var generatedPost: GeneratedPost?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var previewAspect = PreviewAspect.feed
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [ComposerMedia] = []
    @State private var mediaLoadTask: Task<Void, Never>?
    @State private var mediaLoadID = UUID()
    @State private var isLoadingMedia = false
    @State private var isGeneratingImage = false
    @State private var isPreparingShare = false
    @State private var sharePayload: SharePayload?
    @State private var shareMessage: String?
    @State private var shareMessageIsError = false
    @State private var hasPositionedInitialScroll = false
    @State private var selectedGenerationStyle: GenerationStylePreset? = .generation386
    @State private var generatedSignature: DraftSignature?
    @State private var activeCaptionSource: CaptionSource?
    @State private var captionCandidates: [CaptionSource: CaptionCandidate] = [:]
    @State private var showsImagePlayground = false
    @State private var imagePlaygroundPrompt = ""
    @State private var imageGenerationPostID: UUID?
    @State private var pendingExternalProvider: DirectAIProvider?
    @State private var draggedMediaID: UUID?
    @State private var isMediaDropTargeted = false
    @State private var aiPromptShare: AIPromptShare?
    @State private var showsCamera = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear.frame(height: 0).id("composer-top")
                Group {
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            creationColumn
                            previewColumn
                        }
                        .frame(maxWidth: 1120)
                    } else {
                        VStack(spacing: 16) {
                            creationColumn
                            previewColumn
                        }
                        .frame(maxWidth: 680)
                    }
                }
                .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
                .padding(.vertical, horizontalSizeClass == .regular ? 20 : 12)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                guard !hasPositionedInitialScroll else { return }
                hasPositionedInitialScroll = true
                proxy.scrollTo("composer-top", anchor: .top)
            }
        }
        .background(BrandTheme.canvas)
        .background(KeyboardDismissTapInstaller())
        .navigationTitle("스타메니저")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItems) { _, items in
            guard !items.isEmpty else { return }
            mediaLoadTask?.cancel()
            let loadID = UUID()
            mediaLoadID = loadID
            mediaLoadTask = Task { await loadMedia(from: items, loadID: loadID) }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(items: payload.items, cleanupURLs: payload.cleanupURLs) { completed, error in
                if let error {
                    shareMessage = "공유하지 못했어요: \(error.localizedDescription)"
                    shareMessageIsError = true
                } else if completed {
                    shareMessage = "공유 완료 · 문구 붙여넣기"
                    shareMessageIsError = false
                } else {
                    shareMessage = "공유 취소 · 문구는 복사됨"
                    shareMessageIsError = false
                }
            }
        }
        .sheet(item: $aiPromptShare) { payload in
            ActivityView(items: [payload.text], cleanupURLs: []) { completed, error in
                if let error {
                    errorMessage = "\(payload.provider.title)로 보내지 못했어요: \(error.localizedDescription)"
                } else if completed {
                    statusMessage = "\(payload.provider.title)로 보냄 · 결과를 복사해 돌아오세요"
                } else {
                    statusMessage = "보내기 취소 · 요청문은 복사됨"
                }
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCaptureView { image in addCameraPhoto(image) }
                .ignoresSafeArea()
        }
        .starImagePlaygroundSheet(
            isPresented: $showsImagePlayground,
            prompt: imagePlaygroundPrompt,
            onCompletion: receiveImagePlaygroundResult,
            onCancellation: {
                isGeneratingImage = false
                imageGenerationPostID = nil
            }
        )
    }

    private var creationColumn: some View {
        let pickerTitle = "미디어"
        let pickerIcon = mediaItems.isEmpty ? "photo.badge.plus" : "checkmark.circle.fill"

        return VStack(alignment: .leading, spacing: 18) {
            heroCopy

            TextField("오늘의 이야기", text: $idea, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                .padding(14)
                .background(BrandTheme.canvas, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHint("게시물의 바탕이 될 짧은 이야기를 입력합니다")

            VStack(alignment: .leading, spacing: 10) {
                Text("스타일").font(.subheadline.weight(.semibold))
                LazyVGrid(
                    columns: generationPresetColumns,
                    spacing: 10
                ) {
                    ForEach(GenerationStylePreset.allCases) { preset in
                        Button {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil,
                                from: nil,
                                for: nil
                            )
                            selectedGenerationStyle = preset
                            profileStore.profile = preset.applying(to: profileStore.profile)
                            statusMessage = "\(preset.title) 적용"
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: preset.symbolName)
                                    .font(.system(size: 17, weight: .regular))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(BrandTheme.accent)
                                    .frame(width: 30, height: 30)
                                    .background(BrandTheme.paper, in: Circle())
                                    .accessibilityHidden(true)
                                Text(preset.title).font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .padding(.vertical, 6)
                            .background(
                                selectedGenerationStyle == preset ? BrandTheme.paper : BrandTheme.canvas,
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
            }

            HStack(spacing: 10) {
                Text("분위기")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 70, alignment: .leading)
                Picker("분위기", selection: $mood) {
                    ForEach(PostMood.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 10) {
                Text("이야기 비중")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 70, alignment: .leading)
                Picker("이야기 비중", selection: $length) {
                    ForEach(PostLength.allCases) { Text($0.storyWeightTitle).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("글자 수").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(profileStore.profile.controls.characterCount)자")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.accent)
                        .monospacedDigit()
                }
                Slider(value: characterCountBinding, in: 50...500, step: 10)
                    .tint(BrandTheme.accent)
                    .accessibilityLabel("글자 수")
                    .accessibilityValue("\(profileStore.profile.controls.characterCount)자")
            }

            aiChoiceButtons

            if generatedPost != nil {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("미디어").font(.headline)
                        Text("사진·영상을 선택하거나 드래그해 최대 \(Self.maxMediaItems)개 추가")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("게시 비율", selection: $previewAspect) {
                        ForEach(PreviewAspect.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: max(1, Self.maxMediaItems - mediaItems.count),
                            selectionBehavior: .ordered,
                            matching: .any(of: [.images, .videos]),
                            photoLibrary: .shared()
                        ) {
                            Label(pickerTitle, systemImage: pickerIcon)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(isLoadingMedia || mediaItems.count >= Self.maxMediaItems)
                        .accessibilityHint("사진 보관함에서 게시 순서대로 최대 \(Self.maxMediaItems)개를 선택하거나 이 영역으로 드래그합니다")

                        Button(action: openCamera) {
                            Label("카메라", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(mediaItems.count >= Self.maxMediaItems)
                        .accessibilityHint("카메라로 사진을 찍어 미디어에 추가합니다")
                    }

                    if !mediaItems.isEmpty { mediaOrderEditor }
                }
                .contentShape(Rectangle())
                .onDrop(
                    of: [UTType.image.identifier, UTType.movie.identifier],
                    isTargeted: $isMediaDropTargeted,
                    perform: receiveDroppedMedia
                )
                .overlay {
                    if isMediaDropTargeted {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(BrandTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                            .allowsHitTesting(false)
                    }
                }
            }

            if let message = errorMessage ?? statusMessage {
                Label(message, systemImage: errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(errorMessage == nil ? BrandTheme.accent : .red)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 540, alignment: .leading)
        .starCard()
    }

    private var heroCopy: some View {
        Text("오늘 전하고 싶은 이야기는 무엇인가요?")
            .font(.system(.title2, design: .rounded, weight: .bold))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
    }

    private var aiChoiceButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: aiChoiceColumns, spacing: 7) {
                ForEach(AIChoice.allCases) { choice in
                    Button {
                        runAI(choice)
                    } label: {
                        VStack(spacing: 5) {
                            if isGenerating && choice == .appleIntelligence {
                                ProgressView()
                                    .tint(choice.foregroundColor)
                                    .frame(width: 26, height: 26)
                            } else {
                                choice.icon
                                    .frame(width: 26, height: 26)
                            }
                            Text(choice.title)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(choice.foregroundColor)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(choice.backgroundColor, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(choice.borderColor, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedIdea.isEmpty || isGenerating)
                    .opacity(aiChoiceOpacity(for: choice))
                    .accessibilityHint("\(choice.title)로 바로 만듭니다")
                }
            }

            if isGenerating {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(BrandTheme.accent)
                    Text("Apple AI가 게시물을 만드는 중…")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(BrandTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Apple AI가 게시물을 만드는 중입니다")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let provider = pendingExternalProvider {
                PasteButton(payloadType: String.self) { values in
                    guard let text = values.first else { return }
                    importAIResult(text, from: provider)
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityHint("\(provider.title)에서 복사한 결과를 게시물로 가져옵니다")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isGenerating)
    }

    @MainActor
    private func runAI(_ choice: AIChoice) {
        switch choice {
        case .appleIntelligence:
            Task { await generateDraft() }
        case let .external(provider):
            sharePrompt(with: provider)
        }
    }

    private var aiChoiceColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 7), count: count)
    }

    private func aiChoiceOpacity(for choice: AIChoice) -> Double {
        if trimmedIdea.isEmpty { return 0.48 }
        if isGenerating, choice != .appleIntelligence { return 0.4 }
        return 1
    }

    private var characterCountBinding: Binding<Double> {
        Binding(
            get: { Double(profileStore.profile.controls.characterCount) },
            set: { value in
                var controls = profileStore.profile.controls
                controls.characterCount = Int(value)
                profileStore.profile.controls = controls
            }
        )
    }

    private var generationPresetColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }

    private var mediaOrderEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("길게 눌러 순서 변경")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, media in
                        ZStack(alignment: .topTrailing) {
                            MediaThumbnail(media: media)

                            Button(role: .destructive) {
                                withAnimation(.snappy) { mediaItems.removeAll { $0.id == media.id } }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.72))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(index + 1)번째 미디어 삭제")
                        }
                        .overlay(alignment: .topLeading) {
                            if index == 0 {
                                Text("대표")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(BrandTheme.accent, in: Capsule())
                                    .padding(6)
                            }
                        }
                        .onDrag {
                            draggedMediaID = media.id
                            return NSItemProvider(object: media.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: MediaReorderDropDelegate(
                                targetID: media.id,
                                mediaItems: $mediaItems,
                                draggedMediaID: $draggedMediaID
                            )
                        )
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(index == 0 ? "대표 \(media.kind.title)" : "\(index + 1)번째 \(media.kind.title)")
                        .accessibilityAction(named: "앞으로 이동") { moveMedia(at: index, offset: -1) }
                        .accessibilityAction(named: "뒤로 이동") { moveMedia(at: index, offset: 1) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(BrandTheme.canvas, in: RoundedRectangle(cornerRadius: 14))
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("미리보기").font(.headline)
                Spacer()
                if let source = activeCaptionSource {
                    Label(source.title, systemImage: source.symbolName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let post = generatedPost {
                VStack(alignment: .leading, spacing: 12) {
                    if comparisonCandidates.count > 1 {
                        candidateComparison
                    }

                    if !mediaItems.isEmpty || isLoadingMedia {
                        MediaPreview(items: mediaItems, aspect: previewAspect.ratio, isLoading: isLoadingMedia)
                    }

                    if !draftIsCurrent {
                        Label("조건이 바뀌었어요. 다시 만들어 주세요.", systemImage: "arrow.clockwise.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    if let validation = activeValidationReport {
                        HStack {
                            Label(validation.passesAllRules ? "기준 통과" : "확인 필요", systemImage: validation.passesAllRules ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(validation.passesAllRules ? .green : .orange)
                            Spacer()
                            Text("\(post.characterCount) / \(validation.format.requiredCharacterCount)자").monospacedDigit()
                        }
                        .font(.caption.weight(.semibold))

                        if !validation.passesAllRules {
                            Text(validation.failedRuleDescriptions.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .lineSpacing(2)
                        }
                    }

                    Text(post.composedText)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(BrandTheme.paper, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("생성된 게시물, \(post.characterCount)자")

                    Button { Task { await share(post) } } label: {
                        HStack {
                            if isPreparingShare { ProgressView().tint(.white) }
                            Label(isPreparingShare ? "준비 중" : "Instagram으로 →", systemImage: "paperplane.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isPreparingShare || isGenerating)
                    .accessibilityHint("문구를 자동으로 복사하고 미디어 공유 화면을 엽니다")

                    Label(
                        shareMessage ?? "문구는 자동 복사됩니다",
                        systemImage: shareMessageIsError ? "exclamationmark.triangle.fill" : "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(shareMessageIsError ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Label("게시물을 만들면 여기에 표시됩니다", systemImage: "text.page")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: previewAspect)
        .frame(maxWidth: 540, alignment: .leading)
        .starCard()
    }

    private var candidateComparison: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("결과 비교")
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(comparisonCandidates, id: \.source) { candidate in
                        let report = validationReport(for: candidate)
                        Button {
                            useCandidate(candidate)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(candidate.source.title, systemImage: candidate.source.symbolName)
                                        .font(.caption.weight(.semibold))
                                    Spacer(minLength: 8)
                                    Image(systemName: report.passesAllRules ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(report.passesAllRules ? .green : .orange)
                                }
                                Text(candidate.post.previewSnippet)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                Text("\(candidate.post.characterCount)자 · \(report.passesAllRules ? "통과" : "확인 필요")")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(report.passesAllRules ? .green : .orange)
                            }
                            .frame(width: 220, height: 112, alignment: .topLeading)
                            .padding(12)
                            .background(
                                activeCaptionSource == candidate.source ? BrandTheme.paper : BrandTheme.canvas,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(activeCaptionSource == candidate.source ? BrandTheme.accent : Color.secondary.opacity(0.2), lineWidth: activeCaptionSource == candidate.source ? 1.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("이 결과를 게시물 미리보기에 사용합니다")
                    }
                }
            }
        }
    }

    private var trimmedIdea: String { idea.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var currentDraftSignature: DraftSignature {
        DraftSignature(
            idea: trimmedIdea,
            mood: mood,
            length: length,
            profile: profileStore.profile
        )
    }

    private var draftIsCurrent: Bool {
        generatedSignature == currentDraftSignature
    }

    private var comparisonCandidates: [CaptionCandidate] {
        guard let generatedSignature else { return [] }
        return CaptionSource.allCases.compactMap { source in
            guard let candidate = captionCandidates[source], candidate.signature == generatedSignature else { return nil }
            return candidate
        }
    }

    private var activeValidationReport: CaptionValidationReport? {
        guard let post = generatedPost, let signature = generatedSignature else { return nil }
        return CaptionValidationReport.evaluate(post.composedText, context: validationContext(for: signature))
    }

    private var activeCaptionPassesValidation: Bool {
        activeValidationReport?.passesAllRules == true
    }

    @MainActor
    private func sharePrompt(with provider: DirectAIProvider) {
        guard !trimmedIdea.isEmpty else {
            errorMessage = "이야기를 입력해 주세요."
            return
        }
        errorMessage = nil
        UIPasteboard.general.string = externalPrompt
        pendingExternalProvider = provider
        statusMessage = "공유 화면에서 \(provider.title) 선택"
        shareMessage = nil
        aiPromptShare = AIPromptShare(provider: provider, text: externalPrompt)
    }

    private var externalPrompt: String {
        """
        \(profileStore.profile.prompt(for: trimmedIdea))
        - 선택한 분위기: \(mood.rawValue)
        - 이야기 비중: \(length.storyWeightTitle) — \(length.promptInstruction)
        - 공백과 줄바꿈을 포함해 정확히 \(profileStore.profile.controls.characterCount)자로 작성
        """
    }

    @MainActor
    private func importAIResult(_ text: String, from provider: DirectAIProvider) {
        guard !text.isEmpty else {
            errorMessage = "복사한 결과가 비어 있어요."
            return
        }
        let signature = currentDraftSignature
        let lines = text.components(separatedBy: "\n")
        let hashtags = (lines.first ?? "").split(separator: " ").compactMap { token -> String? in
            guard token.hasPrefix("#") else { return nil }
            return String(token.dropFirst())
        }
        let post = GeneratedPost(
            sourceIdea: signature.idea,
            hook: lines.dropFirst().first ?? "",
            caption: lines.dropFirst().dropLast().joined(separator: "\n"),
            callToAction: lines.last ?? "",
            hashtags: hashtags,
            composedText: text,
            targetCharacterCount: signature.profile.controls.characterCount
        )
        let candidate = CaptionCandidate(
            source: provider.captionSource,
            post: post,
            signature: signature,
            requestID: UUID()
        )
        captionCandidates[candidate.source] = candidate
        useCandidate(candidate)
        pendingExternalProvider = nil
        errorMessage = nil
        statusMessage = validationReport(for: candidate).passesAllRules ? "\(provider.title) 결과 가져옴" : "가져옴 · 기준 확인 필요"
    }

    @MainActor
    private func useCandidate(_ candidate: CaptionCandidate) {
        mediaItems.removeAll { media in
            guard let sourcePostID = media.generatedFromPostID else { return false }
            return sourcePostID != candidate.post.id
        }
        generatedPost = candidate.post
        generatedSignature = candidate.signature
        activeCaptionSource = candidate.source
    }

    private func validationContext(for signature: DraftSignature) -> CaptionValidationContext {
        CaptionValidationContext(
            requiredCharacterCount: signature.profile.controls.characterCount,
            prohibitedPhrases: signature.profile.prohibitedPhrases,
            allowsBodyEmoji: signature.profile.usesEmoji
        )
    }

    private func validationReport(for candidate: CaptionCandidate) -> CaptionValidationReport {
        CaptionValidationReport.evaluate(
            candidate.post.composedText,
            context: validationContext(for: candidate.signature)
        )
    }

    @MainActor
    private func generateDraft() async {
        guard !trimmedIdea.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        statusMessage = nil
        shareMessage = nil
        shareMessageIsError = false
        generatedPost = nil
        generatedSignature = nil
        activeCaptionSource = nil
        do {
            let profile = profileStore.profile
            let signature = currentDraftSignature
            let post: GeneratedPost
            let source: CaptionSource
            if DeviceIntelligenceCaptionGenerator.availability == .available,
               let devicePost = try? await DeviceIntelligenceCaptionGenerator().generate(
                    from: trimmedIdea,
                    mood: mood,
                    length: length,
                    profile: profile
               ) {
                post = devicePost
                source = .device
            } else {
                post = try await PreviewCaptionGenerator().generate(
                    from: trimmedIdea,
                    mood: mood,
                    length: length,
                    profile: profile
                )
                source = .deterministic
            }
            let candidate = CaptionCandidate(
                source: source,
                post: post,
                signature: signature,
                requestID: UUID()
            )
            captionCandidates[source] = candidate
            generatedPost = post
            generatedSignature = signature
            activeCaptionSource = source
            statusMessage = validationReport(for: candidate).passesAllRules ? "완료" : "확인 필요"
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    @MainActor
    private func loadMedia(from items: [PhotosPickerItem], loadID: UUID) async {
        isLoadingMedia = true
        errorMessage = nil
        defer {
            if mediaLoadID == loadID { isLoadingMedia = false }
        }
        var loaded: [ComposerMedia] = []
        for item in items {
            if Task.isCancelled { return }
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard !Task.isCancelled, mediaLoadID == loadID else { return }
            let type = item.supportedContentTypes.first(where: { $0.conforms(to: .image) || $0.conforms(to: .movie) })
            loaded.append(ComposerMedia(
                data: data,
                kind: type?.conforms(to: .movie) == true ? .video : .image,
                fileExtension: type?.preferredFilenameExtension
            ))
        }
        guard !Task.isCancelled, mediaLoadID == loadID else { return }
        if loaded.isEmpty {
            errorMessage = "선택한 미디어를 불러오지 못했어요."
        } else {
            appendMedia(loaded)
            selectedItems = []
        }
    }

    private func receiveDroppedMedia(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        guard mediaItems.count < Self.maxMediaItems else {
            errorMessage = "미디어는 최대 \(Self.maxMediaItems)개까지 추가할 수 있어요."
            return false
        }

        mediaLoadTask?.cancel()
        let loadID = UUID()
        mediaLoadID = loadID
        mediaLoadTask = Task { await loadDroppedMedia(from: providers, loadID: loadID) }
        return true
    }

    @MainActor
    private func loadDroppedMedia(from providers: [NSItemProvider], loadID: UUID) async {
        isLoadingMedia = true
        errorMessage = nil
        defer {
            if mediaLoadID == loadID { isLoadingMedia = false }
        }

        var loaded: [ComposerMedia] = []
        for provider in providers {
            if Task.isCancelled { return }
            let contentTypes = provider.registeredTypeIdentifiers.compactMap(UTType.init)
            guard let type = contentTypes.first(where: { $0.conforms(to: .movie) })
                    ?? contentTypes.first(where: { $0.conforms(to: .image) }),
                  let data = await loadDataRepresentation(from: provider, typeIdentifier: type.identifier),
                  !data.isEmpty else { continue }
            guard !Task.isCancelled, mediaLoadID == loadID else { return }
            loaded.append(ComposerMedia(
                data: data,
                kind: type.conforms(to: .movie) ? .video : .image,
                fileExtension: type.preferredFilenameExtension
            ))
        }

        guard !Task.isCancelled, mediaLoadID == loadID else { return }
        if loaded.isEmpty {
            errorMessage = "드래그한 미디어를 불러오지 못했어요."
        } else {
            appendMedia(loaded)
        }
    }

    private func loadDataRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String
    ) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func appendMedia(_ loaded: [ComposerMedia]) {
        let availableCount = max(0, Self.maxMediaItems - mediaItems.count)
        let accepted = Array(loaded.prefix(availableCount))
        guard !accepted.isEmpty else {
            errorMessage = "미디어는 최대 \(Self.maxMediaItems)개까지 추가할 수 있어요."
            return
        }
        mediaItems.append(contentsOf: accepted)
        errorMessage = nil
        statusMessage = loaded.count > accepted.count
            ? "\(accepted.count)개 추가 · 최대 \(Self.maxMediaItems)개"
            : "\(accepted.count)개 추가"
    }

    private func moveMedia(at index: Int, offset: Int) {
        let destination = index + offset
        guard mediaItems.indices.contains(index), mediaItems.indices.contains(destination) else { return }
        mediaItems.swapAt(index, destination)
    }

    @MainActor
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "이 기기에서는 카메라를 사용할 수 없어요."
            return
        }
        errorMessage = nil
        showsCamera = true
    }

    @MainActor
    private func addCameraPhoto(_ image: UIImage) {
        guard mediaItems.count < Self.maxMediaItems,
              let data = image.jpegData(compressionQuality: 0.92) else { return }
        mediaItems.append(ComposerMedia(data: data, kind: .image, fileExtension: "jpg"))
        statusMessage = "촬영한 사진 추가"
    }

    @MainActor
    private func share(_ post: GeneratedPost) async {
        guard !mediaItems.isEmpty else {
            shareMessage = "사진이나 영상을 먼저 추가해 주세요."
            shareMessageIsError = true
            return
        }
        guard mediaItems.count <= Self.maxMediaItems else {
            shareMessage = "미디어는 최대 \(Self.maxMediaItems)개까지 공유할 수 있어요."
            shareMessageIsError = true
            return
        }
        guard draftIsCurrent else {
            shareMessage = "작성 조건이 바뀌었어요. 게시물을 다시 만든 뒤 공유해 주세요."
            shareMessageIsError = true
            return
        }
        UIPasteboard.general.string = post.composedText
        isPreparingShare = true
        errorMessage = nil
        shareMessage = "공유 준비 중"
        shareMessageIsError = false
        let snapshot = mediaItems
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                try Self.prepareShareFiles(from: snapshot)
            }.value
            let activityItems: [Any]
            if snapshot.count == 1,
               snapshot[0].kind == .image,
               let image = UIImage(contentsOfFile: prepared.items[0].path) {
                activityItems = [image]
            } else {
                activityItems = prepared.items
            }
            shareMessage = activeCaptionPassesValidation ? "문구 복사됨" : "확인 필요 · 문구 복사됨"
            shareMessageIsError = false
            sharePayload = SharePayload(items: activityItems, cleanupURLs: [prepared.directory])
        } catch {
            shareMessage = "미디어 공유를 준비하지 못했어요: \(error.localizedDescription)"
            shareMessageIsError = true
        }
        isPreparingShare = false
    }

    nonisolated private static func prepareShareFiles(from mediaItems: [ComposerMedia]) throws -> (items: [URL], directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("starmanager-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let urls = try mediaItems.enumerated().map { index, media in
                let safeExtension = media.fileExtension?.lowercased().filter { $0.isLetter || $0.isNumber }
                let fallback = media.kind == .image ? "png" : "mov"
                let ext = safeExtension?.isEmpty == false ? safeExtension! : fallback
                let url = directory.appendingPathComponent(String(format: "%02d.%@", index + 1, ext))
                try media.data.write(to: url)
                return url
            }
            return (urls, directory)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    @MainActor
    private func makeImageFromPost() async {
        guard let post = generatedPost, mediaItems.count < Self.maxMediaItems else { return }
        isGeneratingImage = true
        errorMessage = nil

        if imagePlaygroundIsAvailable {
            imageGenerationPostID = post.id
            imagePlaygroundPrompt = post.composedText
            showsImagePlayground = true
            return
        }

        do {
            let payload = GeneratedImagePayload(data: try makeLocalImageData(from: post), fileExtension: "png")
            guard generatedPost?.id == post.id else { return }
            mediaItems.append(ComposerMedia(
                data: payload.data,
                kind: .image,
                fileExtension: payload.fileExtension,
                generatedFromPostID: post.id
            ))
            statusMessage = "이미지 추가"
        } catch {
            errorMessage = error.localizedDescription
        }
        isGeneratingImage = false
    }

    private var imagePlaygroundIsAvailable: Bool {
#if canImport(ImagePlayground)
        if #available(iOS 18.1, *) {
            return ImagePlaygroundViewController.isAvailable
        }
#endif
        return false
    }

    @MainActor
    private func receiveImagePlaygroundResult(_ url: URL) {
        defer {
            isGeneratingImage = false
            imageGenerationPostID = nil
        }
        do {
            let data = try Data(contentsOf: url)
            guard let sourcePostID = imageGenerationPostID,
                  generatedPost?.id == sourcePostID,
                  mediaItems.count < Self.maxMediaItems else { return }
            let fileExtension = url.pathExtension.isEmpty ? "png" : url.pathExtension
            mediaItems.append(ComposerMedia(
                data: data,
                kind: .image,
                fileExtension: fileExtension,
                generatedFromPostID: sourcePostID
            ))
            statusMessage = "이미지 추가"
        } catch {
            errorMessage = "만든 이미지를 불러오지 못했어요."
        }
    }

    private func makeLocalImageData(from post: GeneratedPost) throws -> Data {
        let size = CGSize(width: 1080, height: 1350)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let colors = imagePalette(for: post.sourceIdea)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [colors.background.cgColor, colors.glow.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            cg.setFillColor(colors.accent.withAlphaComponent(0.16).cgColor)
            cg.fillEllipse(in: CGRect(x: -160, y: 180, width: 760, height: 760))
            cg.setFillColor(colors.accent.withAlphaComponent(0.1).cgColor)
            cg.fillEllipse(in: CGRect(x: 590, y: 760, width: 620, height: 620))

            let card = CGRect(x: 110, y: 210, width: 860, height: 930)
            let cardPath = UIBezierPath(roundedRect: card, cornerRadius: 58)
            UIColor.white.withAlphaComponent(0.78).setFill()
            cardPath.fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineSpacing = 15
            let headline = imageHeadline(from: post.sourceIdea)
            (headline as NSString).draw(
                in: CGRect(x: 180, y: 410, width: 720, height: 300),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 68, weight: .bold),
                    .foregroundColor: colors.ink,
                    .paragraphStyle: paragraph
                ]
            )

            let hook = post.hook.trimmingCharacters(in: .whitespacesAndNewlines)
            (hook as NSString).draw(
                in: CGRect(x: 200, y: 760, width: 680, height: 180),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 34, weight: .medium),
                    .foregroundColor: colors.ink.withAlphaComponent(0.72),
                    .paragraphStyle: paragraph
                ]
            )

            let star = UIBezierPath()
            let center = CGPoint(x: 540, y: 330)
            for index in 0..<10 {
                let radius: CGFloat = index.isMultiple(of: 2) ? 64 : 27
                let angle = CGFloat(index) * .pi / 5 - .pi / 2
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                index == 0 ? star.move(to: point) : star.addLine(to: point)
            }
            star.close()
            colors.accent.setFill()
            star.fill()

            ("STAR MANAGER" as NSString).draw(
                in: CGRect(x: 0, y: 1050, width: size.width, height: 60),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 27, weight: .semibold),
                    .foregroundColor: colors.accent,
                    .paragraphStyle: paragraph,
                    .kern: 6
                ]
            )
        }

        guard let data = image.pngData() else { throw AIBackendError.missingImage }
        return data
    }

    private func imageHeadline(from idea: String) -> String {
        let words = idea.split(whereSeparator: \.isWhitespace)
        let headline = words.prefix(6).joined(separator: " ")
        return headline.isEmpty ? "오늘의 이야기를\n한 장에 담다" : headline
    }

    private func imagePalette(for text: String) -> (background: UIColor, glow: UIColor, accent: UIColor, ink: UIColor) {
        let palettes: [(UIColor, UIColor, UIColor, UIColor)] = [
            (#colorLiteral(red: 0.95, green: 0.91, blue: 0.82, alpha: 1), #colorLiteral(red: 0.84, green: 0.76, blue: 0.91, alpha: 1), #colorLiteral(red: 0.38, green: 0.28, blue: 0.58, alpha: 1), #colorLiteral(red: 0.14, green: 0.13, blue: 0.15, alpha: 1)),
            (#colorLiteral(red: 0.9, green: 0.95, blue: 0.93, alpha: 1), #colorLiteral(red: 0.71, green: 0.84, blue: 0.83, alpha: 1), #colorLiteral(red: 0.1, green: 0.38, blue: 0.38, alpha: 1), #colorLiteral(red: 0.1, green: 0.18, blue: 0.18, alpha: 1)),
            (#colorLiteral(red: 0.97, green: 0.9, blue: 0.86, alpha: 1), #colorLiteral(red: 0.95, green: 0.72, blue: 0.58, alpha: 1), #colorLiteral(red: 0.72, green: 0.25, blue: 0.13, alpha: 1), #colorLiteral(red: 0.2, green: 0.12, blue: 0.1, alpha: 1))
        ]
        let value = text.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return palettes[abs(value) % palettes.count]
    }
}

private enum PreviewAspect: String, CaseIterable, Identifiable {
    case square
    case feed
    case vertical

    var id: String { rawValue }
    var title: String {
        switch self { case .square: "1:1"; case .feed: "4:5"; case .vertical: "9:16" }
    }
    var ratio: CGFloat {
        switch self { case .square: 1; case .feed: 4 / 5; case .vertical: 9 / 16 }
    }
}

private struct DraftSignature: Equatable {
    let idea: String
    let mood: PostMood
    let length: PostLength
    let profile: CreatorProfile
}

private extension DirectAIProvider {
    var symbolName: String {
        switch self {
        case .openAI: "bubble.left.and.text.bubble.right"
        case .gemini: "diamond"
        case .grok: "xmark"
        }
    }
    var assetName: String {
        switch self {
        case .openAI: "ChatGPTBrand"
        case .gemini: "GeminiBrand"
        case .grok: "GrokBrand"
        }
    }
    var backgroundColor: Color {
        switch self {
        case .openAI: .white
        case .gemini: Color(red: 0.92, green: 0.95, blue: 1.00)
        case .grok: .black
        }
    }
    var foregroundColor: Color {
        switch self {
        case .openAI, .gemini: Color(red: 0.10, green: 0.10, blue: 0.11)
        case .grok: .white
        }
    }
    var borderColor: Color {
        switch self {
        case .openAI: .black.opacity(0.14)
        case .gemini: Color(red: 0.25, green: 0.52, blue: 0.96).opacity(0.32)
        case .grok: .black
        }
    }
    var captionSource: CaptionSource {
        switch self {
        case .openAI: .chatGPT
        case .gemini: .gemini
        case .grok: .grok
        }
    }
}

private enum AIChoice: Identifiable, CaseIterable, Equatable {
    case appleIntelligence
    case external(DirectAIProvider)

    static let allCases: [AIChoice] = [
        .appleIntelligence,
        .external(.openAI),
        .external(.gemini),
        .external(.grok)
    ]

    var id: String {
        switch self {
        case .appleIntelligence: "apple-ai"
        case let .external(provider): provider.id
        }
    }

    var title: String {
        switch self {
        case .appleIntelligence: "AI"
        case let .external(provider): provider.title
        }
    }

    @ViewBuilder
    var icon: some View {
        switch self {
        case .appleIntelligence:
            Image(systemName: "apple.logo")
                .font(.system(size: 24, weight: .semibold))
        case let .external(provider):
            Image(provider.assetName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    var foregroundColor: Color {
        switch self {
        case .appleIntelligence: .white
        case let .external(provider): provider.foregroundColor
        }
    }

    var backgroundColor: Color {
        switch self {
        case .appleIntelligence: BrandTheme.accent
        case let .external(provider): provider.backgroundColor
        }
    }

    var borderColor: Color {
        switch self {
        case .appleIntelligence: BrandTheme.accent
        case let .external(provider): provider.borderColor
        }
    }
}

private enum CaptionSource: String, CaseIterable, Identifiable, Hashable {
    case device
    case deterministic
    case chatGPT
    case gemini
    case grok

    var id: String { rawValue }
    var title: String {
        switch self {
        case .device: "아이폰 AI"
        case .deterministic: "기본 생성"
        case .chatGPT: "ChatGPT"
        case .gemini: "Gemini"
        case .grok: "Grok"
        }
    }
    var symbolName: String {
        switch self {
        case .device: "apple.intelligence"
        case .deterministic: "iphone"
        case .chatGPT: "bubble.left.and.text.bubble.right"
        case .gemini: "diamond"
        case .grok: "xmark"
        }
    }
}

private struct CaptionCandidate: Identifiable, Equatable {
    var id: CaptionSource { source }
    let source: CaptionSource
    let post: GeneratedPost
    let signature: DraftSignature
    let requestID: UUID
}

private struct StarImagePlaygroundModifier: ViewModifier {
    @Binding var isPresented: Bool
    let prompt: String
    let onCompletion: (URL) -> Void
    let onCancellation: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
#if canImport(ImagePlayground)
        if #available(iOS 18.1, *) {
            content.imagePlaygroundSheet(
                isPresented: $isPresented,
                concept: prompt,
                onCompletion: onCompletion,
                onCancellation: onCancellation
            )
        } else {
            content
        }
#else
        content
#endif
    }
}

private extension View {
    func starImagePlaygroundSheet(
        isPresented: Binding<Bool>,
        prompt: String,
        onCompletion: @escaping (URL) -> Void,
        onCancellation: @escaping () -> Void
    ) -> some View {
        modifier(StarImagePlaygroundModifier(
            isPresented: isPresented,
            prompt: prompt,
            onCompletion: onCompletion,
            onCancellation: onCancellation
        ))
    }
}

private struct MediaPreview: View {
    let items: [ComposerMedia]
    let aspect: CGFloat
    let isLoading: Bool

    var body: some View {
        ZStack {
            BrandTheme.paper
            if isLoading {
                ProgressView("미디어 불러오는 중")
            } else if !items.isEmpty {
                TabView {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, media in
                        ZStack(alignment: .topTrailing) {
                            if media.kind == .image, let image = UIImage(data: media.data) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "play.rectangle.fill").font(.system(size: 42))
                                    Text("영상").font(.subheadline.weight(.medium))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundStyle(BrandTheme.accent)
                            }
                            Text("\(index + 1)/\(items.count)")
                                .font(.caption.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(12)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 34))
                    Text("불러오는 중").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.quaternary) }
        .clipped()
        .accessibilityLabel(items.isEmpty ? "미디어 준비 중" : "선택한 미디어 \(items.count)개 미리보기")
    }
}

private struct ComposerMedia: Identifiable, Sendable {
    let id = UUID()
    let data: Data
    let kind: MediaKind
    let fileExtension: String?
    let generatedFromPostID: UUID?

    init(
        data: Data,
        kind: MediaKind,
        fileExtension: String?,
        generatedFromPostID: UUID? = nil
    ) {
        self.data = data
        self.kind = kind
        self.fileExtension = fileExtension
        self.generatedFromPostID = generatedFromPostID
    }
}

private enum MediaKind: String, Sendable {
    case image
    case video

    var title: String { self == .image ? "사진" : "영상" }
    var symbolName: String { self == .image ? "photo.fill" : "video.fill" }
}

private struct MediaThumbnail: View {
    let media: ComposerMedia
    @State private var videoThumbnailData: Data?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            thumbnail
                .frame(width: 104, height: 118)
                .background(BrandTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.black.opacity(0.09), lineWidth: 1)
                }
                .clipped()

            Image(systemName: media.kind.symbolName)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(6)
                .background(.black.opacity(0.66), in: Circle())
                .padding(7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: media.id) {
            guard media.kind == .video, videoThumbnailData == nil else { return }
            videoThumbnailData = await Self.makeVideoThumbnailData(for: media)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if media.kind == .image, let image = UIImage(data: media.data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let videoThumbnailData, let image = UIImage(data: videoThumbnailData) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                BrandTheme.canvas
                ProgressView()
            }
        }
    }

    private nonisolated static func makeVideoThumbnailData(for media: ComposerMedia) async -> Data? {
        await Task.detached(priority: .utility) {
            let ext = media.fileExtension?.isEmpty == false ? media.fileExtension! : "mov"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("starmanager-thumb-\(media.id.uuidString).\(ext)")
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                try media.data.write(to: url)
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 320, height: 320)
                let image = try generator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: image).jpegData(compressionQuality: 0.72)
            } catch {
                return nil
            }
        }.value
    }
}

private struct MediaReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var mediaItems: [ComposerMedia]
    @Binding var draggedMediaID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedMediaID,
              draggedMediaID != targetID,
              let sourceIndex = mediaItems.firstIndex(where: { $0.id == draggedMediaID }),
              let targetIndex = mediaItems.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.snappy) {
            mediaItems.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedMediaID = nil
        return true
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
    let cleanupURLs: [URL]
}

private struct AIPromptShare: Identifiable {
    let id = UUID()
    let provider: DirectAIProvider
    let text: String
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraFlashMode = .off
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { context.coordinator.install(from: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { context.coordinator.install(from: uiView) }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        func install(from view: UIView) {
            guard let window = view.window, installedWindow !== window else { return }
            uninstall()
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            installedWindow = window
            self.recognizer = recognizer
        }

        func uninstall() {
            if let recognizer { installedWindow?.removeGestureRecognizer(recognizer) }
            recognizer = nil
            installedWindow = nil
        }

        @objc private func dismissKeyboard() {
            installedWindow?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let cleanupURLs: [URL]
    let onCompletion: (Bool, Error?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
            onCompletion(completed, error)
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private enum MediaLoadError: Error { case empty }

#Preview {
    NavigationStack { ComposerView() }
        .environmentObject(CreatorProfileStore())
        .environmentObject(DirectAIConfigurationStore())
}
