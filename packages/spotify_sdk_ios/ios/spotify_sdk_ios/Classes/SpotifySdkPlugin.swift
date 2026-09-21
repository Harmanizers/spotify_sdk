import Flutter
import SpotifyiOS

public class SpotifySdkPlugin: NSObject, FlutterPlugin {
    private static var instance = SpotifySdkPlugin()

    private let remoteManager = RemoteManager.shared
    private lazy var authHandler = AuthHandler(remoteManager: remoteManager)
    @available(iOS 13.0, *)
    private var authorizationCodeHandler: AuthorizationCodeHandler {
        if let existing = _authorizationCodeHandler as? AuthorizationCodeHandler {
            return existing
        }
        let fresh = AuthorizationCodeHandler()
        _authorizationCodeHandler = fresh
        return fresh
    }
    // Untyped because a stored property cannot carry an availability
    // annotation, and this plugin still builds for iOS 12.
    private var _authorizationCodeHandler: AnyObject?
    private lazy var playerHandler = PlayerHandler(remoteManager: remoteManager)
    private lazy var libraryHandler = LibraryHandler(remoteManager: remoteManager)
    private lazy var imageHandler = ImageHandler(remoteManager: remoteManager)

    /// A connect deferred from the authorize redirect until the app is active again.
    private var deferredConnectObserver: NSObjectProtocol?
    private static let deferredConnectFallback: TimeInterval = 5

    public static func register(with registrar: FlutterPluginRegistrar) {
        guard RemoteManager.playerStateChannel == nil else {
            return
        }
        let spotifySDKChannel = FlutterMethodChannel(name: SpotifySdkConstants.channelSpotifySdk, binaryMessenger: registrar.messenger())
        let connectionStatusChannel = FlutterEventChannel(name: SpotifySdkConstants.channelConnectionStatus, binaryMessenger: registrar.messenger())
        RemoteManager.connectionStatusChannel = connectionStatusChannel
        RemoteManager.playerStateChannel = FlutterEventChannel(name: SpotifySdkConstants.channelPlayerState, binaryMessenger: registrar.messenger())
        RemoteManager.playerContextChannel = FlutterEventChannel(name: SpotifySdkConstants.channelPlayerContext, binaryMessenger: registrar.messenger())
        RemoteManager.capabilitiesChannel = FlutterEventChannel(name: SpotifySdkConstants.channelCapabilities, binaryMessenger: registrar.messenger())
        RemoteManager.userStatusChannel = FlutterEventChannel(name: SpotifySdkConstants.channelUserStatus, binaryMessenger: registrar.messenger())

        registrar.addApplicationDelegate(instance)

        if #available(iOS 13.0, *) {
            let selector = NSSelectorFromString("addSceneDelegate:")
            if (registrar as AnyObject).responds(to: selector) {
                (registrar as AnyObject).perform(selector, with: instance)
            }
        }
        registrar.addMethodCallDelegate(instance, channel: spotifySDKChannel)

        instance.remoteManager.connectionStatusHandler = ConnectionStatusHandler()
        connectionStatusChannel.setStreamHandler(instance.remoteManager.connectionStatusHandler)

        instance.remoteManager.capabilitiesHandler = CapabilitiesHandler()
        RemoteManager.capabilitiesChannel?.setStreamHandler(instance.remoteManager.capabilitiesHandler)

