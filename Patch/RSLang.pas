unit RSLang;

{ *********************************************************************** }
{                                                                         }
{ RSPak                                    Copyright (c) Rozhenko Sergey  }
{ http://sites.google.com/site/sergroj/                                   }
{ sergroj@mail.ru                                                         }
{                                                                         }
{ This file is a subject to any one of these licenses at your choice:     }
{ BSD License, MIT License, Apache License, Mozilla Public License.       }
{                                                                         }
{ *********************************************************************** )

 You can edit language files with my tool:
  http://www.grayface.nm.ru/TxtEdit.rar

{ *********************************************************************** }
{$I RSPak.inc}

interface

uses
  SysUtils, Classes, Windows, Messages, RSQ, RSSysUtils, RSStrUtils, TypInfo,
  Graphics, Controls, StdCtrls;

type
  TRSLoadSectionEvent = procedure(var Errors:string) of object;

  TRSLangItem = record
    Name: string;
    Value: PStr;
  end;
  PRSLangItem = ^TRSLangItem;

  TRSLangSection = class(TObject)
  public
    Name: string;
    Form: TComponent;
    Items: array of TRSLangItem; // Custom items
    Restrictions: array of string;
    Allowed: array of string;
    OnLoad: TRSLoadSectionEvent;
    function AddItem(AName:string; var AValue:string):PRSLangItem;
    procedure AddRestriction(s:string);
    procedure AddAllowed(s:string);
  end;

  TRSLanguage = class(TObject)
  protected
    FLangBackup: string;
    FNeedBackup: boolean;

    function DoCharsetToIdent(k: int): string;
    function CheckClass(c:TClass; s:string):boolean;
    procedure SetCharsets(Obj:TObject; Charset:int; Edits:boolean; Path: string;
      Backup: boolean);
    function SetGlobalCharset(Form:TComponent; s:string; Edits:boolean):boolean;

    procedure WriteSection(var s:string; var Sect:TRSLangSection;
      SkipEmptyStrings:boolean);
    procedure AddBackup(key, value: string);
  public
    Sections: array of TRSLangSection;
    destructor Destroy; override;
    function AddSection(Name: string; Form:TComponent):TRSLangSection;
    function LoadLanguage(f: string; Silent:boolean):string;
    function MakeLanguage(SkipEmptyStrings:boolean=true):string;
    property LanguageBackup: string read FLangBackup write FLangBackup;
  end;

var RSLanguage:TRSLanguage;

implementation

function IsThere(const s1, s2:string):boolean;
begin
  if Length(s1)>=Length(s2) then
    result := CompareString(LOCALE_USER_DEFAULT, NORM_IGNORECASE, ptr(s1),
      Length(s2), ptr(s2), Length(s2)) = 2
  else
    result:=false;
end;

function HasString(s:string; Arr:array of string):boolean;
var i:int;
begin
  result:=true;
  for i:=0 to High(Arr) do
    if IsThere(s, Arr[i]) then
      exit;
  result:=false;
end;

type
  TStripControl = class(TControl)
  end;

{
******************************** TRSLangSection ********************************
}

function TRSLangSection.AddItem(AName:string; var AValue:string):PRSLangItem;
var i:int;
begin
  i:=Length(Items);
  SetLength(Items, i+1);
  result:=@Items[i];
  result.Name:=AName;
  result.Value:=@AValue;
end;

procedure TRSLangSection.AddRestriction(s:string);
var i:int;
begin
  i:=Length(Restrictions);
  SetLength(Restrictions, i+1);
  Restrictions[i]:=s;
end;

procedure TRSLangSection.AddAllowed(s:string);
var i:int;
begin
  i:=Length(Allowed);
  SetLength(Allowed, i+1);
  Allowed[i]:=s;
end;

{
********************************** TRSLanguage *********************************
}

destructor TRSLanguage.Destroy;
var i:int;
begin
  for i:=0 to Length(Sections)-1 do
    Sections[i].Free;
  inherited;
end;

procedure TRSLanguage.AddBackup(key, value: string);
begin
  if FNeedBackup then
    FLangBackup:= key + #9 + RSStringReplace(value, #13#10, #10) + #13#10 + FLangBackup;
end;

function TRSLanguage.AddSection(Name: string; Form:TComponent):TRSLangSection;
var i:int;
begin
  i:=Length(Sections);
  SetLength(Sections, i+1);
  result:=TRSLangSection.Create;
  Sections[i]:=result;
  result.Name:=Name;
  result.Form:=Form;
end;

function TRSLanguage.DoCharsetToIdent(k: int): string;
begin
  if not CharsetToIdent(k, result) then
    result:= IntToStr(k);
end;

function TRSLanguage.CheckClass(c:TClass; s:string):boolean;
begin
  result:=true;
  while c<>nil do
  begin
    if c.ClassNameIs(s) then exit;
    c:=c.ClassParent;
  end;
  result:=false;
end;

procedure TRSLanguage.SetCharsets(Obj:TObject; Charset:int; Edits:boolean; Path: string;
   Backup: boolean);
var
  i, Count:int;
  PropList:PPropList; PropInfo:PPropInfo;
  Obj1:TObject;
begin
  if (Obj is TCustomEdit)<>Edits then
    exit;
  Count:=GetTypeData(obj.ClassInfo)^.PropCount;
  if Count<=0 then exit;
  Obj1:=nil;
  GetMem(PropList, Count * sizeof(pointer));
  try
    GetPropInfos(obj.ClassInfo, PropList);
    for i := 0 to Count - 1 do
    begin
      PropInfo:= PropList^[i];
      if PropInfo = nil then
        Break;

      if PropInfo.PropType^^.Kind=tkClass then
        Obj1:= GetObjectProp(Obj, PropInfo)
      else
        continue;

      if Obj1 = nil then continue;

      if Obj1 is TFont then
      begin
        if TFontCharset(Charset) <> TFont(Obj1).Charset then
          if Backup then
            AddBackup(Path + PropInfo.Name + '.Charset', DoCharsetToIdent(TFont(Obj1).Charset))
          else
            TFont(Obj1).Charset:= TFontCharset(Charset);
            
        continue;
      end;

      SetCharsets(Obj1, Charset, Edits, Path + PropInfo.Name + '.', Backup);
    end;
  finally
    FreeMem(PropList, Count * sizeof(pointer));
  end;
end;

function TRSLanguage.SetGlobalCharset(Form:TComponent; s:string; Edits:boolean):boolean;
var i, Charset:int;
begin
  result:=IdentToCharset(s, Charset);
  if not result then exit;
  for i:=0 to Form.ComponentCount-1 do
  begin
    SetCharsets(Form.Components[i], Charset, Edits, Form.Components[i].Name + '.', true);
  end;
  SetCharsets(Form, Charset, Edits, '', true);

  SetCharsets(Form, Charset, Edits, '', false);
  for i:=0 to Form.ComponentCount-1 do
  begin
    SetCharsets(Form.Components[i], Charset, Edits, Form.Components[i].Name + '.', false);
  end;
end;

function TRSLanguage.LoadLanguage(f:string; Silent:boolean):string;
const
  WrongSect = 'Unknown section.';
  WrongLines = 'The following properties weren''t loaded:';
  ErrorTitle = 'Language loaded with errors';

var Sect:TRSLangSection; SectAdded:boolean;

  procedure ErrorSection(Name, ErrorText:string);
  begin
    if result<>'' then
      result:=result+#13#10;
    result:=result+Name+#13#10+ErrorText+#13#10;
  end;

  procedure ErrorLine(Name, Value:string);
  begin
    if not SectAdded then
    begin
      SectAdded:=true;
      ErrorSection(Sect.Name, WrongLines);
    end;
    result:=result+'  '+Name+#13#10;
  end;

label loop, loop1, AfterCase;
var
  ps1, ps2, ps3: TRSParsedString;
  Obj, Obj1:TObject;
  PropInfo:PPropInfo; PropType:PTypeInfo;
  s,s1,s2: string;
  i,j,k,L: int;
begin
  FNeedBackup:= f <> FLangBackup;
  if not FNeedBackup then
    FLangBackup:= '';

  ps2:=nil; ps3:=nil; Sect:=nil;
  ps1:=RSParseString(f, [#13#10]);
  for i:=0 to RSGetTokensCount(ps1, true)-1 do
  begin
    if pchar(ps1[i*2])^=';' then continue;
    ps2:=RSParseToken(ps1, i, [#9]);
    if (Length(ps2)<4) then continue;
    s:=RSGetToken(ps2, 0);
    s1:=RSGetTokens(ps2, 1);

    if s='' then
      if s1='' then
        continue
      else
      begin
        if (Sect<>nil) then
        begin
          AddBackup('', Sect.Name);
          if Assigned(Sect.OnLoad) then
            Sect.OnLoad(s);
          if s<>'' then
            ErrorLine(s, '');
        end;

        for j:=0 to Length(Sections)-1 do
          if SameText(s1, Sections[j].Name) then
          begin
            Sect:= Sections[j];
            SectAdded:= false;
            goto loop;
          end;
        Sect:=nil;
        ErrorSection(s1, WrongSect);
        continue;
      end;

    if Sect=nil then continue;

    s1:=RSStringReplace(s1, #10, #13#10);

    with Sect do
    begin

       // Custom items
      for j:=0 to Length(Items)-1 do
        if SameText(s, Items[j].Name) then
        begin
          AddBackup(s, Items[j].Value^);
          Items[j].Value^:=s1;
          goto loop;
        end;

       // Restrictions
      if HasString(s, Restrictions) and not HasString(s, Allowed) then
      begin
        ErrorLine(s, s1);
        continue;
      end;

      Obj:=Form;
      if Obj=nil then
      begin
        ErrorLine(s, s1);
        continue;
      end;

       // My props

      if SameText(s, 'GlobalCharset') then
      begin
        SetGlobalCharset(Form, s1, false);
        goto loop;
      end;

      if SameText(s, 'EditsCharset') then
      begin
        SetGlobalCharset(Form, s1, true);
        goto loop;
      end;

       // RTTI props

      ps3:=RSParseToken(ps2, 0, ['.']);

      try
        k:=RSGetTokensCount(ps3)-1;

        j:=0;
         // Components Chain
        while j<k do
        begin
          Obj1:= TComponent(Obj).FindComponent(RSGetToken(ps3, j));
          if Obj1 = nil then break;
          Obj:= Obj1;
          Inc(j);
        end;

         // Objects Chain
        while j<k do
        begin
          s2:= RSGetToken(ps3, j);
          PropInfo:= GetPropInfo(Obj, s2);
          if (PropInfo<>nil) and (PropInfo.PropType^.Kind = tkClass) then
            Obj1:=GetObjectProp(Obj, PropInfo)
          else
            Obj1:=nil;

// Kinda case

          if Obj1<>nil then
          begin
            Obj:=Obj1;
            goto AfterCase;
          end;

          if (Obj is TCollection) and RSVal(s2, L) and (L>=0) and
             (L<TCollection(Obj).Count) then
          begin
            Obj:=TCollection(Obj).Items[L];
            goto AfterCase;
          end;

          Obj1:=ptr(Obj.FieldAddress(s2));
          if Obj1=nil then
          begin
            ErrorLine(s, s1);
            goto loop1;
          end else
            Obj:=pptr(Obj1)^;
AfterCase:
          Inc(j);
        end;

         // Target Property

        s2:=RSGetToken(ps3, k);

         // Special Cases

        if (Obj is TStrings) and SameText(s2, 'Strings') then
        begin
          AddBackup(s, TStrings(Obj).Text);
          TStrings(Obj).Text:=s1;
          continue;
        end;

         // Common Case

        PropInfo:=GetPropInfo(Obj, s2);

        if PropInfo=nil then
        begin
          if (Obj is TControl) and SameText(s2, 'Text') then
          begin
            AddBackup(s, TStripControl(Obj).Text);
            TStripControl(Obj).Text:=s1;
            continue;
          end;
          ErrorLine(s, s1);
          continue;
        end;

        PropType:=PropInfo.PropType^;
        case PropType.Kind of
          tkString, tkLString, tkWString:
            if not (Obj is TComponent) or (PropInfo.Name<>'Name') then
            begin
              AddBackup(s, GetStrProp(Obj, PropInfo));
              SetStrProp(Obj, PropInfo, s1);
              continue;
            end;

          tkInteger:
            if (PropType.Name = 'TFontCharset') and
               (IdentToCharset(s1, j) or RSVal(s1, j) and (DWord(j)<256)) then
            begin
              AddBackup(s, DoCharsetToIdent(GetOrdProp(Obj, PropInfo)));
              SetOrdProp(Obj, PropInfo, j);
              continue;
            end;

          {tkChar:
            if length(s1)=1 then
              SetOrdProp(Obj, PropInfo, int(s1[1]))
            else
              if (length(s1)>1) and (length(s1)<=4) and (s1[1]='#') and
                MyVal(copy(s1, 2, length(s2)-1), j) and (j in [0..255]) then
              begin
                SetOrdProp(Obj, PropInfo, j);
              end else
                ErrorLine(s, s1);}

        end;
        ErrorLine(s, s1);
loop1:
      except
        ErrorLine(s, s1);
      end;
    end;
loop:
  end;

  if (Sect<>nil) then
  begin
    AddBackup('', Sect.Name);
    if Assigned(Sect.OnLoad) then
    begin
      s:= '';
      Sect.OnLoad(s);
      if s<>'' then
        ErrorLine(s, '');
    end;
  end;

  if not Silent and (result<>'') then
    MessageBox(0, ptr(result), ErrorTitle, MB_OK or MB_ICONSTOP or MB_TASKMODAL);
end;

procedure TRSLanguage.WriteSection(var s:string; var Sect:TRSLangSection;
                                   SkipEmptyStrings:boolean);

  procedure AddLine(Name, Value:string);
  begin
    s:= s + Name + #9 + Value + #13#10;
  end;

   // Strings with Restrictions check
  procedure AddLineEx(Name, Value:string);
  begin
    Value:= RSStringReplace(Value, #13#10, #10);
    if not HasString(Name, Sect.Restrictions) or HasString(Name, Sect.Allowed) then
      AddLine(Name, Value);
  end;

  procedure WriteObject(Obj:TObject; Prefix:string);
  var i, Count:int; s1:string;
    PropList:PPropList; PropInfo:PPropInfo;
    Obj1:TObject;
  begin
    if Obj is TStrings then
    begin
      s1:=TStrings(Obj).Text;
      if not SkipEmptyStrings or (s1<>'') then
        AddLineEx(Prefix+'Strings', s1);
    end;

    if Obj is TCollection then
      for i:=0 to TCollection(Obj).Count-1 do
        WriteObject(TCollection(Obj).Items[i], Prefix+IntToStr(i)+'.'); 

    Count:=GetTypeData(obj.ClassInfo)^.PropCount;
    if Count <= 0 then  exit;
    GetMem(PropList, Count * sizeof(pointer));
    try
      GetPropInfos(obj.ClassInfo, PropList);
      for i:= 0 to Count-1 do
      begin
        PropInfo:= PropList^[i];
        if PropInfo = nil then
          Break;

        case PropInfo.PropType^^.Kind of
          tkClass:
          begin
            Obj1:= GetObjectProp(Obj, PropInfo);
            if Obj1 = nil then  continue;
            if not (Obj1 is TComponent) or (TComponent(Obj1).Owner=Obj) then
              WriteObject(Obj1, Prefix + PropInfo.Name + '.');
          end;
          tkString, tkLString, tkWString:
          begin
            if PropInfo.Name = 'Name' then  continue;
            s1:= GetStrProp(Obj, PropInfo);
            if not SkipEmptyStrings or (s1<>'') then
              AddLineEx(Prefix + PropInfo.Name, s1);
          end;
        end;
        
      end;
    finally
      FreeMem(PropList, Count * sizeof(pointer));
    end;
  end;

  procedure WriteComponent(Obj:TComponent; Prefix:string);
  var i:int;
  begin
    WriteObject(Obj, Prefix);
    with Obj do
      for i:=0 to ComponentCount-1 do
        if Components[i].Name<>'' then
          WriteComponent(Components[i], Prefix+Components[i].Name+'.');
  end;

var i:int;
begin
  AddLine('', Sect.Name);
  with Sect do
  begin
    for i:=0 to Length(Items)-1 do
      AddLine(Items[i].Name, RSStringReplace(Items[i].Value^, #13#10, #10));

    if Form<>nil then
      WriteComponent(Form, '');
  end;
end;

function TRSLanguage.MakeLanguage(SkipEmptyStrings:boolean=true):string;
var i:int;
begin
  for i:=0 to Length(Sections)-1 do
  begin
    WriteSection(result, Sections[i], SkipEmptyStrings);
    result:=result+#13#10;
  end;
end;

initialization
  RSLanguage:=TRSLanguage.Create;
finalization
  RSLanguage.Free;
end.
