unit Toobit4D;
{$I Toobit4D.inc}

{ Toobit4D - Toobit exchange API for Delphi and FreePascal.
  REST via RESTRequest4Delphi, WebSocket via WebSocket4D.

  uses Toobit4D;

  var Toobit: TToobit;
  begin
    Toobit := TToobit.Create('API_KEY', 'SECRET_KEY');
    try
      Toobit.Client.SyncTime;
      Writeln(Toobit.Spot.TickerPrice('BTCUSDT'));
      Writeln(Toobit.Futures.Balance);
    finally
      Toobit.Free;
    end;
  end; }

interface

uses
  SysUtils,
  Toobit4D.Types,
  Toobit4D.Utils,
  Toobit4D.Json,
  Toobit4D.Client,
  Toobit4D.Spot,
  Toobit4D.Futures,
  Toobit4D.WS.Transport,
  Toobit4D.Stream;

type
  TToobit = class
  private
    FClient: TToobitClient;
    FSpot: TToobitSpotApi;
    FFutures: TToobitFuturesApi;
  public
    constructor Create(const AApiKey: string = ''; const ASecretKey: string = '');
    destructor Destroy; override;

    { Creates a market-data stream (caller owns it). }
    function NewMarketStream: TToobitMarketStream;
    { Creates a private user-data stream (caller owns it). }
    function NewUserStream(AKind: TToobitUserStreamKind): TToobitUserStream;

    property Client: TToobitClient read FClient;
    property Spot: TToobitSpotApi read FSpot;
    property Futures: TToobitFuturesApi read FFutures;
  end;

implementation

constructor TToobit.Create(const AApiKey, ASecretKey: string);
begin
  inherited Create;
  FClient := TToobitClient.Create(AApiKey, ASecretKey);
  FSpot := TToobitSpotApi.Create(FClient);
  FFutures := TToobitFuturesApi.Create(FClient);
end;

destructor TToobit.Destroy;
begin
  FFutures.Free;
  FSpot.Free;
  FClient.Free;
  inherited;
end;

function TToobit.NewMarketStream: TToobitMarketStream;
begin
  Result := TToobitMarketStream.Create;
end;

function TToobit.NewUserStream(AKind: TToobitUserStreamKind): TToobitUserStream;
begin
  Result := TToobitUserStream.Create(FClient, AKind);
  if AKind = usFutures then
    Result.Category := FFutures.Category;
end;

end.
