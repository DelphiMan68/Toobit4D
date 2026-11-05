unit Toobit4D.WS.WebSocket4D;
{$I Toobit4D.inc}

{ WebSocket transport built on WebSocket4D (https://github.com/DelphiMan68/WebSocket4D).
  Windows only (WebSocket4D uses WinHTTP).

  Behaviour of TWebSocket4DClient that this adapter relies on:
    * Connect(URL) is synchronous. It does NOT raise on failure; it reports the problem
      through OnError and returns with Connected = False. OnConnect is raised (on the
      calling thread) only after a successful connection.
    * StartReceiving starts a receive thread. OnTextMessage, OnError and OnDisconnect
      are raised on that thread. When the peer closes the connection, the receive thread
      ends and OnDisconnect is raised once.
    * AutoReconnect is switched OFF here: Toobit4D.Stream does its own reconnect and
      re-subscription.
    * Close waits for the receive thread to finish, so it must not be called from one of
      the client's own callbacks (Toobit4D.Stream never does). }

interface

uses
  SysUtils, WebSocket4D, Toobit4D.Types, Toobit4D.WS.Transport;

type
  TToobitWsTransportWebSocket4D = class(TToobitWsTransport)
  private
    FClient: TWebSocket4DClient;
    procedure ReleaseClient;
    procedure HandleConnect(Sender: TObject);
    procedure HandleDisconnect(Sender: TObject);
    procedure HandleTextMessage(Sender: TObject; const Text: UTF8String);
    procedure HandleError(Sender: TObject; const ErrorMessage: string; ErrorCode: Cardinal);
  public
    destructor Destroy; override;
    procedure Connect(const AUrl: string); override;
    procedure Send(const AText: string); override;
    procedure Disconnect; override;
  end;

implementation

destructor TToobitWsTransportWebSocket4D.Destroy;
begin
  ReleaseClient;
  inherited;
end;

procedure TToobitWsTransportWebSocket4D.ReleaseClient;
var
  LClient: TWebSocket4DClient;
begin
  LClient := FClient;
  FClient := nil;
  if LClient <> nil then
  begin
    try
      LClient.Close;      // raises OnDisconnect (once) if the socket was open
    except
      // already closed
    end;
    LClient.Free;
  end;
end;

procedure TToobitWsTransportWebSocket4D.Connect(const AUrl: string);
begin
  ReleaseClient;
  FClient := TWebSocket4DClient.Create;
  FClient.AutoReconnect := False;          // reconnect is handled by Toobit4D.Stream
  FClient.OnConnect := HandleConnect;
  FClient.OnDisconnect := HandleDisconnect;
  FClient.OnTextMessage := HandleTextMessage;
  FClient.OnError := HandleError;

  FClient.Connect(AUrl);                   // reports failures via OnError, does not raise
  if not FClient.Connected then
    raise EToobitWsError.Create('WebSocket connection failed: ' + AUrl);
  FClient.StartReceiving;                  // OnConnect has already been raised by Connect
end;

procedure TToobitWsTransportWebSocket4D.Send(const AText: string);
var
  LClient: TWebSocket4DClient;
begin
  LClient := FClient;
  if LClient = nil then
    raise EToobitWsError.Create('WebSocket is not connected');
  LClient.SendText(UTF8String(AText));
end;

procedure TToobitWsTransportWebSocket4D.Disconnect;
begin
  // OnDisconnect (-> DoClose) is raised by the client itself if the socket was open
  ReleaseClient;
end;

procedure TToobitWsTransportWebSocket4D.HandleConnect(Sender: TObject);
begin
  DoOpen;
end;

procedure TToobitWsTransportWebSocket4D.HandleDisconnect(Sender: TObject);
begin
  DoClose;
end;

procedure TToobitWsTransportWebSocket4D.HandleTextMessage(Sender: TObject; const Text: UTF8String);
begin
  DoMessage(string(Text));
end;

procedure TToobitWsTransportWebSocket4D.HandleError(Sender: TObject;
  const ErrorMessage: string; ErrorCode: Cardinal);
begin
  if ErrorCode <> 0 then
    DoError(Format('%s (code %d)', [ErrorMessage, ErrorCode]))
  else
    DoError(ErrorMessage);
end;

end.
