unit Toobit4D.Stream;
{$I Toobit4D.inc}

(* WebSocket streams: public market data and the private user-data stream.

  * automatic reconnect with back-off and automatic re-subscription
  * client heartbeat  {"ping": <ms>}  (the server drops idle clients after ~5 min)
  * user stream: creates the listenKey, keeps it alive (every 30 min), closes it on Stop

  THREADING: events are raised on a library worker thread (or on the thread the
  transport uses for receiving). Synchronise before touching VCL/LCL controls. *)

interface

uses
  Classes, SysUtils, SyncObjs,
  Toobit4D.Types, Toobit4D.Utils, Toobit4D.Json, Toobit4D.Client, Toobit4D.WS.Transport;

type
  { ATopic: market stream topic ('trade', 'kline', 'realtimes', 'depth', 'diffDepth',
    'markPrice', 'bookTicker', 'wholeRealTime', 'wholeBookTicker', 'index') or, for the user
    stream, the event type ('executionReport', 'contractExecutionReport', 'outboundAccountInfo',
    'outboundContractAccountInfo', 'outboundContractPositionInfo', 'ticketInfo',
    'planExecutionReport', 'listenKeyWillExpire').
    ASymbol may be empty. AJson is the untouched frame text. }
  TToobitStreamMessageEvent = procedure(Sender: TObject; const ATopic, ASymbol, AJson: string) of object;
  TToobitStreamNotifyEvent  = procedure(Sender: TObject) of object;
  TToobitStreamErrorEvent   = procedure(Sender: TObject; const AMessage: string) of object;

  TToobitStreamBase = class
  private
    FTransport: TToobitWsTransport;
    FOwnsTransport: Boolean;
    FWorker: TThread;
    FLock: TCriticalSection;
    FOpened: Boolean;
    FStopping: Boolean;
    FPingIntervalMs: Integer;
    FReconnectDelayMs: Integer;
    FSubKeys: TStringList;
    FSubMessages: TStringList;
    FOnMessage: TToobitStreamMessageEvent;
    FOnConnected: TToobitStreamNotifyEvent;
    FOnDisconnected: TToobitStreamNotifyEvent;
    FOnError: TToobitStreamErrorEvent;
    function GetActive: Boolean;
    function GetOpened: Boolean;
    procedure SetOpened(AValue: Boolean);
    procedure TransportOpen(Sender: TObject);
    procedure TransportClose(Sender: TObject);
    procedure TransportMessage(Sender: TObject; const AText: string);
    procedure TransportError(Sender: TObject; const AMessage: string);
    procedure RunConnection;
    procedure ResubscribeAll;
  protected
    function ResolveUrl: string; virtual; abstract;
    procedure KeepAlive; virtual;
    function KeepAliveIntervalMs: Integer; virtual;
    procedure Cleanup; virtual;
    procedure SendRaw(const AText: string);
    procedure AddSubscription(const AKey, AMessage: string);
    procedure RemoveSubscription(const AKey: string);
    procedure RaiseError(const AMessage: string);
    function TopicOf(const AJson: string): string; virtual;
  public
    { ATransport = nil -> the default WebSocket4D transport is created. }
    constructor Create(ATransport: TToobitWsTransport = nil);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    property Active: Boolean read GetActive;
    property Connected: Boolean read GetOpened;
    property PingIntervalMs: Integer read FPingIntervalMs write FPingIntervalMs;
    property ReconnectDelayMs: Integer read FReconnectDelayMs write FReconnectDelayMs;

    property OnMessage: TToobitStreamMessageEvent read FOnMessage write FOnMessage;
    property OnConnected: TToobitStreamNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TToobitStreamNotifyEvent read FOnDisconnected write FOnDisconnected;
    property OnError: TToobitStreamErrorEvent read FOnError write FOnError;
  end;

  { ---------------------------------------------------------------- market -- }
  TToobitMarketStream = class(TToobitStreamBase)
  private
    FUrl: string;
    procedure Sub(const AEvent, ATopic: string; const ASymbols: array of string;
      ALimit: Integer; AWithParams: Boolean);
  protected
    function ResolveUrl: string; override;
  public
    constructor Create(ATransport: TToobitWsTransport = nil);

    { generic: ATopic as in the docs, e.g. 'trade', 'depth', 'kline_1m' }
    procedure Subscribe(const ATopic: string; const ASymbols: array of string; ALimit: Integer = 0);
    procedure Unsubscribe(const ATopic: string; const ASymbols: array of string);

    procedure SubscribeTrades(const ASymbols: array of string);
    { AInterval: 1m 5m 15m 30m 1h 2h 4h 6h 12h 1d 1w 1M. ALimit = history rows (max 2000). }
    procedure SubscribeKline(const ASymbols: array of string; const AInterval: string; ALimit: Integer = 0);
    procedure SubscribeTicker(const ASymbols: array of string);        // topic 'realtimes'
    procedure SubscribeDepth(const ASymbols: array of string);         // partial book depth
    procedure SubscribeDiffDepth(const ASymbols: array of string);
    procedure SubscribeBookTicker(const ASymbols: array of string);    // futures
    procedure SubscribeMarkPrice(const ASymbols: array of string);     // futures
    procedure SubscribeIndex(const ASymbols: array of string);         // futures, e.g. BTCUSDT
    procedure SubscribeAllTickers;                                     // futures 'wholeRealTime'
    procedure SubscribeAllBookTickers;                                 // futures 'wholeBookTicker'

    property Url: string read FUrl write FUrl;
  end;

  { ------------------------------------------------------------------ user -- }
  TToobitUserStreamKind = (usSpot, usFutures);

  TToobitUserStream = class(TToobitStreamBase)
  private
    FClient: TToobitClient;
    FKind: TToobitUserStreamKind;
    FCategory: string;
    FListenKey: string;
  protected
    function ResolveUrl: string; override;
    procedure KeepAlive; override;
    function KeepAliveIntervalMs: Integer; override;
    procedure Cleanup; override;
  public
    constructor Create(AClient: TToobitClient; AKind: TToobitUserStreamKind;
      ATransport: TToobitWsTransport = nil);
    { '' = USDT-M, TB_CATEGORY_USDC = USDC-M (futures only) }
    property Category: string read FCategory write FCategory;
    property ListenKey: string read FListenKey;
  end;

