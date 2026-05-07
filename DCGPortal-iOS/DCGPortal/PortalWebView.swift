import SwiftUI
import UIKit
import WebKit

struct PortalWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "downloadFile")
        userContentController.addUserScript(WKUserScript(
            source: Self.downloadBridgeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black

        context.coordinator.webView = webView
        loadPortal(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func loadPortal(in webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html")
            ?? Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
            webView.loadHTMLString("<html><body style='background:#000;color:#fff;font-family:-apple-system'>Missing bundled portal file.</body></html>", baseURL: nil)
            return
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    static let downloadBridgeScript = """
    (function installNativeDownloadBridge() {
      function patch() {
        if (!window.XLSX || !window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.downloadFile) {
          return false;
        }
        if (window.XLSX.__dcgNativePatched) {
          return true;
        }
        var originalWriteFile = window.XLSX.writeFile;
        window.XLSX.writeFile = function(workbook, fileName, opts) {
          try {
            var options = Object.assign({}, opts || {}, { bookType: 'xlsx', type: 'base64' });
            var base64 = window.XLSX.write(workbook, options);
            window.webkit.messageHandlers.downloadFile.postMessage({
              fileName: fileName || 'DCG-Report.xlsx',
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              base64: base64
            });
          } catch (error) {
            console.error('[DCG native download bridge]', error);
            if (typeof originalWriteFile === 'function') {
              originalWriteFile.apply(window.XLSX, arguments);
            }
          }
        };
        window.XLSX.__dcgNativePatched = true;
        return true;
      }

      if (!patch()) {
        var tries = 0;
        var timer = setInterval(function() {
          tries += 1;
          if (patch() || tries > 40) {
            clearInterval(timer);
          }
        }, 250);
      }
    })();
    """
}

final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    weak var webView: WKWebView?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(PortalWebView.downloadBridgeScript)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "downloadFile",
              let payload = message.body as? [String: Any],
              let base64 = payload["base64"] as? String,
              let data = Data(base64Encoded: base64) else {
            return
        }

        let fileName = sanitizedFileName(payload["fileName"] as? String ?? "DCG-Report.xlsx")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: .atomic)
            presentShareSheet(for: fileURL)
        } catch {
            print("Failed to write exported report: \(error)")
        }
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if ["http", "https", "file", "data", "blob"].contains(url.scheme?.lowercased()) {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    private func sanitizedFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: #"/\?%*|"<>:"#)
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "DCG-Report.xlsx" : cleaned
    }

    private func presentShareSheet(for fileURL: URL) {
        DispatchQueue.main.async {
            guard let viewController = UIApplication.shared.topViewController() else {
                return
            }

            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }
            viewController.present(activityViewController, animated: true)
        }
    }
}

private extension UIApplication {
    func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        if let navigationController = root as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }
        if let tabBarController = root as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topViewController(base: selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
