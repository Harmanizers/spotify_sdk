import Flutter
import SpotifyiOS

/// Obtains an OAuth **authorization code** on iOS, the way the Android plugin
/// already does with `AuthorizationResponse.Type.CODE`.
///
/// Why this exists at all: `getSwapToken` used to route to
/// `SPTAppRemote.authorizeAndPlayURI`, whose success hands back
/// `connectionParameters.accessToken`. That is an access token, not a code, so
/// a backend presenting it for exchange is told `invalid_grant`, "Invalid
/// authorization code". The two platforms answered the same method with two
/// different kinds of credential, and only one of them was the documented one.
///
/// `SPTSessionManager` is the SDK's own answer. It authorizes through the
/// Spotify app when one is installed and through ASWebAuthentication when none
/// is, and it offers `shouldRequestAccessTokenWithAuthorizationCode`, whose
/// contract is explicit: return `NO` and the code is yours. That is exactly the
/// hand-off this needs, so the swap never happens and no client secret is ever
/// wanted on the device.
///
/// `tokenSwapURL` is set because the SDK only runs the authorization-code flow
/// when it has one; it is never called, because the delegate below always
/// declines the swap. Any absolute URL would do, and the caller's redirect is
/// used so a reader never has to wonder which host it is.
@available(iOS 13.0, *)
class AuthorizationCodeHandler: NSObject {
    private var sessionManager: SPTSessionManager?
    private var pendingResult: FlutterResult?

    /// Whether an authorization is outstanding, so the plugin knows to give the
    /// redirect to the session manager rather than to the App Remote. Without
    /// this the App Remote parses a code-carrying redirect, finds no access
    /// token in it, and reports an authentication error for an authorization
    /// that in fact succeeded.
    var isAwaitingRedirect: Bool { pendingResult != nil }

    /// The method-channel entry point. Mirrors AuthHandler's argument checks so
    /// a missing argument reads the same whichever authorization was asked for.
    func requestAuthorizationCode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let clientID = arguments[SpotifySdkConstants.paramClientId] as? String,
              !clientID.isEmpty,
              let rawRedirect = arguments[SpotifySdkConstants.paramRedirectUrl] as? String,
              let redirectURL = URL(string: rawRedirect) else {
            result(SpotifyErrorMapper.argumentError("One or more arguments are missing"))
            return
        }
        requestAuthorizationCode(
            clientID: clientID,
            redirectURL: redirectURL,
            scope: arguments[SpotifySdkConstants.scope] as? String ?? "",
            result: result
        )
    }

    func requestAuthorizationCode(
        clientID: String,
        redirectURL: URL,
        scope: String,
        result: @escaping FlutterResult
    ) {
        if let inFlight = pendingResult {
            // One authorization at a time. A second request would strand the
            // first result, and Flutter fails on a result delivered twice.
            inFlight(SpotifyErrorMapper.makeError(
                code: "errorAuthorizing",
                message: "Superseded by another authorization request"
            ))
        }
        pendingResult = result

        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        configuration.tokenSwapURL = redirectURL

        let manager = SPTSessionManager(configuration: configuration, delegate: self)
        sessionManager = manager
        manager.initiateSession(withRawScope: scope, options: .default, campaign: nil)
    }

    /// Hands a redirect to the session manager. Answers whether it was for an
    /// authorization this handler started, so the caller can fall through to
    /// the App Remote when it was not.
    func handle(url: URL) -> Bool {
        guard let manager = sessionManager, isAwaitingRedirect else {
            return false
        }
        manager.application(UIApplication.shared, open: url, options: [:])
        return true
    }

    private func deliver(_ value: Any?) {
        pendingResult?(value)
        pendingResult = nil
    }
}

@available(iOS 13.0, *)
extension AuthorizationCodeHandler: SPTSessionManagerDelegate {
    /// The whole point of this class. Declining the swap keeps the code, which
    /// is what the caller asked for and what the backend can exchange.
    func sessionManager(
        manager: SPTSessionManager,
        shouldRequestAccessTokenWith code: String
    ) -> Bool {
        deliver(code)
        return false
    }

    /// Reached only if the swap above were ever allowed. Answering the token
    /// here would put this back where it started, so it is refused loudly
    /// rather than quietly handing back the wrong kind of credential again.
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        deliver(SpotifyErrorMapper.makeError(
            code: "errorAuthorizing",
            message: "Authorization answered a session rather than a code"
        ))
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        let nsError = error as NSError
        // The SDK reports a declined consent screen as its own error rather
        // than as a cancellation, and the Dart side tells a refusal from a
        // failure by the message, so the underlying one is carried through.
        deliver(SpotifyErrorMapper.makeError(
            code: String(nsError.code),
            message: nsError.localizedDescription,
            details: "\(nsError.domain) \(nsError.code): \(nsError.userInfo)"
        ))
    }
}
