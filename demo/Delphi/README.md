# Delphi demos

| Program | Purpose |
|---|---|
| `ToobitDemo.dpr` | Minimal example: self-test, one REST call, a short market stream. |
| `ToobitTester.dpr` | Interactive console tester (menu, keys, safety rules: see [`../README.md`](../README.md)). |

## Build

1. Open the `.dpr` in the Delphi IDE.
2. Add these folders to **Project > Options > Building > Delphi Compiler > Search path**:

```
..\..\src
<RESTRequest4Delphi>\src
<WebSocket4D>\Source
```

3. Build and run (console application).

Command line alternative:

```
dcc32 -U..\..\src;<RESTRequest4Delphi>\src;<WebSocket4D>\Source ToobitTester.dpr
```

(`dcc64` works as well; WebSocket4D itself is Windows only.)

## Notes

- Delphi must be able to find `System.JSON` and `System.DateUtils` (XE7 or later recommended).
- Environment variables `TOOBIT_API_KEY` and `TOOBIT_SECRET_KEY` supply the keys for the private tests.
