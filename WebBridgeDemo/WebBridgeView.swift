//
//  WebBridgeView.swift
//  WebBridgeDemo
//
//  Created by Bishan on 2025-09-05.
//

import SwiftUI
import WebKit

public struct WebBridgeView: UIViewRepresentable {
    private let htmlFileName: String
    private let bridge: WebBridge

    public init(htmlFileName: String = "bridge_demo", handlers: [String: WebBridge.Handler] = [:]) {
        self.htmlFileName = htmlFileName
        self.bridge = WebBridge(handlers: handlers)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(bridge, name: WebBridge.channelName)

        let webView = WKWebView(frame: .zero, configuration: config)
        bridge.attach(webView)

        // Load HTML from bundle
        guard let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html") else {
            assertionFailure("Missing \(htmlFileName).html in bundle resources")
            return webView
        }
        // Use loadFileURL to preserve relative paths if needed
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}
}
