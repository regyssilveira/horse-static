unit Horse.Static;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
  Horse, Horse.Commons, Horse.Static.Storage,
  {$IF DEFINED(FPC)}
  Classes, SysUtils, DateUtils, StrUtils,
  {$ELSE}
  System.Classes, System.SysUtils, System.DateUtils, System.StrUtils,
  {$ENDIF}
  Horse.Mime;

type
  THorseStaticConfig = record
  private
    FStorage: IHorseStaticStorage;
    FVirtualPath: string;
    FCacheControl: string;
    FUseETag: Boolean;
    FUseLastModified: Boolean;
    FAcceptRanges: Boolean;
    FSpaFallbackFile: string;
  public
    class function Default(const APhysicalPath: string; const AVirtualPath: string = '/'): THorseStaticConfig; static;
    function Storage(const AValue: IHorseStaticStorage): THorseStaticConfig;
    function CacheControl(const AValue: string): THorseStaticConfig;
    function UseETag(const AValue: Boolean): THorseStaticConfig;
    function UseLastModified(const AValue: Boolean): THorseStaticConfig;
    function AcceptRanges(const AValue: Boolean): THorseStaticConfig;
    function SpaFallback(const AIndexFile: string): THorseStaticConfig;
    
    property GetStorage: IHorseStaticStorage read FStorage;
    property GetVirtualPath: string read FVirtualPath;
    property GetCacheControl: string read FCacheControl;
    property GetUseETag: Boolean read FUseETag;
    property GetUseLastModified: Boolean read FUseLastModified;
    property GetAcceptRanges: Boolean read FAcceptRanges;
    property GetSpaFallbackFile: string read FSpaFallbackFile;
  end;

  THorseStatic = class
  private
    FConfig: THorseStaticConfig;
    class function ParseHTTPDate(const ADateStr: string): TDateTime; static;
    class function DateTimeToHTTPDate(const ADateTime: TDateTime): string; static;
    function GenerateETag(const AFile: IHorseStaticFile): string;
    procedure HandleRangeRequest(Req: THorseRequest; Res: THorseResponse; const AFile: IHorseStaticFile; const ARangeHeader: string);
    procedure HandleFullRequest(Res: THorseResponse; const AFile: IHorseStaticFile);
  public
    constructor Create(const AConfig: THorseStaticConfig);
    class function New(const APhysicalPath: string; const AVirtualPath: string = '/'): THorseStaticConfig; overload; static;
    class function Middleware(const AConfig: THorseStaticConfig): THorseCallback; static;
  end;

implementation

{ THorseStaticConfig }

class function THorseStaticConfig.Default(const APhysicalPath: string; const AVirtualPath: string): THorseStaticConfig;
begin
  Result.FStorage := THorseStaticLocalStorage.Create(APhysicalPath);
  Result.FVirtualPath := IncludeTrailingPathDelimiter(AVirtualPath);
  if not Result.FVirtualPath.StartsWith('/') then
    Result.FVirtualPath := '/' + Result.FVirtualPath;
  Result.FCacheControl := 'public, max-age=86400';
  Result.FUseETag := True;
  Result.FUseLastModified := True;
  Result.FAcceptRanges := True;
  Result.FSpaFallbackFile := '';
end;

function THorseStaticConfig.Storage(const AValue: IHorseStaticStorage): THorseStaticConfig;
begin
  Result := Self;
  Result.FStorage := AValue;
end;

function THorseStaticConfig.CacheControl(const AValue: string): THorseStaticConfig;
begin
  Result := Self;
  Result.FCacheControl := AValue;
end;

function THorseStaticConfig.UseETag(const AValue: Boolean): THorseStaticConfig;
begin
  Result := Self;
  Result.FUseETag := AValue;
end;

function THorseStaticConfig.UseLastModified(const AValue: Boolean): THorseStaticConfig;
begin
  Result := Self;
  Result.FUseLastModified := AValue;
end;

function THorseStaticConfig.AcceptRanges(const AValue: Boolean): THorseStaticConfig;
begin
  Result := Self;
  Result.FAcceptRanges := AValue;
end;

function THorseStaticConfig.SpaFallback(const AIndexFile: string): THorseStaticConfig;
begin
  Result := Self;
  Result.FSpaFallbackFile := AIndexFile;
end;

{ THorseStatic }

constructor THorseStatic.Create(const AConfig: THorseStaticConfig);
begin
  FConfig := AConfig;
end;

