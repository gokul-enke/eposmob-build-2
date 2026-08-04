# Flutter Testing, Recording, and Sharing Workflow

Use this workflow whenever the user asks to test a running Flutter app, demonstrate a UI flow, make a sale, or provide a recording of the test.

## 1. Testing with Marionette MCP

Marionette controls a Flutter app running in debug mode through its Dart VM Service.

### Connect

Get the VM Service URI from the Flutter console, for example:

```text
ws://127.0.0.1:<port>/<isolate-id>/ws
```

Connect before interacting:

```text
mcp__marionette__connect({ uri: "<VM_SERVICE_URI>" })
```

Then inspect the current UI:

```text
mcp__marionette__get_interactive_elements({})
mcp__marionette__take_screenshots({})
```

### Interact safely

- Prefer stable widget keys over coordinates.
- Use visible text only when a key is unavailable.
- Use `enter_text` only after identifying the correct field.
- After navigation, loading, or a modal, inspect the UI again before the next action.
- Do not print or report passwords, tokens, full credentials, or unnecessary customer data.
- Do not create a real order, payment, or other irreversible side effect unless the user explicitly requests it.
- If the user explicitly requests a sale, use the safest available test customer, lowest-value test item, and test payment method unless the user specifies otherwise. Report the resulting invoice/order ID and status.

Typical tools:

```text
mcp__marionette__tap({ key: "<KEY>" })
mcp__marionette__tap({ text: "<VISIBLE_TEXT>" })
mcp__marionette__tap({ coordinates: { x: <X>, y: <Y> } })
mcp__marionette__enter_text({ key: "<FIELD_KEY>", input: "<TEXT>" })
mcp__marionette__scroll_to({ ... })
mcp__marionette__take_screenshots({})
```

Use coordinates only as a last resort, and verify the result with another UI inspection or screenshot.

### Check errors

After the flow, check Flutter runtime errors:

```text
mcp__dart_mcp_server__get_runtime_errors({
  appUri: "<VM_SERVICE_URI>",
  clearRuntimeErrors: false
})
```

Use Marionette logs when available. Report runtime errors separately from business-flow failures.

## 2. Recording with Screencast MCP

Start recording before the first user-flow action so the recording includes the complete process.

For a Windows app, capture only the visible app window:

```text
mcp__screencast__start_recording({
  target: "window:<EXACT_WINDOW_TITLE>",
  fps: 15,
  quality: "draft",
  audio: { source: "none" }
})
```

Important:

- The window must be visible, unminimized, and on top when recording starts.
- `window:<title>` is resolved at start and does not follow the window if it moves or resizes.
- Use `target: "full"` only when the user explicitly asks for the whole desktop.
- Video-only capture is the default. System audio requires a supported Windows loopback device.
- Save the returned `sessionId` and `outputPath`.

Stop only after the final verification screen has been shown:

```text
mcp__screencast__stop_recording({ sessionId: "<SESSION_ID>" })
```

The stop result must show `finalizedGracefully: true` and `fileExists: true` before reporting the recording as complete.

### Verify the video

Probe the finalized file:

```text
mcp__screencast__get_media_info({ input: "<VIDEO_PATH>" })
```

Sample beginning, middle, and end frames:

```text
mcp__screencast__sample_frames({
  input: "<VIDEO_PATH>",
  timestamps: [1, <MIDDLE_SECONDS>, <LAST_SAFE_SECONDS>]
})
```

View at least one sampled frame and verify that it contains the expected app UI. Report duration, resolution, frame rate, audio presence, and the full local path.

If the recording contains credentials, personal data, or information that should not be public, redact it with Screencast MCP before sharing or use restricted sharing.

## 3. Share a temporary link with Cloudflare Quick Tunnel

Cloudflare Quick Tunnel serves the local video through a temporary random `trycloudflare.com` URL. It is not a permanent upload.

### Prerequisites

Check that `cloudflared` is installed:

```powershell
Get-Command cloudflared
```

Use a local HTTP server bound to `127.0.0.1` that serves only the selected video (or a dedicated temporary folder containing only that video). Never expose the entire recordings directory, repository, or home directory.

Start the free temporary tunnel:

```powershell
cloudflared tunnel --url http://127.0.0.1:<PORT> --no-autoupdate
```

Capture the generated URL from the output:

```text
https://<random-words>.trycloudflare.com
```

Verify the link before sending it. Check that the player page returns `200 OK` and that the MP4 endpoint returns `Content-Type: video/mp4` and the expected content length. Provide both the player URL and direct MP4 URL when available.

### Sharing rules

- Anyone who has the Quick Tunnel URL can access the served file.
- The link works only while the local server, `cloudflared`, and the host PC remain running.
- The URL is random and temporary; it can change after restarting the tunnel.
- Stop the local server and tunnel when the user confirms they no longer need the link.
- For permanent hosting or access control, use Google Drive, a named Cloudflare Tunnel, or another authenticated storage service.

## 4. Standard completion report

Return a concise report containing:

1. The test flow completed and any intentional choices (for example, skipped day close or selected test payment).
2. The resulting invoice/order ID and business status, when applicable.
3. Runtime-error result.
4. Recording duration, resolution, audio status, and full local path.
5. A verified temporary player link and direct MP4 link, if requested.
6. A clear warning if the link is temporary or publicly accessible.

Never include passwords, access tokens, or unnecessary personal information in the report.

## 5. Machine-specific setup used by this project

The Screencast MCP server is configured globally with:

```toml
[mcp_servers.screencast]
command = 'C:\\nvm4w\\nodejs\\screencast-mcp.cmd'

[mcp_servers.screencast.env]
FFMPEG_PATH = 'C:\\Users\\jim\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffmpeg.exe'
FFPROBE_PATH = 'C:\\Users\\jim\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffprobe.exe'
```

If the Screencast MCP tools are not loaded directly, use the configured MCP server or its documented Node MCP client fallback. Do not bypass recording finalization with a force-kill unless graceful stopping has failed and the user has been informed.

Official references:

- [Marionette MCP](https://github.com/leanflutter/marionette)
- [Cloudflare Quick Tunnels](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/)
