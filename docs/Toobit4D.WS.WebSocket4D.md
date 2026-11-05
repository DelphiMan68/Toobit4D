# Toobit4D.WS.WebSocket4D

Transport adapter on top of [WebSocket4D](https://github.com/DelphiMan68/WebSocket4D) (`TWebSocket4DClient`). The WebSocket4D client is WinHTTP based and requires Windows 8 or later. This unit is the only place in Toobit4D that references WebSocket4D.

## Mapping

| `TToobitWsTransport` | `TWebSocket4DClient` |
|---|---|
| `Connect(AUrl)` | `Connect(URL)`, then `StartReceiving` |
| `Send(AText)` | `SendText(UTF8String)` |
| `Disconnect` | `Close` (then the client object is freed) |
| `OnOpen` | `OnConnect` |
| `OnClose` | `OnDisconnect` |
| `OnMessage` | `OnTextMessage(Sender; const Text: UTF8String)` |
| `OnError` | `OnError(Sender; const ErrorMessage: string; ErrorCode: Cardinal)`, reported as `"message (code N)"` |

## Behaviour worth knowing

- **`Connect` does not raise on failure.** `TWebSocket4DClient.Connect` is synchronous, reports problems through `OnError` and returns with `Connected = False`. The adapter therefore raises `EToobitWsError` when the client is not connected after `Connect`, and raises `OnOpen` only from the client's `OnConnect` event (which fires only after a successful connection).
- **Fresh client per connection.** Every `Connect` frees the previous `TWebSocket4DClient` and creates a new one, so reconnects start from a clean state.
- **Library auto-reconnect is disabled** (`AutoReconnect := False`). `Toobit4D.Stream` performs reconnection, re-subscription and listenKey renewal itself.
- **Disconnect detection.** When the peer closes the connection, the client's receive thread ends and `OnDisconnect` is raised once; the adapter forwards it as `OnClose`. `Disconnect` does not raise a second `OnClose`.
- **Threads.** `OnConnect` is raised on the thread that called `Connect` (the stream's worker thread). `OnTextMessage`, `OnError` (after connect) and `OnDisconnect` are raised on WebSocket4D's receive thread. `Close` waits for that receive thread, so never call `Disconnect` from inside one of your own `OnMessage` handlers.
- **Text only.** Binary frames are ignored (`OnBinaryMessage` is not assigned); Toobit sends text frames when `binary:false` is requested, which the library always does.
- **Encoding.** Text is exchanged as `UTF8String` and converted to `string` for the rest of the library.

## TLS

`wss://stream.toobit.com` uses a publicly trusted certificate. The WinHTTP client validates it against the Windows certificate store, so no configuration is needed.

## Updating WebSocket4D

The adapter was written against the `WebSocket4D.pas` supplied by the project owner (events `OnConnect`, `OnDisconnect`, `OnTextMessage`, `OnBinaryMessage`, `OnError`; methods `Connect`, `SendText`, `Close`, `StartReceiving`). If a future version changes these signatures, only this unit needs to change.
