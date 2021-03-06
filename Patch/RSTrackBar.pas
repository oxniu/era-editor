unit RSTrackBar;

{ *********************************************************************** }
{                                                                         }
{ RSPak                                    Copyright (c) Rozhenko Sergey  }
{ http://sites.google.com/site/sergroj/                                   }
{ sergroj@mail.ru                                                         }
{                                                                         }
{ This file is a subject to any one of these licenses at your choice:     }
{ BSD License, MIT License, Apache License, Mozilla Public License.       }
{                                                                         }
{ *********************************************************************** }
{$I RSPak.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, ComCtrls, CommCtrl, RSCommon,
  RSQ, Graphics;

{$I RSWinControlImport.inc}

type
  TRSTrackBar = class;

  TRSTrackBarAdjustRectEvent = procedure(Sender:TRSTrackBar; var r:TRect) of object;

  TRSTrackBar = class(TTrackBar)
  private
    FOnAdjustClickRect: TRSTrackBarAdjustRectEvent;
    FOnCreateParams: TRSCreateParamsEvent;
    FProps: TRSWinControlProps;
    FSelEnabled: boolean;
    FRestoreMsg: PMessage;
    FRestoreLParam: int;
    procedure SetSelEnabled(v: boolean);
  protected
    procedure CreateParams(var Params:TCreateParams); override;
    procedure TranslateWndProc(var Msg:TMessage);
    procedure WndProc(var Msg:TMessage); override;

    procedure AdjustClickRect(var r:TRect); virtual;
    procedure WMLButtonDown(var AMsg:TWMLButtonDown); message WM_LButtonDown;
  public
    constructor Create(AOwner:TComponent); override;
    procedure DefaultHandler(var message); override;
  published
    property BevelEdges;
    property BevelInner;
    property BevelKind default bkNone;
    property BevelOuter;
    property BevelWidth;
    property SelEnabled: boolean read FSelEnabled write SetSelEnabled default false;
    property OnAdjustClickRect: TRSTrackBarAdjustRectEvent read FOnAdjustClickRect write FOnAdjustClickRect;
    property OnClick;
    property OnCanResize;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    {$I RSWinControlProps.inc}
  end;
  
procedure register;

implementation

uses Types;

procedure register;
begin
  RegisterComponents('RSPak', [TRSTrackBar]);
end;

{
********************************** TRSTrackBar ***********************************
}
constructor TRSTrackBar.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  WindowProc:=TranslateWndProc;
  Height:=33;
end;

procedure TRSTrackBar.CreateParams(var Params:TCreateParams);
begin
  inherited;
  if not FSelEnabled then
    Params.Style:= Params.Style and not TBS_ENABLESELRANGE;
    
  if Assigned(FOnCreateParams) then FOnCreateParams(Params);
end;

procedure TRSTrackBar.TranslateWndProc(var Msg:TMessage);
var b:boolean;
begin
  if assigned(FProps.OnWndProc) then
  begin
    b:=false;
    FProps.OnWndProc(Self, Msg, b, WndProc);
    if b then exit;
  end;
  WndProc(Msg);
end;

procedure TRSTrackBar.WndProc(var Msg:TMessage);
begin
  RSProcessProps(self, Msg, FProps);
  inherited;
end;

procedure TRSTrackBar.AdjustClickRect(var r:TRect);
begin
  if Assigned(FOnAdjustClickRect) then
    FOnAdjustClickRect(self, r);
end;

procedure TRSTrackBar.WMLButtonDown(var AMsg:TWMLButtonDown);
var r,r1:TRect; Msg1:TMessage;
begin
  Perform(TBM_GETCHANNELRECT, 0, int(@r1));
  Perform(TBM_GETTHUMBRECT, 0, int(@r));
  if r1.Left>r.Left then  r1.Left:=r.Left;
  if r1.Top>r.Top then  r1.Top:=r.Top;
  if r1.Right<r.Right then  r1.Right:=r.Right;
  if r1.Bottom<r.Bottom then  r1.Bottom:=r.Bottom;
  AdjustClickRect(r1);

  with AMsg do
    if (YPos>=r1.Top) and (YPos<r1.Bottom) and
       (XPos>=r1.Left) and (XPos<r1.Right) then
    begin
      Msg1:=TMessage(AMsg);
      XPos:= (r.Left + r.Right) div 2;
      YPos:= (r.Top + r.Bottom) div 2;
      FRestoreMsg:= @AMsg; // To make OnMouseDown work properly
      FRestoreLParam:= Msg1.LParam;
      try
        inherited;
      finally
        FRestoreMsg:=nil;
      end;
      Msg1.Msg:=WM_MOUSEMOVE;
      DefaultHandler(Msg1);
    end else
      inherited;
end;

procedure TRSTrackBar.DefaultHandler(var message);
begin
  inherited;
  if FRestoreMsg = @message then
  begin
    TMessage(message).LParam:=FRestoreLParam;
    FRestoreMsg:=nil;
  end;
end;

procedure TRSTrackBar.SetSelEnabled(v: boolean);
begin
  if v=FSelEnabled then exit;
  FSelEnabled:=v;
  RecreateWnd;
end;

end.