implementation

uses
  Toobit4D.WS.WebSocket4D;

type
  TToobitStreamWorker = class(TThread)
  private
    FOwner: TToobitStreamBase;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TToobitStreamBase);
  end;

{ TToobitStreamWorker }

constructor TToobitStreamWorker.Create(AOwner: TToobitStreamBase);
begin
  FOwner := AOwner;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TToobitStreamWorker.Execute;
var
  LWait: Integer;
begin
  while not Terminated do
  begin
    try
      FOwner.RunConnection;
    except
      on E: Exception do
        FOwner.RaiseError(E.Message);
    end;
    // back-off before the next attempt (interruptible)
    LWait := FOwner.FReconnectDelayMs;
    while (LWait > 0) and not Terminated do
    begin
      Sleep(100);
      Dec(LWait, 100);
    end;
  end;
end;

{ TToobitStreamBase }

constructor TToobitStreamBase.Create(ATransport: TToobitWsTransport);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSubKeys := TStringList.Create;
  FSubMessages := TStringList.Create;
  FPingIntervalMs := 20000;
  FReconnectDelayMs := 3000;
  if ATransport = nil then
  begin
    FTransport := TToobitWsTransportWebSocket4D.Create;
    FOwnsTransport := True;
  end
  else
  begin
    FTransport := ATransport;
    FOwnsTransport := False;
  end;
  FTransport.OnOpen := TransportOpen;
  FTransport.OnClose := TransportClose;
  FTransport.OnMessage := TransportMessage;
  FTransport.OnError := TransportError;
end;

