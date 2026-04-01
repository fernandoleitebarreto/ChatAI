unit uAIProviderIntf;

interface

uses
  System.JSON;

type

  // ---------------------------------------------------------------------------
  // Base interface for any AI provider
  // ---------------------------------------------------------------------------
  IAIProvider = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']

    // Sends a prompt and returns JSON in the format:
    // { "type": "text"|"array", "data": ... }
    function Send(const APrompt: string): TJSONObject;

    // Common configuration getters and setters
    function GetModel: string;
    function GetMaxTokens: Integer;
    function GetSystemPrompt: string;
    procedure SetModel(const AValue: string);
    procedure SetMaxTokens(const AValue: Integer);
    procedure SetSystemPrompt(const AValue: string);

    property Model       : string  read GetModel        write SetModel;
    property MaxTokens   : Integer read GetMaxTokens    write SetMaxTokens;
    property SystemPrompt: string  read GetSystemPrompt write SetSystemPrompt;
  end;

implementation

end.
