unit RSValueListEditor;

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
  Windows, Messages, SysUtils, Classes, Controls, Grids, ValEdit, RSCommon,
  RSSysUtils;

{ TODO :
HotTrack in pseudoComboBox
}

{$I RSWinControlImport.inc}

type
  TRSValueListEditor = class;

  TRSValueListEditorCreateEditEvent =
     procedure(Sender:TRSValueListEditor; var Editor:TInplaceEdit) of object;

  TRSValueListEditor = class(TValueListEditor)
  private
    FOnCreateParams: TRSCreateParamsEvent;
    FProps: TRSWinControlProps;
    FOnBeforeSetEditText: TGetEditEvent;
    FOnCreateEditor: TRSValueListEditorCreateEditEvent;
  protected
    FDeleting: boolean;
    procedure CreateParams(var Params:TCreateParams); override;
    procedure TranslateWndProc(var Msg:TMessage);
    procedure WndProc(var Msg:TMessage); override;

    procedure SetCell(ACol, ARow: integer; const Value: string); override;
    function SelectCell(ACol, ARow: integer): boolean; override;
    function CreateEditor: TInplaceEdit; override;
    procedure SetEditText(ACol, ARow: Longint; const Value: string); override;
    procedure WMCommand(var Msg: TWMCommand); message WM_COMMAND;
  public
    constructor Create(AOwner:TComponent); override;
    procedure DeleteRow(ARow: integer); override;
  published
    property OnBeforeSetEditText: TGetEditEvent read FOnBeforeSetEditText write FOnBeforeSetEditText;
    property OnCreateEditor: TRSValueListEditorCreateEditEvent read FOnCreateEditor write FOnCreateEditor;
    property BevelEdges;
    property BevelInner;
    property BevelKind default bkNone;
    property BevelOuter;
    property BevelWidth;
    property OnCanResize;
    property OnResize;
    {$I RSWinControlProps.inc}
  end;

procedure register;

implementation

procedure register;
begin
  RegisterComponents('RSPak', [TRSValueListEditor]);
end;

{
********************************** TRSValueListEditor ***********************************
}
constructor TRSValueListEditor.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  WindowProc:=TranslateWndProc;
end;

procedure TRSValueListEditor.CreateParams(var Params:TCreateParams);
begin
  inherited CreateParams(Params);
  if Assigned(FOnCreateParams) then FOnCreateParams(Params);
end;

procedure TRSValueListEditor.TranslateWndProc(var Msg:TMessage);
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

procedure TRSValueListEditor.WndProc(var Msg:TMessage);
begin
  RSProcessProps(self, Msg, FProps);
  inherited;
end;

 // Gee. They failed to avoid "List index out of bounds". (see original SetCell)
procedure TRSValueListEditor.SetCell(ACol, ARow: integer; const Value: string);
var
  index: integer;
  Line: string;
begin
  index:= ARow - FixedRows;
  if index >= Strings.Count then
  begin
    if ACol = 0 then
      Line:= Value + '='
    else
      Line:= '=' + Value;

    Strings.Add(Line);
  end else
  begin
    if ACol = 0 then
      Line:= Value + '=' + Cells[1, ARow]
    else
      Line:= Cells[0, ARow] + '=' + Value;

    Strings[index]:= Line;
  end;
end;

 // Another bug. OnSelectCell and OnValidate weren't called after deleting a row
function TRSValueListEditor.SelectCell(ACol, ARow: integer): boolean;
begin
  if (ARow <> Row) and (Strings.Count > 0) and IsEmptyRow and not FDeleting then
  begin
    result:= (ARow < Row);
    DeleteRow(Row);
    if not result then
      FocusCell(ACol, ARow - 1, True)
    else
      result:= inherited SelectCell(ACol, ARow);
  end else
    result:= inherited SelectCell(ACol, ARow);
end;

 // In TValueListEditor class FDeleting field is stupidly made private
procedure TRSValueListEditor.DeleteRow(ARow: integer);
begin
  FDeleting:= true;
  try
    inherited;
  finally
    FDeleting:= false;
  end;
end;

function TRSValueListEditor.CreateEditor: TInplaceEdit;
begin
  result:= inherited CreateEditor;
//  TInplaceEditList(InplaceEditor).PickList.ho
  if Assigned(OnCreateEditor) then
    OnCreateEditor(self, result);
end;

procedure TRSValueListEditor.SetEditText(ACol, ARow: Longint; const Value: string);
var v:string;
begin
  v:=Value;
  if Assigned(OnBeforeSetEditText) then
    OnBeforeSetEditText(self, ACol, ARow, v);

  inherited SetEditText(ACol, ARow, v);
end;

 // A bug that prevented ComboBox dropped on grid from showing drop-down list 
procedure TRSValueListEditor.WMCommand(var Msg: TWMCommand);
begin
  RSDispatchEx(self, TWinControl, Msg);
  inherited;
end;

end.