destructor TToobitStreamBase.Destroy;
begin
  Stop;
  if FOwnsTransport then
    FTransport.Free;
  FSubMessages.Free;
  FSubKeys.Free;
  FLock.Free;
  inherited;
end;

function TToobitStreamBase.GetActive: Boolean;
begin
  Result := FWorker <> nil;
end;

function TToobitStreamBase.GetOpened: Boolean;
begin
  FLock.Enter;
  try
    Result := FOpened;
  finally
    FLock.Leave;
  end;
end;

procedure TToobitStreamBase.SetOpened(AValue: Boolean);
begin
  FLock.Enter;
  try
    FOpened := AValue;
  finally
    FLock.Leave;
  end;
end;

procedure TToobitStreamBase.Start;
begin
  if FWorker <> nil then
    Exit;
  FStopping := False;
  FWorker := TToobitStreamWorker.Create(Self);
end;

procedure TToobitStreamBase.Stop;
begin
  if FWorker = nil then
    Exit;
  FStopping := True;
  FWorker.Terminate;
  try
    FTransport.Disconnect;
  except
    // ignore - we are shutting down
  end;
  FWorker.WaitFor;
  FreeAndNil(FWorker);
  SetOpened(False);
  try
    Cleanup;
  except
    // ignore
  end;
end;

procedure TToobitStreamBase.KeepAlive;
begin
  // nothing for market streams
end;

function TToobitStreamBase.KeepAliveIntervalMs: Integer;
begin
  Result := 0;
end;

procedure TToobitStreamBase.Cleanup;
begin
end;

procedure TToobitStreamBase.RaiseError(const AMessage: string);
begin
  if Assigned(FOnError) then
    FOnError(Self, AMessage);
end;

procedure TToobitStreamBase.SendRaw(const AText: string);
begin
  FTransport.Send(AText);
end;

procedure TToobitStreamBase.AddSubscription(const AKey, AMessage: string);
var
  LIndex: Integer;
begin
  FLock.Enter;
  try
    LIndex := FSubKeys.IndexOf(AKey);
    if LIndex >= 0 then
      FSubMessages[LIndex] := AMessage
    else
    begin
      FSubKeys.Add(AKey);
      FSubMessages.Add(AMessage);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TToobitStreamBase.RemoveSubscription(const AKey: string);
var
  LIndex: Integer;
begin
  FLock.Enter;
  try
    LIndex := FSubKeys.IndexOf(AKey);
    if LIndex >= 0 then
    begin
      FSubKeys.Delete(LIndex);
      FSubMessages.Delete(LIndex);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TToobitStreamBase.ResubscribeAll;
var
  LList: TStringList;
  I: Integer;
begin
  LList := TStringList.Create;
  try
    FLock.Enter;
    try
      LList.Assign(FSubMessages);
    finally
      FLock.Leave;
    end;
    for I := 0 to LList.Count - 1 do
      SendRaw(LList[I]);
  finally
    LList.Free;
  end;
end;

function TToobitStreamBase.TopicOf(const AJson: string): string;
begin
  Result := JsonQuickString(AJson, 'topic');
  if Result = '' then
    Result := JsonQuickString(AJson, 'e');            // user stream events
  if Result = '' then
    Result := JsonQuickString(AJson, 'eventType');    // planExecutionReport, listenKeyWillExpire
end;

procedure TToobitStreamBase.TransportOpen(Sender: TObject);
begin
  SetOpened(True);
end;

procedure TToobitStreamBase.TransportClose(Sender: TObject);
var
  LWasOpen: Boolean;
begin
  FLock.Enter;
  try
    LWasOpen := FOpened;
    FOpened := False;
  finally
    FLock.Leave;
  end;
  if LWasOpen and Assigned(FOnDisconnected) then
    FOnDisconnected(Self);
end;

procedure TToobitStreamBase.TransportError(Sender: TObject; const AMessage: string);
begin
  RaiseError(AMessage);
end;

procedure TToobitStreamBase.TransportMessage(Sender: TObject; const AText: string);
var
  LPong: string;
