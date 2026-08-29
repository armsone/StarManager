import SwiftUI
import UIKit

struct ProfileSettingsView: View {
    @Environment(\.brandTheme) private var theme
    @AppStorage(BrandTheme.appearanceStorageKey) private var appearanceStyleRaw = AppearanceStyle.bk.rawValue
    @AppStorage(SharedGenerationSettings.showsExternalAIBrowserKey) private var showsExternalAIBrowser = false
    @State private var loginProvider: ExternalAIProvider?
    @StateObject private var loginStatusStore = ExternalAILoginStatusStore()

    var body: some View {
        Form {
            Section {
                Toggle("브라우저 보기", isOn: $showsExternalAIBrowser)
                    .accessibilityHint("켜면 외부 AI가 글을 만드는 브라우저를 처음부터 보여줍니다")

                ForEach(ExternalAIProvider.allCases) { provider in
                    let status = loginStatusStore.status(for: provider)
                    Button {
                        loginProvider = provider
                    } label: {
                        HStack {
                            Text(provider.title).foregroundStyle(.primary)
                            Spacer()
                            Label(status.title, systemImage: status.iconName)
                                .labelStyle(.titleAndIcon)
                                .font(.footnote)
                                .foregroundStyle(status.color)
                        }
                    }
                    .accessibilityLabel("\(provider.title), \(status.title)")
                    .accessibilityHint(
                        status == .loggedIn
                            ? "\(provider.title) 계정 페이지를 앱 안에서 다시 엽니다"
                            : "\(provider.title) 공식 로그인 페이지를 앱 안에서 엽니다"
                    )
                }
            } header: {
                BrandSectionTitle(title: "외부 로그인 관리", systemImage: "person.badge.key.fill")
            } footer: {
                Text("브라우저 보기는 기본적으로 꺼져 있어요. 켜면 글을 만드는 과정을 처음부터 볼 수 있어요. 한 번 로그인하면 이 기기에서는 서비스가 로그아웃시키기 전까지 기억돼요. 스타매니저는 비밀번호를 보거나 저장하지 않아요.")
            }

            Section {
                LabeledContent("현재 버전") {
                    Text(Self.appVersionText)
                        .foregroundStyle(.secondary)
                }
                Button {
                    openAppStore()
                } label: {
                    Label("App Store에서 업데이트 확인", systemImage: "arrow.down.circle")
                }
                .accessibilityHint("App Store 앱을 열어 최신 버전이 있는지 확인합니다")
            } header: {
                BrandSectionTitle(title: "앱 업데이트 관리", systemImage: "arrow.triangle.2.circlepath.circle.fill")
            } footer: {
                Text("App Store에서 최신 버전을 확인하고 설치할 수 있어요.")
            }

            Section {
                Picker("테마", selection: $appearanceStyleRaw) {
                    ForEach(AppearanceStyle.allCases) { style in
                        Text(style.title).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                BrandSectionTitle(title: "테마 관리", systemImage: "paintbrush.pointed.fill")
            } footer: {
                Text("BK는 기본 모습, 클래식은 예전 모습, 인터스텔라는 은빛과 금빛이 도는 어두운 모습이에요.")
            }

        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .scrollContentBackground(.hidden)
        .background(theme.canvasGradient)
        .background(
            ExternalAILoginStatusProbeView(store: loginStatusStore)
        )
        .navigationTitle("설정")
        .onAppear {
            loginStatusStore.refreshAll()
        }
        .onChange(of: appearanceStyleRaw) { _, newValue in
            updateAppIcon(for: newValue)
        }
        .sheet(item: $loginProvider) { provider in
            ExternalAILoginSheet(provider: provider) {
                loginStatusStore.markLoggedIn(provider)
            }
        }
    }

    private static var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private func openAppStore() {
        guard let url = URL(string: "itms-apps://apps.apple.com/") else { return }
        UIApplication.shared.open(url)
    }

    private func updateAppIcon(for rawValue: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let iconName: String?
        switch AppearanceStyle(rawValue: rawValue) ?? .bk {
        case .bk: iconName = nil
        case .classic: iconName = "AppIconClassic"
        case .interstellar: iconName = "AppIconInterstellar"
        }
        guard UIApplication.shared.alternateIconName != iconName else { return }
        UIApplication.shared.setAlternateIconName(iconName)
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
    }
    .environmentObject(CreatorProfileStore())
}
