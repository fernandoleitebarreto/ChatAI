unit UnitMain;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  System.JSON;

type
  TFrmMain = class(TForm)
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FrmMain: TFrmMain;

implementation

{$R *.dfm}

uses
  Horse,
  Horse.Jhonson,
  Horse.CORS,
  Dm.Main;

// ---------------------------------------------------------------------------
// POST /prompts
// Body  : { "prompt": "..." }
// Returns the TJSONObject produced by TDm.ProcessPrompt
// ---------------------------------------------------------------------------
procedure HandlePrompt(AReq : THorseRequest;
                       ARes : THorseResponse;
                       ANext: TProc);
var
  LDm    : TDm;
  LPrompt: string;
begin
  LDm := TDm.Create(nil);
  try
    try
      LPrompt := AReq.Body<TJSONObject>.GetValue<string>('prompt');
      ARes.Send<TJSONObject>(LDm.ProcessPrompt(LPrompt));
    except
      on E: Exception do
        ARes.Send(E.Message).Status(500);
    end;
  finally
    LDm.Free;
  end;
end;

procedure TFrmMain.FormShow(Sender: TObject);
begin
  THorse.Use(Jhonson());
  THorse.Use(CORS);

  THorse.Post('/prompts', HandlePrompt);

  THorse.Listen(3001);
end;

end.
