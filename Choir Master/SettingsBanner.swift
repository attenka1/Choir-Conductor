import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

@MainActor @Observable
final class AdsConsent {
    static let shared = AdsConsent()
    private(set) var canRequestAds = false
    private(set) var privacyOptionsRequired = false
    private var requestedConsent = false
    private var startedSDK = false

    func prepare() async {
        guard !requestedConsent else { return }
        requestedConsent = true
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // UMP can still permit ads using consent from the previous session.
            print("Ad consent: \(error.localizedDescription)")
        }
        await updateStatus()
    }

    func showPrivacyOptions() async {
        canRequestAds = false
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            print("Ad privacy options: \(error.localizedDescription)")
        }
        await updateStatus()
    }

    private func updateStatus() async {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else {
            canRequestAds = false
            return
        }
        if !startedSDK {
            startedSDK = true
            await MobileAds.shared.start()
        }
        canRequestAds = ConsentInformation.shared.canRequestAds
    }
}

struct SettingsBanner: View {
    var body: some View {
        Group {
            if AdsConsent.shared.canRequestAds {
                BannerContainer()
                    .frame(width: 320, height: 50)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .task { await AdsConsent.shared.prepare() }
    }
}

private struct BannerContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let banner = BannerView(adSize: AdSizeBanner)
        #if DEBUG
        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"
        #else
        banner.adUnitID = "ca-app-pub-3317951565050510/7979352275"
        #endif
        banner.rootViewController = controller
        banner.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])
        banner.load(Request())
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
