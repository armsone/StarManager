import SwiftUI
import WebKit

enum ExternalAIProvider: String, CaseIterable, Identifiable, Sendable, Hashable {
    case openAI
    case gemini
    case grok
    case claude

    /// 사용자에게 제공하는 외부 AI 목록. Grok은 결과에 서비스 UI 문구가 반복해서
    /// 섞이는 문제가 있어 생성 및 로그인 관리 화면에서 제외한다.
    static let allCases: [ExternalAIProvider] = [.gemini, .openAI, .claude]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: "ChatGPT"
        case .gemini: "Gemini"
        case .grok: "Grok"
        case .claude: "Claude"
        }
    }
}

/// ChatGPT·Gemini·Claude 웹사이트를 앱 안에서 열어 프롬프트를 채워 넣고,
/// 완성된 답변을 감지해 가져올 수 있게 해 주는 화면.
struct ExternalAIBrowserSheet: View {
    let provider: ExternalAIProvider
    let prompt: String
    let onImport: (String) -> Void
    let onManualCopyFallback: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var bridge = ExternalAIBrowserBridge()
    @State private var hasFilledPrompt = false
    @State private var fillFailed = false
    @State private var hasImported = false
    @State private var isAutoFilling = false
    @State private var hasSubmittedPrompt = false
    @State private var submitFailed = false

