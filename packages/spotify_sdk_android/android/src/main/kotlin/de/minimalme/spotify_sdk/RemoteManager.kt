package de.minimalme.spotify_sdk

import android.app.Activity
import android.content.Context
import com.spotify.android.appremote.api.SpotifyAppRemote
import de.minimalme.spotify_sdk.subscriptions.ConnectionStatusChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.event.SetEvent
import kotlinx.event.event

class RemoteManager {

    var applicationContext: Context? = null
    var applicationActivity: Activity? = null
    var spotifyAppRemote: SpotifyAppRemote? = null

    var playerContextChannel: EventChannel? = null
    var playerStateChannel: EventChannel? = null
    var capabilitiesChannel: EventChannel? = null
    var userStatusChannel: EventChannel? = null
    var connectionStatusChannel: EventChannel? = null

    var connStatusEventChannel: SetEvent<ConnectionStatusChannel.ConnectionEvent> = event()
    var pendingOperation: PendingOperation? = null

    inline fun withAppRemote(result: Result, block: (SpotifyAppRemote) -> Unit) {
        val remote = spotifyAppRemote
        if (remote != null && remote.isConnected) {
            block(remote)
        } else {
            result.error(SpotifySdkConstants.ERROR_SPOTIFY_APP_REMOTE_NULL, "spotifyAppRemote is null or disconnected", "")
        }
    }

    /**
     * Takes the slot for [result], failing whichever request held it. Only an
     * activity result clears the slot, and a login activity left any other way
     * never reports one, so refusing here stranded every later request.
     */
    fun String.takePendingOperation(result: Result) {
        pendingOperation?.result?.error(
            SpotifySdkConstants.ERROR_AUTHORIZING,
            "Superseded by another authorization request",
            ""
        )
        pendingOperation = PendingOperation(this, result)
    }
}