begin
  // heartbeat frames are short - only those are parsed
  if Length(AText) < 80 then
  begin
    if JsonField(AText, 'pong') <> '' then
      Exit;
    LPong := JsonField(AText, 'ping');
    if LPong <> '' then
    begin
      try
        SendRaw('{"pong":' + LPong + '}');
      except
        // ignore, the reconnect logic will deal with a dead socket
      end;
      Exit;
    end;
  end;
  if Assigned(FOnMessage) then
    FOnMessage(Self, TopicOf(AText), JsonQuickString(AText, 'symbol'), AText);
end;

procedure TToobitStreamBase.RunConnection;
var
  LUrl: string;
  LWaited: Integer;
  LNow, LLastPing, LLastKeep, LKeepEvery: Int64;
begin
  LUrl := ResolveUrl;
  SetOpened(False);
  FTransport.Connect(LUrl);

  // wait (max 15 s) for the socket to open
  LWaited := 0;
  while (not FStopping) and (not GetOpened) and (LWaited < 15000) do
  begin
    Sleep(50);
    Inc(LWaited, 50);
  end;
  if FStopping then
    Exit;
  if not GetOpened then
  begin
    RaiseError('WebSocket connection timed out: ' + LUrl);
    try
      FTransport.Disconnect;
    except
    end;
    Exit;
  end;

  if Assigned(FOnConnected) then
    FOnConnected(Self);
  ResubscribeAll;

  LLastPing := ToobitTickMs;
  LLastKeep := LLastPing;
  LKeepEvery := KeepAliveIntervalMs;

  while (not FStopping) and GetOpened do
  begin
    Sleep(100);
    LNow := ToobitTickMs;
    if (FPingIntervalMs > 0) and (LNow - LLastPing >= FPingIntervalMs) then
    begin
      SendRaw('{"ping":' + IntToStr(ToobitUtcNowMs) + '}');
      LLastPing := LNow;
    end;
    if (LKeepEvery > 0) and (LNow - LLastKeep >= LKeepEvery) then
    begin
      try
        KeepAlive;
      except
        on E: Exception do
          RaiseError('listenKey keep-alive failed: ' + E.Message);
      end;
      LLastKeep := LNow;
    end;
  end;

  try
    FTransport.Disconnect;
  except
  end;
  if (not FStopping) and GetOpened then
    TransportClose(Self);
end;

{ TToobitMarketStream }

constructor TToobitMarketStream.Create(ATransport: TToobitWsTransport);
begin
  inherited Create(ATransport);
  FUrl := TOOBIT_WS_MARKET_URL;
end;

function TToobitMarketStream.ResolveUrl: string;
begin
  Result := FUrl;
end;

procedure TToobitMarketStream.Sub(const AEvent, ATopic: string; const ASymbols: array of string;
  ALimit: Integer; AWithParams: Boolean);
var
  I: Integer;
  LSymbols, LMsg, LKey: string;
begin
  LSymbols := '';
  for I := 0 to High(ASymbols) do
  begin
    if I > 0 then
      LSymbols := LSymbols + ',';
    LSymbols := LSymbols + ASymbols[I];
  end;

  LMsg := '{';
  if LSymbols <> '' then
    LMsg := LMsg + '"symbol":' + JsonQuote(LSymbols) + ',';
  LMsg := LMsg + '"topic":' + JsonQuote(ATopic) + ',"event":' + JsonQuote(AEvent);
  if AWithParams then
  begin
    LMsg := LMsg + ',"params":{';
    if ALimit > 0 then
      LMsg := LMsg + '"limit":' + IntToStr(ALimit) + ',';
    LMsg := LMsg + '"binary":false}';       // binary=true would deliver compressed frames
  end;
  LMsg := LMsg + '}';

  LKey := ATopic + '|' + LSymbols;
  if AEvent = 'sub' then
    AddSubscription(LKey, LMsg)
  else
    RemoveSubscription(LKey);

  if Connected then
    SendRaw(LMsg);
end;

procedure TToobitMarketStream.Subscribe(const ATopic: string; const ASymbols: array of string;
  ALimit: Integer);
