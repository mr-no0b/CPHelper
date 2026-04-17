import SwiftUI
import WebKit

struct WebDestination: Identifiable, Hashable {
    let title: String
    let url: URL

    var id: String {
        url.absoluteString
    }
}

struct CodeforcesWebPageView: View {
    let title: String
    let url: URL

    var body: some View {
        CodeforcesWebView(url: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct CodeforcesWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
