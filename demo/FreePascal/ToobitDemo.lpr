program ToobitDemo;
{$mode delphi}{$H+}
{$APPTYPE CONSOLE}

{ Minimal Toobit4D demo (FreePascal).
  fpc -Mdelphi -Fu..\..\src -Fu<RESTRequest4Delphi>\src -Fu<WebSocket4D>\Source ToobitDemo.lpr
  HTTPS needs the OpenSSL DLLs next to the .exe. }

uses
  {$IF FPC_FULLVERSION >= 30200}opensslsockets,{$ENDIF}  // HTTPS for fphttpclient (FPC 3.2+)
  SysUtils, Toobit4D, Toobit4D.Types, Toobit4D.Utils, Toobit4D.Json,
  Toobit4D.Client, Toobit4D.Spot, Toobit4D.Futures, Toobit4D.Stream,
  Toobit4D.WS.Transport, Toobit4D.WS.WebSocket4D;

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
