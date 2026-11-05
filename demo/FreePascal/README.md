# FreePascal demos

| Program | Purpose |
|---|---|
| `ToobitDemo.lpr` | Minimal example: self-test, one REST call, a short market stream. |
| `ToobitTester.lpr` | Interactive console tester (menu, keys, safety rules: see [`../README.md`](../README.md)). |

Both programs start with `{$mode delphi}{$H+}`, matching the library sources.

## Build with the command line

From this folder (Windows):

```
fpc -Mdelphi -Fu..\..\src -Fu<RESTRequest4Delphi>\src -Fu<WebSocket4D>\Source ToobitTester.lpr
```

## Build with Lazarus

1. **Project > New Project from File...** and choose the `.lpr` (or create a *Program* project and replace its source).
2. **Project > Project Options > Compiler Options > Paths > Other unit files (-Fu)**: add
   `..\..\src`, the RESTRequest4Delphi `src` folder and the WebSocket4D `Source` folder.
3. **Compiler Options > Parsing**: syntax mode *Delphi*.
4. Build and run.

## HTTPS

RESTRequest4Delphi uses FPC's `fphttpclient` here. For `https://` to work:

- The OpenSSL libraries that match your FPC version (`libssl*.dll` and `libcrypto*.dll`) must be next to the executable or on the `PATH`.
- With FPC 3.2 and later the unit `opensslsockets` must be linked in. Both programs add it automatically (`{$IF FPC_FULLVERSION >= 30200}`); with older FPC versions you need a working OpenSSL setup of your own.

If REST calls fail with an SSL or "unable to load library" error, this is the first thing to check.

## Notes

- WebSocket4D is Windows only (its client is WinHTTP based), so the stream tests need Windows even though the REST part is portable.
- Environment variables `TOOBIT_API_KEY` and `TOOBIT_SECRET_KEY` supply the keys for the private tests.
- These programs have not been compiled yet. Please report compiler errors with their line numbers.
