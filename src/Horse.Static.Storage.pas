unit Horse.Static.Storage;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
  {$IF DEFINED(FPC)}
  Classes, SysUtils,
  {$ELSE}
  System.Classes, System.SysUtils,
  {$ENDIF}
  Horse.Mime;

type
  IHorseStaticFile = interface
    ['{69A4C078-4A1C-4B6A-91D0-17937A208D6C}']
    function GetName: string;
    function GetSize: Int64;
    function GetLastModified: TDateTime;
    function GetContentType: string;
    function GetContentStream: TStream;
  end;

  IHorseStaticStorage = interface
    ['{D7A04D8C-BE63-441F-AF16-EED58F58AC66}']
    function Exists(const APath: string): Boolean;
    function GetFile(const APath: string): IHorseStaticFile;
  end;

  THorseStaticRangeStream = class(TStream)
  private
    FSourceStream: TStream;
    FStartPos: Int64;
    FSize: Int64;
    FCurrentPos: Int64;
    FOwnsSource: Boolean;
  public
    constructor Create(const ASourceStream: TStream; const AStart, ALength: Int64; const AOwnsSource: Boolean = True);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; overload; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;
  end;

  THorseStaticLocalFile = class(TInterfacedObject, IHorseStaticFile)
  private
    FFileName: string;
    FSize: Int64;
    FLastModified: TDateTime;
    FContentType: string;
  public
    constructor Create(const AFileName: string);
    function GetName: string;
    function GetSize: Int64;
    function GetLastModified: TDateTime;
    function GetContentType: string;
    function GetContentStream: TStream;
  end;

  THorseStaticLocalStorage = class(TInterfacedObject, IHorseStaticStorage)
  private
    FPhysicalPath: string;
    function SanitizePath(const APath: string): string;
  private
    class function FileGetLastModified(const AFileName: string): TDateTime; static;
  public
    constructor Create(const APhysicalPath: string);
    function Exists(const APath: string): Boolean;
    function GetFile(const APath: string): IHorseStaticFile;
  end;

implementation

{ THorseStaticRangeStream }

constructor THorseStaticRangeStream.Create(const ASourceStream: TStream; const AStart, ALength: Int64; const AOwnsSource: Boolean);
begin
  inherited Create;
  FSourceStream := ASourceStream;
  FStartPos := AStart;
  FSize := ALength;
  FCurrentPos := 0;
  FOwnsSource := AOwnsSource;
end;

destructor THorseStaticRangeStream.Destroy;
begin
  if FOwnsSource then
    FSourceStream.Free;
  inherited Destroy;
end;

function THorseStaticRangeStream.Read(var Buffer; Count: Longint): Longint;
var
  LMaxToRead: Int64;
begin
  Result := 0;
  if FCurrentPos >= FSize then
    Exit;

  LMaxToRead := FSize - FCurrentPos;
  if Count > LMaxToRead then
    Count := LMaxToRead;

  FSourceStream.Position := FStartPos + FCurrentPos;
  Result := FSourceStream.Read(Buffer, Count);
  Inc(FCurrentPos, Result);
end;

function THorseStaticRangeStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('Write operations are not supported on THorseStaticRangeStream');
end;

function THorseStaticRangeStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  Result := Seek(Int64(Offset), TSeekOrigin(Origin));
end;

function THorseStaticRangeStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FCurrentPos := Offset;
    soCurrent: Inc(FCurrentPos, Offset);
    soEnd: FCurrentPos := FSize + Offset;
  end;

  if FCurrentPos < 0 then
    FCurrentPos := 0;
  if FCurrentPos > FSize then
    FCurrentPos := FSize;

  Result := FCurrentPos;
end;

{ THorseStaticLocalFile }

constructor THorseStaticLocalFile.Create(const AFileName: string);
var
  LSR: TSearchRec;
begin
  FFileName := AFileName;
  FContentType := THorseMimeTypes.GetFileType(FFileName);
  
  if FindFirst(FFileName, faAnyFile, LSR) = 0 then
  begin
    FSize := LSR.Size;
    {$IF DEFINED(FPC)}
      FLastModified := LSR.Time;
    {$ELSE}
      {$IF compilerversion >= 28.0}
        FLastModified := LSR.TimeStamp;
      {$ELSE}
        FLastModified := FileDateToDateTime(LSR.Time);
      {$IFEND}
    {$ENDIF}
    FindClose(LSR);
  end
  else
  begin
    FSize := 0;
    FLastModified := 0;
  end;
end;

function THorseStaticLocalFile.GetName: string;
begin
  Result := ExtractFileName(FFileName);
end;

function THorseStaticLocalFile.GetSize: Int64;
begin
  Result := FSize;
end;

function THorseStaticLocalFile.GetLastModified: TDateTime;
begin
  Result := FLastModified;
end;

function THorseStaticLocalFile.GetContentType: string;
begin
  Result := FContentType;
end;

function THorseStaticLocalFile.GetContentStream: TStream;
begin
  Result := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
end;

{ THorseStaticLocalStorage }

constructor THorseStaticLocalStorage.Create(const APhysicalPath: string);
begin
  FPhysicalPath := ExpandFileName(APhysicalPath);
end;

class function THorseStaticLocalStorage.FileGetLastModified(const AFileName: string): TDateTime;
var
  LSR: TSearchRec;
begin
  Result := 0;
  if FindFirst(AFileName, faAnyFile, LSR) = 0 then
  begin
    {$IF DEFINED(FPC)}
      Result := LSR.Time;
    {$ELSE}
      {$IF compilerversion >= 28.0}
        Result := LSR.TimeStamp;
      {$ELSE}
        Result := FileDateToDateTime(LSR.Time);
      {$IFEND}
    {$ENDIF}
    FindClose(LSR);
  end;
end;

function THorseStaticLocalStorage.SanitizePath(const APath: string): string;
var
  LRoot, LFull, LPathClean: string;
begin
  Result := '';
  LRoot := IncludeTrailingPathDelimiter(FPhysicalPath);

  // Normaliza os delimitadores de path com base na plataforma (Windows/Linux)
  LPathClean := APath;
  if PathDelim = '/' then
    LPathClean := LPathClean.Replace('\', '/')
  else
    LPathClean := LPathClean.Replace('/', '\');

  // Adiciona o delimitador se necessário e resolve os caminhos relativos
  LFull := ExpandFileName(LRoot + LPathClean);

  // Garante que o arquivo está abaixo do diretório raiz (Prevenção de Directory Traversal)
  if LFull.StartsWith(LRoot, True) then
    Result := LFull;
end;

function THorseStaticLocalStorage.Exists(const APath: string): Boolean;
var
  LFilePath: string;
begin
  LFilePath := SanitizePath(APath);
  Result := (LFilePath <> '') and FileExists(LFilePath);
end;

function THorseStaticLocalStorage.GetFile(const APath: string): IHorseStaticFile;
var
  LFilePath: string;
begin
  LFilePath := SanitizePath(APath);
  if (LFilePath <> '') and FileExists(LFilePath) then
    Result := THorseStaticLocalFile.Create(LFilePath)
  else
    Result := nil;
end;

end.
