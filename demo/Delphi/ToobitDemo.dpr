program ToobitDemo;
{$APPTYPE CONSOLE}

{ Minimal Toobit4D demo (Delphi).
  Search path: ..\..\src, <RESTRequest4Delphi>\src, <WebSocket4D>\Source }

uses
  SysUtils,
  Toobit4D.Client in '..\..\src\Toobit4D.Client.pas',
  Toobit4D.Futures in '..\..\src\Toobit4D.Futures.pas',
  Toobit4D.Json in '..\..\src\Toobit4D.Json.pas',
  Toobit4D in '..\..\src\Toobit4D.pas',
  Toobit4D.Spot in '..\..\src\Toobit4D.Spot.pas',
  Toobit4D.Stream in '..\..\src\Toobit4D.Stream.pas',
  Toobit4D.Types in '..\..\src\Toobit4D.Types.pas',
  Toobit4D.Utils in '..\..\src\Toobit4D.Utils.pas',
  Toobit4D.WS.Transport in '..\..\src\Toobit4D.WS.Transport.pas',
  Toobit4D.WS.WebSocket4D in '..\..\src\Toobit4D.WS.WebSocket4D.pas';

type
  TStreamPrinter = class
    procedure OnMsg(Sender: TObject; const ATopic, ASymbol, AJson: string);
    procedure OnErr(Sender: TObject; const AMessage: string);
  end;

procedure TStreamPrinter.OnMsg(Sender: TObject; const ATopic, ASymbol, AJson: string);
begin
  Writeln('[', ATopic, '] ', ASymbol, ' ', Copy(AJson, 1));
end;

procedure TStreamPrinter.OnErr(Sender: TObject; const AMessage: string);
begin
  Writeln('WS error: ', AMessage);
end;

var
  Toobit: TToobit;
  Stream: TToobitMarketStream;
  Printer: TStreamPrinter;
begin
  if not ToobitSelfTest then
  begin
    Writeln('HMAC self test FAILED');
    Halt(1);
  end;

  // Fill in keys only for private calls; public calls work without them.
  Toobit := TToobit.Create('', '');
  Printer := TStreamPrinter.Create;
  try
    try
      Writeln('Offset to server clock: ', Toobit.Client.SyncTime, ' ms');
      Writeln(Toobit.Spot.TickerPrice('BTCUSDT'));
      Writeln(Toobit.Futures.FundingRate('BTC-SWAP-USDT'));

      Stream := Toobit.NewMarketStream;
      try
        Stream.OnMessage := Printer.OnMsg;
        Stream.OnError := Printer.OnErr;
        Stream.Start;
        Stream.SubscribeTrades(['BTCUSDT']);
        Stream.SubscribeKline(['BTCUSDT'], '1m');
        Writeln('Streaming... press Enter to stop');
        Readln;
      finally
        Stream.Free;   // Stop is called automatically
      end;
    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  finally
    Printer.Free;
    Toobit.Free;
  end;
end.
