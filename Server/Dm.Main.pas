unit Dm.Main;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.IniFiles,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.VCLUI.Wait, FireDAC.Comp.Client,
  Data.DB, System.JSON, uAIProvider, uAIModels, uAIProviderIntf;

type
  TDm = class(TDataModule)
    Conn: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
  private
    // ---------------------------------------------------------------------------
    // Returns a configured AI provider.
    // Switch the provider type or API key here without touching any other unit.
    // ---------------------------------------------------------------------------
    function GetAIProvider: IAIProvider;
  public
    // Receives a free-text prompt, forwards it to the AI provider and returns
    // the structured JSON response: { "type": "text"|"array", "data": ... }
    function ProcessPrompt(const APrompt: string): TJSONObject;
  end;

var
  Dm: TDm;

implementation

{$R *.dfm}

const
  INI_FILENAME    = 'ChatAI.ini';
  INI_SECTION     = 'AI';
  INI_KEY_PROVIDER = 'Provider';   // Claude or ChatGPT
  INI_KEY_APIKEY   = 'ApiKey';

function GetIniPath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + INI_FILENAME;
end;

procedure TDm.DataModuleCreate(Sender: TObject);
begin
  // SQLite — database file path can be adjusted as needed
  Conn.Params.Database := ExtractFilePath(ParamStr(0)) + 'data.db';
  Conn.Connected := True;
end;

function TDm.GetAIProvider: IAIProvider;
var
  LIni: TIniFile;
  LProviderStr: string;
  LApiKey: string;
  LProviderType: TAIProviderType;
begin
  LIni := TIniFile.Create(GetIniPath);
  try
    LProviderStr := LIni.ReadString(INI_SECTION, INI_KEY_PROVIDER, 'Claude');
    LApiKey      := LIni.ReadString(INI_SECTION, INI_KEY_APIKEY, '');

    if LApiKey = ''
      then raise Exception.Create('API key not configured. Please set ApiKey in ' + GetIniPath);

    LProviderType := TAIProviderType.FromName(LProviderStr);
    Result := TAIProviderFactory.Create(LProviderType, LApiKey);
  finally
    LIni.Free;
  end;
end;

function TDm.ProcessPrompt(const APrompt: string): TJSONObject;
var
  LProvider: IAIProvider;
begin
  LProvider := GetAIProvider;
  Result := LProvider.Send(APrompt);
  // No manual Free needed — IAIProvider is reference-counted
end;

end.
