program Tests;

{$APPTYPE CONSOLE}

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

uses
  {$IF DEFINED(FPC)}
  Classes, SysUtils,
  {$ELSE}
  System.Classes, System.SysUtils,
  {$ENDIF}
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  Tests.Integration.Static in 'Tests.Integration.Static.pas',
  Horse.Static in '..\src\Horse.Static.pas',
  Horse.Static.Storage in '..\src\Horse.Static.Storage.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;

    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := True;

    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    Results := Runner.Execute;
    if (not Results.AllPassed) then
      System.ExitCode := 1
    else
      System.ExitCode := 0;

    {$IFNDEF CI}
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    {$ENDIF}
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 1;
    end;
  end;
end.