begin
  Sub('sub', ATopic, ASymbols, ALimit, True);
end;

procedure TToobitMarketStream.Unsubscribe(const ATopic: string; const ASymbols: array of string);
begin
  Sub('cancel', ATopic, ASymbols, 0, True);
end;

procedure TToobitMarketStream.SubscribeTrades(const ASymbols: array of string);
begin
  Sub('sub', 'trade', ASymbols, 0, True);
end;

procedure TToobitMarketStream.SubscribeKline(const ASymbols: array of string;
  const AInterval: string; ALimit: Integer);
begin
  Sub('sub', 'kline_' + AInterval, ASymbols, ALimit, True);
end;

procedure TToobitMarketStream.SubscribeTicker(const ASymbols: array of string);
begin
  Sub('sub', 'realtimes', ASymbols, 0, True);
end;

procedure TToobitMarketStream.SubscribeDepth(const ASymbols: array of string);
begin
  Sub('sub', 'depth', ASymbols, 0, True);
end;

procedure TToobitMarketStream.SubscribeDiffDepth(const ASymbols: array of string);
begin
  Sub('sub', 'diffDepth', ASymbols, 0, True);
end;

procedure TToobitMarketStream.SubscribeBookTicker(const ASymbols: array of string);
begin
  Sub('sub', 'bookTicker', ASymbols, 0, False);
end;

procedure TToobitMarketStream.SubscribeMarkPrice(const ASymbols: array of string);
begin
  Sub('sub', 'markPrice', ASymbols, 0, False);
end;

procedure TToobitMarketStream.SubscribeIndex(const ASymbols: array of string);
begin
  Sub('sub', 'index', ASymbols, 0, True);
end;

procedure TToobitMarketStream.SubscribeAllTickers;
begin
  Sub('sub', 'wholeRealTime', [], 0, False);
end;

procedure TToobitMarketStream.SubscribeAllBookTickers;
begin
  Sub('sub', 'wholeBookTicker', [], 0, False);
end;

{ TToobitUserStream }

constructor TToobitUserStream.Create(AClient: TToobitClient; AKind: TToobitUserStreamKind;
  ATransport: TToobitWsTransport);
begin
  inherited Create(ATransport);
  FClient := AClient;
  FKind := AKind;
end;

function TToobitUserStream.ResolveUrl: string;
var
  LResp: string;
begin
  if FKind = usSpot then
    LResp := FClient.Request(hmPost, '/api/v1/userDataStream', nil, tsSigned)
  else
    LResp := FClient.Request(hmPost, '/api/v1/listenKey',
      NewParams.AddIf('category', FCategory), tsSigned);
  FListenKey := JsonField(LResp, 'listenKey');
  if FListenKey = '' then
    raise EToobitWsError.Create('Could not obtain a listenKey: ' + LResp);
  Result := TOOBIT_WS_USER_URL + FListenKey;
end;

function TToobitUserStream.KeepAliveIntervalMs: Integer;
begin
  Result := 30 * 60 * 1000;   // the key is valid for 60 min
end;

procedure TToobitUserStream.KeepAlive;
begin
  if FListenKey = '' then
    Exit;
  if FKind = usSpot then
    FClient.Request(hmPut, '/api/v1/userDataStream',
      NewParams.Add('listenKey', FListenKey), tsSigned)
  else
    FClient.Request(hmPut, '/api/v1/listenKey',
      NewParams.Add('listenKey', FListenKey).AddIf('category', FCategory), tsSigned);
end;

procedure TToobitUserStream.Cleanup;
begin
  if FListenKey = '' then
    Exit;
  if FKind = usSpot then
    FClient.Request(hmDelete, '/api/v1/userDataStream',
      NewParams.Add('listenKey', FListenKey), tsSigned)
  else
    FClient.Request(hmDelete, '/api/v1/listenKey',
      NewParams.Add('listenKey', FListenKey).AddIf('category', FCategory), tsSigned);
  FListenKey := '';
end;

end.
