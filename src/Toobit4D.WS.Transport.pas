unit Toobit4D.WS.Transport;
{$I Toobit4D.inc}

{ Abstract WebSocket transport.
  Toobit4D.Stream only talks to this class, so the concrete WebSocket library is
  isolated in ONE small unit (Toobit4D.WS.WebSocket4D.pas). }

interface

uses
  SysUtils;

type
  TToobitWsNotifyEvent = procedure(Sender: TObject) of object;
  TToobitWsTextEvent   = procedure(Sender: TObject; const AText: string) of object;

  TToobitWsTransport = class
  private
    FOnOpen: TToobitWsNotifyEvent;
    FOnClose: TToobitWsNotifyEvent;
    FOnMessage: TToobitWsTextEvent;
    FOnError: TToobitWsTextEvent;
  protected
    procedure DoOpen;
    procedure DoClose;
    procedure DoMessage(const AText: string);
    procedure DoError(const AMessage: string);
  public
    { Opens the connection and returns; DoOpen must be raised once the socket is
      usable, DoMessage for every text frame, DoClose when the socket closes. }
    procedure Connect(const AUrl: string); virtual; abstract;
    procedure Send(const AText: string); virtual; abstract;
    procedure Disconnect; virtual; abstract;

    property OnOpen: TToobitWsNotifyEvent read FOnOpen write FOnOpen;
    property OnClose: TToobitWsNotifyEvent read FOnClose write FOnClose;
    property OnMessage: TToobitWsTextEvent read FOnMessage write FOnMessage;
    property OnError: TToobitWsTextEvent read FOnError write FOnError;
  end;

implementation

procedure TToobitWsTransport.DoOpen;
begin
  if Assigned(FOnOpen) then FOnOpen(Self);
end;

procedure TToobitWsTransport.DoClose;
begin
  if Assigned(FOnClose) then FOnClose(Self);
end;

procedure TToobitWsTransport.DoMessage(const AText: string);
begin
  if Assigned(FOnMessage) then FOnMessage(Self, AText);
end;

procedure TToobitWsTransport.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then FOnError(Self, AMessage);
end;

end.