class function THorseStatic.New(const APhysicalPath: string; const AVirtualPath: string): THorseStaticConfig;
begin
  Result := THorseStaticConfig.Default(APhysicalPath, AVirtualPath);
end;

class function THorseStatic.ParseHTTPDate(const ADateStr: string): TDateTime;
var
  LDay, LMonth, LYear, LHour, LMin, LSec: Word;
  LMonthStr: string;
const
  Months: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
begin
  Result := 0;
  if Length(ADateStr) < 25 then
    Exit;

  LDay := StrToIntDef(Copy(ADateStr, 6, 2), 1);
  LMonthStr := Copy(ADateStr, 9, 3);
  LMonth := 1;
  for var I := 1 to 12 do
  begin
    if SameText(LMonthStr, Months[I]) then
    begin
      LMonth := I;
      Break;
    end;
  end;
  LYear := StrToIntDef(Copy(ADateStr, 13, 4), 1970);
  LHour := StrToIntDef(Copy(ADateStr, 18, 2), 0);
  LMin := StrToIntDef(Copy(ADateStr, 21, 2), 0);
  LSec := StrToIntDef(Copy(ADateStr, 24, 2), 0);

  try
    Result := EncodeDate(LYear, LMonth, LDay) + EncodeTime(LHour, LMin, LSec, 0);
  except
    Result := 0;
  end;
end;

class function THorseStatic.DateTimeToHTTPDate(const ADateTime: TDateTime): string;
const
  Days: array[1..7] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  Months: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  LYear, LMonth, LDay, LHour, LMin, LSec, LMSec: Word;
  LDayOfWeek: Word;
begin
  DecodeDate(ADateTime, LYear, LMonth, LDay);
  DecodeTime(ADateTime, LHour, LMin, LSec, LMSec);
  LDayOfWeek := DayOfWeek(ADateTime);
  Result := Format('%s, %02d %s %d %02d:%02d:%02d GMT', [
    Days[LDayOfWeek], LDay, Months[LMonth], LYear, LHour, LMin, LSec
  ]);
end;

function THorseStatic.GenerateETag(const AFile: IHorseStaticFile): string;
var
  LModifiedTimeHex: string;
  LSizeHex: string;
begin
  LModifiedTimeHex := IntToHex(Round(AFile.GetLastModified * 1000000), 1);
  LSizeHex := IntToHex(AFile.GetSize, 1);
  Result := 'W/"' + LSizeHex + '-' + LModifiedTimeHex + '"';
end;

procedure THorseStatic.HandleRangeRequest(Req: THorseRequest; Res: THorseResponse; const AFile: IHorseStaticFile; const ARangeHeader: string);
var
  LParts, LSubParts: TArray<string>;
  LRangeStr: string;
  LStart, LEnd, LFileSize, LRangeLength: Int64;
  LRangeStream: THorseStaticRangeStream;
  LFileStream: TStream;
begin
  LFileSize := AFile.GetSize;
  LStart := 0;
  LEnd := LFileSize - 1;

  LParts := ARangeHeader.Split(['=']);
  if Length(LParts) >= 2 then
  begin
    LRangeStr := LParts[1].Trim;
    LSubParts := LRangeStr.Split(['-']);
    if Length(LSubParts) > 0 then
    begin
      if LSubParts[0] = '' then
      begin
        if Length(LSubParts) > 1 then
        begin
          LStart := LFileSize - StrToInt64Def(LSubParts[1], 0);
          if LStart < 0 then
            LStart := 0;
        end;
      end
      else
      begin
        LStart := StrToInt64Def(LSubParts[0], 0);
        if (Length(LSubParts) > 1) and (LSubParts[1] <> '') then
          LEnd := StrToInt64Def(LSubParts[1], LFileSize - 1);
      end;
    end;
  end;

  if (LEnd >= LFileSize) then
    LEnd := LFileSize - 1;

  if (LStart > LEnd) or (LStart < 0) or (LEnd < 0) then
  begin
    Res.Status(THTTPStatus.RequestedRangeNotSatisfiable);
    Res.AddHeader('Content-Range', 'bytes */' + LFileSize.ToString);
    Res.Send('');
    Exit;
  end;

  LRangeLength := LEnd - LStart + 1;
  LFileStream := AFile.GetContentStream;

  LRangeStream := THorseStaticRangeStream.Create(LFileStream, LStart, LRangeLength, True);

  Res.Status(THTTPStatus.PartialContent);
  Res.AddHeader('Content-Range', Format('bytes %d-%d/%d', [LStart, LEnd, LFileSize]));
  Res.AddHeader('Accept-Ranges', 'bytes');
  Res.AddHeader('Content-Length', LRangeLength.ToString);
  Res.SendFile(LRangeStream, AFile.GetName, AFile.GetContentType);