        instance.remoteManager.userStatusHandler = UserStatusHandler()
        RemoteManager.userStatusChannel?.setStreamHandler(instance.remoteManager.userStatusHandler)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Auth & Session
        case SpotifySdkConstants.methodConnectToSpotify:
            authHandler.connectToSpotify(call: call, result: result)
        case SpotifySdkConstants.methodGetAccessToken:
            authHandler.getAccessTokenOrSwapToken(call: call, result: result)
        // Split from getAccessToken deliberately. That one wakes the App Remote
        // and answers its access token; this one is the documented
        // authorization-code request the Android plugin already performs, and
        // the two are different kinds of credential.
        case SpotifySdkConstants.methodGetSwapToken:
            if #available(iOS 13.0, *) {
                authorizationCodeHandler.requestAuthorizationCode(call: call, result: result)
            } else {
                result(SpotifyErrorMapper.makeError(
                    code: "errorAuthorizing",
                    message: "An authorization code needs iOS 13 or newer"
                ))
            }
        case SpotifySdkConstants.methodIsSpotifyInstalled:
            authHandler.isSpotifyInstalled(result: result)
        case SpotifySdkConstants.methodDisconnectFromSpotify:
            authHandler.disconnect(result: result)
        case SpotifySdkConstants.methodGetStoredAccessToken:
            authHandler.getStoredAccessToken(result: result)

        // Playback & Controls
        case SpotifySdkConstants.methodGetPlayerState:
            playerHandler.getPlayerState(result: result)
        case SpotifySdkConstants.methodPlay:
            playerHandler.play(call: call, result: result)
        case SpotifySdkConstants.methodPause:
            playerHandler.pause(result: result)
        case SpotifySdkConstants.methodResume:
            playerHandler.resume(result: result)
        case SpotifySdkConstants.methodQueueTrack:
            playerHandler.queueTrack(call: call, result: result)
        case SpotifySdkConstants.methodSkipNext:
            playerHandler.skipNext(result: result)
        case SpotifySdkConstants.methodSkipPrevious:
            playerHandler.skipPrevious(result: result)
        case SpotifySdkConstants.methodSkipToIndex:
            playerHandler.skipToIndex(call: call, result: result)
        case SpotifySdkConstants.methodSeekTo:
            playerHandler.seekTo(call: call, result: result)
        case SpotifySdkConstants.methodSeekToRelativePosition:
            playerHandler.seekToRelativePosition(call: call, result: result)
        case SpotifySdkConstants.methodGetCrossfadeState:
            playerHandler.getCrossfadeState(result: result)
        case SpotifySdkConstants.methodSetShuffle:
            playerHandler.setShuffle(call: call, result: result)
        case SpotifySdkConstants.methodToggleShuffle:
            playerHandler.toggleShuffle(result: result)
        case SpotifySdkConstants.methodSetRepeatMode:
            playerHandler.setRepeatMode(call: call, result: result)
        case SpotifySdkConstants.methodToggleRepeat:
            playerHandler.toggleRepeat(result: result)
        case SpotifySdkConstants.methodSwitchToLocalDevice:
            playerHandler.switchToLocalDevice(result: result)

        // User Library & Capabilities
        case SpotifySdkConstants.methodAddToLibrary:
            libraryHandler.addToLibrary(call: call, result: result)
        case SpotifySdkConstants.methodRemoveFromLibrary:
            libraryHandler.removeFromLibrary(call: call, result: result)
        case SpotifySdkConstants.methodGetCapabilities:
            libraryHandler.getCapabilities(result: result)
        case SpotifySdkConstants.methodGetLibraryState, SpotifySdkConstants.getLibraryState:
            libraryHandler.getLibraryState(call: call, result: result)

        // Cover Art Images
        case SpotifySdkConstants.methodGetImage:
            imageHandler.getImage(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        setAccessTokenFromURL(url: url)
        return true
    }

    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        setAccessTokenFromURL(url: url)
        return false
    }

    private func setAccessTokenFromURL(url: URL) {
        // An authorization-code redirect carries a code and no access token, so
        // letting the App Remote parse it would report an authentication error
        // for an authorization that succeeded. Offered to the code handler
        // first, which takes it only while one of its own is outstanding.
        if #available(iOS 13.0, *), authorizationCodeHandler.handle(url: url) {
            return
        }

        guard let appRemote = remoteManager.appRemote else {
            remoteManager.connectionStatusHandler?.connectionResult?(FlutterError(code: "errorConnection", message: "AppRemote is null", details: nil))
            remoteManager.connectionStatusHandler?.tokenResult?(FlutterError(code: "errorConnection", message: "AppRemote is null", details: nil))
            remoteManager.connectionStatusHandler?.connectionResult = nil
            remoteManager.connectionStatusHandler?.tokenResult = nil
            return
        }

        guard let token = appRemote.authorizationParameters(from: url)?[SPTAppRemoteAccessTokenKey] else {
            remoteManager.connectionStatusHandler?.connectionResult?(FlutterError(code: "authenticationTokenError", message: appRemote.authorizationParameters(from: url)?[SPTAppRemoteErrorDescriptionKey], details: nil))
            remoteManager.connectionStatusHandler?.tokenResult?(FlutterError(code: "authenticationTokenError", message: appRemote.authorizationParameters(from: url)?[SPTAppRemoteErrorDescriptionKey], details: nil))
            remoteManager.connectionStatusHandler?.connectionResult = nil
            remoteManager.connectionStatusHandler?.tokenResult = nil
            return
        }

        appRemote.connectionParameters.accessToken = token
        connectOnceActive(appRemote)
    }

    /// The redirect from Spotify lands while this app is still inactive. A
    /// connect() issued there has to wake Spotify from the background, which
    /// iOS refuses (SPTAppRemoteBackgroundWakeupFailedError, -1000), so the
    /// authorize that just succeeded reads as a failed connection. Spotify's
    /// own sample connects from didBecomeActive instead; the notification is
    /// used rather than a delegate callback so scene-based hosts behave the
    /// same. The fallback bounds the wait so the Dart call cannot hang if the
    /// app never becomes active.
    private func connectOnceActive(_ appRemote: SPTAppRemote) {
        if UIApplication.shared.applicationState == .active {
            appRemote.connect()
            return
        }
        cancelDeferredConnect()
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.runDeferredConnect(appRemote)
        }
        deferredConnectObserver = observer
        DispatchQueue.main.asyncAfter(deadline: .now() + SpotifySdkPlugin.deferredConnectFallback) { [weak self] in
            guard let self, self.deferredConnectObserver === observer else { return }
            self.runDeferredConnect(appRemote)
        }
    }

    private func runDeferredConnect(_ appRemote: SPTAppRemote) {
        guard deferredConnectObserver != nil else { return }
        cancelDeferredConnect()
        appRemote.connect()
    }

    private func cancelDeferredConnect() {
        if let observer = deferredConnectObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        deferredConnectObserver = nil
    }
}

@available(iOS 13.0, *)
extension SpotifySdkPlugin: UIWindowSceneDelegate {
    public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        setAccessTokenFromURL(url: url)
    }

    public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }
        setAccessTokenFromURL(url: url)
    }
}
