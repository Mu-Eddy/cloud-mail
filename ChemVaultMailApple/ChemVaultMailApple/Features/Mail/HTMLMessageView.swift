import SwiftUI
import WebKit

#if os(macOS)
struct HTMLMessageView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(wrappedHTML, baseURL: nil)
    }

    private var wrappedHTML: String {
        """
        <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1"><style>body{font:-apple-system-body;margin:0;padding:0;color:CanvasText;background:transparent;}img{max-width:100%;height:auto;}</style></head>
        <body>\(html)</body>
        </html>
        """
    }
}
#else
struct HTMLMessageView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.isOpaque = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(wrappedHTML, baseURL: nil)
    }

    private var wrappedHTML: String {
        """
        <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1"><style>body{font:-apple-system-body;margin:0;padding:0;color:CanvasText;background:transparent;}img{max-width:100%;height:auto;}</style></head>
        <body>\(html)</body>
        </html>
        """
    }
}
#endif