end;

procedure THorseStatic.HandleFullRequest(Res: THorseResponse; const AFile: IHorseStaticFile);
begin
  Res.Status(THTTPStatus.Ok);
  Res.AddHeader('Accept-Ranges', 'bytes');
  Res.AddHeader('Content-Length', AFile.GetSize.ToString);
  Res.SendFile(AFile.GetContentStream, AFile.GetName, AFile.GetContentType);
end;

class function THorseStatic.Middleware(const AConfig: THorseStaticConfig): THorseCallback;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
    var
      LRequestPath, LCleanPath, LETag: string;
      LFile: IHorseStaticFile;
      LStatic: THorseStatic;
      LIfNoneMatch, LIfModifiedSince: string;
      LUseRange: Boolean;
      LRangeHeader: string;
      LModifiedTimeUTC: TDateTime;
    begin
      LRequestPath := Req.RawWebRequest.PathInfo;
      
      // Remove o prefixo virtual se houver
      if LRequestPath.StartsWith(AConfig.GetVirtualPath, True) then
        LCleanPath := Copy(LRequestPath, Length(AConfig.GetVirtualPath) + 1, MaxInt)
      else
        LCleanPath := LRequestPath;

      // Sanitiza caminho contra Traversal e confere existência
      if not AConfig.GetStorage.Exists(LCleanPath) then
      begin
        // Se SPA Fallback estiver ativado, tenta o fallback
        if (AConfig.GetSpaFallbackFile <> '') and AConfig.GetStorage.Exists(AConfig.GetSpaFallbackFile) then
          LCleanPath := AConfig.GetSpaFallbackFile
        else
        begin
          Next;
          Exit;
        end;
      end;

      LFile := AConfig.GetStorage.GetFile(LCleanPath);
      if not Assigned(LFile) then
      begin
        Next;
        Exit;
      end;

      LStatic := THorseStatic.Create(AConfig);
      try
        // Configura cabeçalho de controle de cache
        if AConfig.GetCacheControl <> '' then
          Res.AddHeader('Cache-Control', AConfig.GetCacheControl);

        // Configura ETag e validação conditional (If-None-Match)
        if AConfig.GetUseETag then
        begin
          LETag := LStatic.GenerateETag(LFile);
          Res.AddHeader('ETag', LETag);
          
          LIfNoneMatch := Req.Headers['If-None-Match'];
          if (LIfNoneMatch <> '') and (LIfNoneMatch = LETag) then
          begin
            Res.Status(THTTPStatus.NotModified);
            Res.Send('');
            Exit;
          end;
        end;

        // Configura Last-Modified e validação conditional (If-Modified-Since)
        if AConfig.GetUseLastModified then
        begin
          // Data de modificação no formato UTC/GMT
          LModifiedTimeUTC := UniversalTimeToLocalTime(LFile.GetLastModified); // Converte de local para UTC se o arquivo retornar local
          // FindFirst no Delphi retorna tempo local. Para responder como HTTP GMT, fazemos a conversão para GMT
          // No Delphi/Lazarus, TTimeZone.Local.ToUniversalTime é o padrão, mas para compatibilidade multiplataforma pura:
          // LocalTimeToUniversalTime está em DateUtils
          LModifiedTimeUTC := LocalTimeToUniversalTime(LFile.GetLastModified);
          
          Res.AddHeader('Last-Modified', DateTimeToHTTPDate(LModifiedTimeUTC));

          LIfModifiedSince := Req.Headers['If-Modified-Since'];
          if LIfModifiedSince <> '' then
          begin
            if ParseHTTPDate(LIfModifiedSince) >= LModifiedTimeUTC then
            begin
              Res.Status(THTTPStatus.NotModified);
              Res.Send('');
              Exit;
            end;
          end;
        end;

        // Processa requisição de Range se aceita e enviada pelo cliente
        LUseRange := False;
        if AConfig.GetAcceptRanges then
        begin
          LRangeHeader := Req.Headers['Range'];
          if (LRangeHeader <> '') and LRangeHeader.StartsWith('bytes=') then
            LUseRange := True;
        end;

        if LUseRange then
          LStatic.HandleRangeRequest(Req, Res, LFile, LRangeHeader)
        else
          LStatic.HandleFullRequest(Res, LFile);

      finally
        LStatic.Free;
      end;
    end;
end;

end.
