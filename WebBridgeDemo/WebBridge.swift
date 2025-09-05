//
//  WebBridge.swift
//  WebBridgeDemo
//
//  Created by Bishan on 2025-09-05.
//

import Foundation
import WebKit

public final class WebBridge: NSObject, WKScriptMessageHandler {
    public typealias JSON = [String: Any]
    public typealias Handler = (_ payload: JSON?) -> Result<JSON, BridgeError>

    public enum BridgeError: Error {
        case unsupportedMethod(String)
        case invalidPayload(String)
        case internalError(String)

        var code: String {
            switch self {
            case .unsupportedMethod: return "UNSUPPORTED_METHOD"
            case .invalidPayload:    return "INVALID_PAYLOAD"
            case .internalError:     return "INTERNAL_ERROR"
            }
        }

        var message: String {
            switch self {
            case .unsupportedMethod(let s),
                 .invalidPayload(let s),
                 .internalError(let s): return s
            }
        }
    }

    static let channelName = "pickme"

    private weak var webView: WKWebView?
    private var handlers: [String: Handler] = [:]

    /// Provide custom handlers/methods
    public init(handlers: [String: Handler] = [:]) {
        self.handlers = handlers
        super.init()

        // Demo handler showing a single "one function" round-trip:
        // JS: PickMe.invoke("demo", { name: "Bishan" })
        // Native returns: { message: "Hello, Bishan! (from native)" }
        self.handlers["demo"] = { payload in
            let name = (payload?["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "there"
            return .success(["message": "Hello, \(name)! (from native)"])
        }
    }

    func attach(_ webView: WKWebView) { self.webView = webView }

    // MARK: - WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == Self.channelName,
              let dict = message.body as? JSON,
              let id = dict["id"] as? String,
              let method = dict["method"] as? String
        else { return }

        let payload = dict["payload"] as? JSON

        let outcome: Result<JSON, BridgeError>
        if let handler = handlers[method] {
            outcome = handler(payload)
        } else {
            outcome = .failure(.unsupportedMethod(method))
        }

        switch outcome {
        case .success(let result):
            reply(id: id, ok: true, body: ["result": result])
        case .failure(let err):
            reply(id: id, ok: false, body: ["error": ["code": err.code, "message": err.message]])
        }
    }

    // MARK: - Reply (Native → JS)
    private func reply(id: String, ok: Bool, body: JSON) {
        var env: JSON = ["id": id, "ok": ok]
        body.forEach { env[$0.key] = $0.value }

        guard let webView = webView,
              JSONSerialization.isValidJSONObject(env),
              let data = try? JSONSerialization.data(withJSONObject: env, options: []),
              let json = String(data: data, encoding: .utf8)
        else { return }

        // Call the JS resolver with the envelope
        let js = "window.PickMe && window.PickMe._resolveEnvelope(\(json));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Optional: Native → JS event
    /// Call this to push any event to JS: window.PickMe._onEvent({type, payload})
    public func emit(type: String, payload: JSON = [:]) {
        let event: JSON = ["type": type, "payload": payload]
        guard let webView = webView,
              JSONSerialization.isValidJSONObject(event),
              let data = try? JSONSerialization.data(withJSONObject: event, options: []),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.PickMe && window.PickMe._onEvent(\(json));", completionHandler: nil)
    }
}
