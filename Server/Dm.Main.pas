unit Dm.Main;

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.VCLUI.Wait, FireDAC.Comp.Client,
  Data.DB, System.JSON, uAIProvider;

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
  // Store API keys in environment variables or a secure config file —
  // never hard-code them in source code that is committed to version control.
  AI_PROVIDER_TYPE = aptClaude; // Switch to aptChatGPT to use OpenAI
  AI_API_KEY = ''; // Set at runtime or load from config

procedure TDm.DataModuleCreate(Sender: TObject);
begin
  // SQLite — database file path can be adjusted as needed
  Conn.Params.Database := ExtractFilePath(ParamStr(0)) + 'data.db';
  Conn.Connected := True;
end;

function TDm.GetAIProvider: IAIProvider;
begin
  Result := TAIProviderFactory.Create(AI_PROVIDER_TYPE, AI_API_KEY);
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