    var body: some View {
        NavigationStack {
            ExternalAIWebView(provider: provider, bridge: bridge)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text("\(provider.title)에서 만들기")
                                .font(.subheadline.weight(.semibold))
                            Label(statusText, systemImage: statusIcon)
                                .font(.caption2)
                                .foregroundStyle(statusColor)
                                .lineLimit(1)
                        }
                    }
                    ToolbarItemGroup(placement: .confirmationAction) {
                        if !bridge.latestAnswer.isEmpty, !hasImported {
                            Button {
                                importAnswer(bridge.latestAnswer)
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                            }
                            .accessibilityLabel("지금 가져오기")
                            .accessibilityHint("지금 보이는 답변을 바로 게시물로 가져옵니다")
                        }
                        Menu {
                            Button {
                                Task {
                                    if await fillPrompt(force: true) {
                                        await submitPromptWhenReady()
                                    }
                                }
                            } label: {
                                Label("다시 넣기", systemImage: "text.cursor")
                            }
                            .disabled(!bridge.isPageReady)

                            Button {
                                UIPasteboard.general.string = prompt
                                onManualCopyFallback()
                            } label: {
                                Label("문구 복사", systemImage: "doc.on.doc")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("추가 옵션")
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .task(id: bridge.navigationGeneration) {
                    await autoFillWhenReady()
                }
                .onChange(of: bridge.isAnswerStable) { _, stable in
                    guard stable, !bridge.latestAnswer.isEmpty, !hasImported else { return }
                    importAnswer(bridge.latestAnswer)
                }
        }
    }

    private func importAnswer(_ text: String) {
        guard !hasImported else { return }
        let cleanedText = Self.cleanedImportedAnswer(text, provider: provider)
        guard !cleanedText.isEmpty else { return }
        hasImported = true
        UIPasteboard.general.string = cleanedText
        dismiss()
        onImport(cleanedText)
    }

    private static func cleanedImportedAnswer(_ text: String, provider: ExternalAIProvider) -> String {
        var normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider == .grok {
            normalizedText = removingGrokWorkDurationPrefix(from: normalizedText)
        }

        var lines = normalizedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)

        if provider == .grok,
           let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           isGrokWorkDurationHeader(first) {
            lines.removeFirst()
        }

        let removableHeaders: Set<String> = ["글", "본문", "답변", "결과", "text", "plaintext", "markdown"]
        if lines.count > 1,
           let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           removableHeaders.contains(first.lowercased()) {
            lines.removeFirst()
        }

        while let first = lines.first, first.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
            lines.removeFirst()
        }
        while let last = lines.last, last.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
            lines.removeLast()
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isGrokWorkDurationHeader(_ text: String) -> Bool {
        let patterns = [
            #"^\d+\s*(?:s|m|h|초|분|시간)\s*(?:동안\s*)?(?:작업함|생각함)$"#,
            #"^(?:worked|thought)\s+for\s+\d+\s*(?:s|m|h|seconds?|minutes?|hours?)$"#
        ]
        return patterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func removingGrokWorkDurationPrefix(from text: String) -> String {
        // Grok의 작업시간 UI에는 일반 공백처럼 보이는 format 문자나 U+2028/U+2029가
        // 섞일 수 있어 줄 단위 비교만으로는 제거되지 않는다. 응답 맨 앞의 UI 문구를
        // 보이지 않는 문자까지 포함해 직접 잘라 낸다.
        let patterns = [
            #"^[\s\p{Cf}]*\d+[\s\p{Cf}]*(?:s|m|h|초|분|시간)[\s\p{Cf}]*(?:동안)?[\s\p{Cf}]*(?:작업함|생각함)[\s\p{Cf}]*"#,
            #"^[\s\p{Cf}]*(?:worked|thought)[\s\p{Cf}]+for[\s\p{Cf}]+\d+[\s\p{Cf}]*(?:s|m|h|seconds?|minutes?|hours?)[\s\p{Cf}]*"#
        ]
        var result = text
        for pattern in patterns {
            if let range = result.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                result.removeSubrange(range)
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 각 메인 프레임 내비게이션이 끝날 때마다(로그인 리디렉션 포함) 호출되어,
    /// 입력창이 나타날 때까지 정해진 시간(45초) 동안 재시도한다.
    /// `.task(id:)`가 새 내비게이션 세대마다 이전 시도를 자동으로 취소해 준다.
    private func autoFillWhenReady() async {
        guard !hasSubmittedPrompt else { return }
        isAutoFilling = true
        defer { isAutoFilling = false }
        let deadline = Date().addingTimeInterval(45)
        while !Task.isCancelled, Date() < deadline, !hasSubmittedPrompt {
            if bridge.isPageReady {
                if await fillPrompt(force: false) {
                    if await submitPromptWhenReady() {
                        return
                    }
                    // ChatGPT가 초기 화면을 늦게 다시 그리면 방금 채운 입력창이 교체되어
                    // 문구가 사라질 수 있다. 전송이 확인되지 않은 경우 입력 완료 상태를
                    // 되돌려 같은 내비게이션 안에서도 다시 채우고 전송한다.
                    hasFilledPrompt = false
                }
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        if !Task.isCancelled, !hasSubmittedPrompt {
            fillFailed = true
        }
    }

    @discardableResult
    private func submitPromptWhenReady() async -> Bool {
        guard !hasSubmittedPrompt else { return true }
        submitFailed = false
        let deadline = Date().addingTimeInterval(15)
        while !Task.isCancelled, Date() < deadline, !hasSubmittedPrompt {
            if await bridge.submitPrompt() {
                hasSubmittedPrompt = true
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        if !Task.isCancelled, !hasSubmittedPrompt {
            submitFailed = true
        }
        return hasSubmittedPrompt
    }

    @discardableResult
    private func fillPrompt(force: Bool) async -> Bool {
        let success = await bridge.fillPrompt(prompt, force: force)
        if success {
            hasFilledPrompt = true
            fillFailed = false
        } else if force {
            fillFailed = true
        }
        return success
    }

    private var statusText: String {
        if hasImported {
            return "답변을 가져왔어요"
        }
        if bridge.isGenerating {
            return "\(provider.title)가 답변을 쓰는 중…"
        }
        if !bridge.latestAnswer.isEmpty {
            return "답변이 끝나가는 중이에요…"
        }
        if !bridge.isPageReady {
            return "페이지를 불러오는 중…"
        }
        if hasFilledPrompt {
            if submitFailed { return "자동 전송 실패 · 보내기 버튼을 눌러 주세요" }
            if hasSubmittedPrompt { return "답변을 기다리는 중…" }
            return "자동으로 보내는 중…"
        }
        if isAutoFilling {
            return "입력창에 자동으로 채우는 중…"
        }
        if fillFailed {
            return "채우기 실패 · ⋯ 메뉴에서 다시 넣기나 문구 복사를 써 주세요"
        }
        return "입력창을 기다리는 중…"
    }

    private var statusIcon: String {
        if hasImported { return "checkmark.circle.fill" }
        if fillFailed { return "exclamationmark.triangle.fill" }
        return "info.circle"
    }

    private var statusColor: Color {
        if hasImported { return .green }
        if fillFailed { return .orange }
        return .secondary
    }
}

/// 설정 화면에서 로그인만 하기 위해 여는 가벼운 브라우저.
/// 프롬프트를 채우거나 답변을 읽지 않고, 제공사의 공식 로그인 페이지만 보여준다.
struct ExternalAILoginSheet: View {
    let provider: ExternalAIProvider

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExternalAILoginWebView(provider: provider)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("\(provider.title) 로그인")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }
                    }
                }
        }
    }
}

private struct ExternalAILoginWebView: UIViewRepresentable {
    let provider: ExternalAIProvider

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 앱 안에서만 쓰는 영구 저장소. Composer의 AI 브라우저와 이 저장소를 공유해 로그인이
        // 이어지지만, 사파리의 쿠키 저장소와는 별개이며 제공사가 세션을 만료시키면 다시 로그인해야 한다.
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: provider.chatURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// WKWebView 안 상태(페이지 준비, 생성 중, 답변 안정 여부)를 SwiftUI로 전달하는 저장소.
@MainActor
final class ExternalAIBrowserBridge: ObservableObject {
    @Published fileprivate(set) var isPageReady = false
    @Published fileprivate(set) var isGenerating = false
    @Published fileprivate(set) var isAnswerStable = false
    @Published fileprivate(set) var latestAnswer = ""
    /// 메인 프레임 내비게이션이 끝날 때마다 증가한다. SwiftUI가 이 값을 `.task(id:)`로 관찰해
    /// 로그인 리디렉션 이후에도 자동 채우기 시도를 다시 시작할 수 있게 한다.
    @Published fileprivate(set) var navigationGeneration = 0

    fileprivate weak var webView: WKWebView?

    /// 입력창에 프롬프트를 채운다. 자동으로 보내지는 않는다.
    /// `force`가 false면 사용자가 이미 다른 내용을 입력해 둔 경우 덮어쓰지 않는다.
    /// JavaScript가 실제로 입력창을 채웠는지 여부를 그대로 돌려준다.
    @discardableResult
    func fillPrompt(_ prompt: String, force: Bool) async -> Bool {
        guard let webView else { return false }
        let literal = ExternalAIBrowserScripts.jsStringLiteral(prompt)
        let script = "window.__starManagerFillPrompt && window.__starManagerFillPrompt(\(literal), \(force));"
        do {
            let result = try await webView.evaluateJavaScript(script)
            let success = Self.boolean(from: result)
            if success {
                isAnswerStable = false
                latestAnswer = ""
            }
            return success
        } catch {
            return false
        }
    }

    func submitPrompt() async -> Bool {
        guard let webView else { return false }
        do {
            let attempted = try await webView.evaluateJavaScript(
                "window.__starManagerSendPrompt && window.__starManagerSendPrompt();"
            )
            guard Self.boolean(from: attempted) else { return false }
            try? await Task.sleep(nanoseconds: 700_000_000)
            let verified = try await webView.evaluateJavaScript(
                "window.__starManagerDidSubmit && window.__starManagerDidSubmit();"
            )
            return Self.boolean(from: verified)
        } catch {
            return false
        }
    }

    private static func boolean(from value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.boolValue }
        return (value as? Bool) ?? false
    }

    fileprivate func resetForNewNavigation() {
        isPageReady = false
        isGenerating = false
        isAnswerStable = false
        latestAnswer = ""
    }

    fileprivate func markNavigationFinished() {
        isPageReady = true
        navigationGeneration += 1
    }

    fileprivate func receive(text: String, stable: Bool, generating: Bool) {
        isGenerating = generating
        if !text.isEmpty { latestAnswer = text }
        isAnswerStable = stable && !text.isEmpty
    }
}

private struct ExternalAIWebView: UIViewRepresentable {
    let provider: ExternalAIProvider
    @ObservedObject var bridge: ExternalAIBrowserBridge

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 앱 안에서만 쓰는 영구 저장소. 이 저장소를 로그인 전용 브라우저와 공유해 로그인 상태를
        // 유지하지만, 사파리의 쿠키 저장소와는 별개이며 제공사가 세션을 만료시키면 다시 로그인해야 한다.
        configuration.websiteDataStore = .default()

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "starManagerBridge")
        controller.addUserScript(WKUserScript(
            source: ExternalAIBrowserScripts.observerScript(for: provider),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        bridge.webView = webView
        webView.load(URLRequest(url: provider.chatURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "starManagerBridge")
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let bridge: ExternalAIBrowserBridge

        init(bridge: ExternalAIBrowserBridge) {
            self.bridge = bridge
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            bridge.resetForNewNavigation()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.markNavigationFinished()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "starManagerBridge", let body = message.body as? [String: Any] else { return }
            let text = (body["text"] as? String) ?? ""
            let stable = (body["stable"] as? Bool) ?? false
            let generating = (body["generating"] as? Bool) ?? false
            bridge.receive(text: text, stable: stable, generating: generating)
        }
    }
}

private extension ExternalAIProvider {
    var chatURL: URL {
        switch self {
        case .openAI: URL(string: "https://chatgpt.com/")!
        case .gemini: URL(string: "https://gemini.google.com/app")!
        case .grok: URL(string: "https://grok.com/")!
        case .claude: URL(string: "https://claude.ai/new")!
        }
    }
}

/// 제공사별 DOM 구조가 바뀌어도 최대한 버티도록 여러 선택자를 순서대로 시도하는 주입/감시 스크립트.
private enum ExternalAIBrowserScripts {
    static func jsStringLiteral(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }

    static func observerScript(for provider: ExternalAIProvider) -> String {
        let config = selectors(for: provider)
        return """
        (function() {
          if (window.__starManagerInstalled) { return; }
          window.__starManagerInstalled = true;

          const inputSelectors = \(jsArray(config.input));
          const assistantSelectors = \(jsArray(config.assistant));
          const generatingSelectors = \(jsArray(config.generating));
          const sendSelectors = \(jsArray(config.send));

          function queryFirst(selectors) {
            for (const sel of selectors) {
              try {
                const el = document.querySelector(sel);
                if (el) return el;
              } catch (e) {}
            }
            return null;
          }

          function queryAll(selectors) {
            for (const sel of selectors) {
              try {
                const list = document.querySelectorAll(sel);
                if (list && list.length > 0) return Array.from(list);
              } catch (e) {}
            }
            return [];
          }

          function isVisible(element) {
            if (!element) return false;
            const style = window.getComputedStyle(element);
            if (style.display === 'none' || style.visibility === 'hidden') return false;
            return element.getClientRects().length > 0;
          }

          function isGeneratingNow() {
            return queryAll(generatingSelectors).some(isVisible);
          }

          function extractAnswerText(element) {
            // ChatGPT 등의 코드 블록 상단에는 `글`, `text` 같은 UI 머리말과 복사 버튼이 있다.
            // 전체 innerText 대신 실제 code 요소만 읽어 그 머리말이 게시물에 섞이지 않게 한다.
            const codeBlocks = Array.from(element.querySelectorAll('pre code'))
              .map(function(code) { return (code.innerText || code.textContent || '').trim(); })
              .filter(Boolean);
            if (codeBlocks.length > 0) return codeBlocks.join('\\n\\n');
            return (element.innerText || element.textContent || '').trim();
          }

          // force가 false일 때는 사용자가 우리가 넣은 것과 다른 내용을 이미 입력해 두었다면
          // 덮어쓰지 않는다(자동 채우기가 사용자 편집을 방해하지 않도록).
          window.__starManagerFillPrompt = function(text, force) {
            const el = queryFirst(inputSelectors);
            if (!el) return false;
            const isTextField = el.tagName === 'TEXTAREA' || el.tagName === 'INPUT';
            const current = (isTextField ? el.value : (el.innerText || el.textContent || '')).trim();
            // 이전 시도에서 같은 문구가 입력창에 남아 있는 경우에도 준비 완료로 인정한다.
            // 이 경로가 없으면 재실행 시 사용자 입력으로 오인해 전송 단계로 넘어가지 못한다.
            if (current === text.trim()) {
              window.__starManagerLastFilled = text;
              return true;
            }
            if (!force && current.length > 0 && current !== window.__starManagerLastFilled) {
              return false;
            }
            el.focus();
            if (isTextField) {
              const proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
              const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
              setter.call(el, text);
              el.dispatchEvent(new Event('input', { bubbles: true }));
              el.dispatchEvent(new Event('change', { bubbles: true }));
            } else if (el.isContentEditable) {
              const selection = window.getSelection();
              const range = document.createRange();
              range.selectNodeContents(el);
              selection.removeAllRanges();
              selection.addRange(range);
              const inserted = document.execCommand('insertText', false, text);
              if (!inserted) {
                el.replaceChildren(document.createTextNode(text));
                el.dispatchEvent(new InputEvent('input', {
                  bubbles: true,
                  inputType: 'insertText',
                  data: text
                }));
              }
              el.dispatchEvent(new Event('change', { bubbles: true }));
            } else {
              return false;
            }
            window.__starManagerLastFilled = text;
            return true;
          };

          window.__starManagerSendPrompt = function() {
            const input = queryFirst(inputSelectors);
            const button = queryFirst(sendSelectors);
            if (!input || !button || button.disabled || button.getAttribute('aria-disabled') === 'true') return false;
            const rect = button.getBoundingClientRect();
            if (rect.width === 0 || rect.height === 0) return false;

            window.__starManagerSubmitAttempts = (window.__starManagerSubmitAttempts || 0) + 1;
            const attempt = window.__starManagerSubmitAttempts;
            input.focus();

            if (attempt === 1) {
              button.focus();
              button.click();
            } else if (attempt === 2) {
              button.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, cancelable: true, pointerType: 'touch' }));
              button.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, cancelable: true, pointerType: 'touch' }));
              button.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
            } else if (attempt === 3) {
              const form = input.closest('form') || button.closest('form');
              if (form && typeof form.requestSubmit === 'function') {
                form.requestSubmit(button);
              }
            } else {
              ['keydown', 'keypress', 'keyup'].forEach(function(type) {
                input.dispatchEvent(new KeyboardEvent(type, {
                  key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
                  bubbles: true, cancelable: true
                }));
              });
            }
            return true;
          };

          window.__starManagerDidSubmit = function() {
            const el = queryFirst(inputSelectors);
            const isTextField = el && (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT');
            const current = el ? (isTextField ? el.value : (el.innerText || el.textContent || '')).trim() : '';
            const answerStarted = queryAll(assistantSelectors).length > baselineCount;
            const generating = isGeneratingNow();
            return current.length === 0 || answerStarted || generating;
          };

          // 감시 시작 시점의 답변 개수를 기준으로 삼아, 이전 대화 답변이나 사용자가 입력한 프롬프트를
          // 새 답변으로 잘못 가져오지 않도록 한다.
          const baselineCount = queryAll(assistantSelectors).length;
          let lastText = '';
          let stableTicks = 0;

          setInterval(function() {
            const items = queryAll(assistantSelectors);
            // Gemini는 답변 완료 뒤에도 숨겨진 mat-progress-spinner를 DOM에 남겨 둔다.
            // 실제로 보이는 생성 표시만 검사해야 완료된 응답을 정상적으로 가져올 수 있다.
            const generating = isGeneratingNow();
            if (items.length <= baselineCount) {
              window.webkit.messageHandlers.starManagerBridge.postMessage({ text: '', stable: false, generating: generating });
              return;
            }
            const latest = items[items.length - 1];
            const text = extractAnswerText(latest);
            if (text.length > 0 && text === lastText && !generating) {
              stableTicks += 1;
            } else {
              stableTicks = 0;
            }
            lastText = text;
            // 스트리밍 중 잠깐 멈춘 순간을 완성으로 착각하지 않도록, 변화 없는 상태가
            // 약 3초 이상(0.9초 주기 x 4회) 이어져야 안정된 답변으로 판단한다.
            const stable = stableTicks >= 4 && text.length > 0;
            window.webkit.messageHandlers.starManagerBridge.postMessage({ text: text, stable: stable, generating: generating });
          }, 900);
        })();
        """
    }

    private static func jsArray(_ values: [String]) -> String {
        let items = values.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" }.joined(separator: ", ")
        return "[\(items)]"
    }

    private struct Selectors {
        let input: [String]
        let assistant: [String]
        let generating: [String]
        let send: [String]
    }

    private static func selectors(for provider: ExternalAIProvider) -> Selectors {
        switch provider {
        case .openAI:
            Selectors(
                input: [
                    "#prompt-textarea",
                    "div[contenteditable='true']#prompt-textarea",
                    "form div[contenteditable='true']",
                    "textarea[data-testid]"
                ],
                assistant: [
                    "[data-message-author-role='assistant']"
                ],
                generating: [
                    "button[data-testid='stop-button']",
                    "button[aria-label*='Stop']",
                    "button[aria-label*='중지']"
                ],
                send: [
                    "#composer-submit-button",
                    "button[data-testid='send-button']",
                    "form button[type='submit']",
                    "button[aria-label*='프롬프트 보내기']",
                    "button[aria-label*='Send']",
                    "button[aria-label*='보내기']"
                ]
            )
        case .gemini:
            Selectors(
                input: [
                    "div.ql-editor[contenteditable='true']",
                    "rich-textarea div[contenteditable='true']",
                    "div[aria-label*='프롬프트']",
                    "div[contenteditable='true']",
                    "textarea"
                ],
                assistant: [
                    "model-response .markdown",
                    "message-content .markdown",
                    "div.model-response-text",
                    "model-response"
                ],
                generating: [
                    "button[aria-label*='Stop']",
                    "button[aria-label*='중지']",
                    "mat-progress-spinner",
                    ".loading-indicator"
                ],
                send: [
                    "button.send-button",
                    "button[aria-label*='Send']",
                    "button[aria-label*='보내기']"
                ]
            )
        case .grok:
            Selectors(
                input: [
                    "textarea",
                    "div[contenteditable='true']"
                ],
                assistant: [
                    "[data-testid='grok-response']",
                    "div.message-bubble",
                    "div[class*='message'][class*='assistant']"
                ],
                generating: [
                    "button[aria-label*='Stop']",
                    "button[data-testid='stop-button']"
                ],
                send: [
                    "button[aria-label*='Send']",
                    "button[aria-label*='보내기']",
                    "button[type='submit']"
                ]
            )
        case .claude:
            Selectors(
                input: [
                    "div.ProseMirror[contenteditable='true']",
                    "div[contenteditable='true'][data-placeholder]",
                    "div[contenteditable='true']"
                ],
                assistant: [
                    "[data-is-streaming] .font-claude-response-body",
                    ".font-claude-response-body",
                    "div[data-testid*='assistant']"
                ],
                generating: [
                    "button[aria-label*='Stop']",
                    "button[aria-label*='중지']"
                ],
                send: [
                    "button[aria-label='Send Message']",
                    "button[aria-label*='Send']",
                    "button[aria-label*='보내기']",
                    "button[type='submit']"
                ]
            )
        }
    }
}
