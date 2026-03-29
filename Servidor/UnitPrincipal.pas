unit UnitPrincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.JSON;

type
  TFrmPrincipal = class(TForm)
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FrmPrincipal: TFrmPrincipal;

implementation

{$R *.dfm}

uses Horse,
     Horse.Jhonson,
     Horse.CORS,
     Dm.Geral;

procedure ProcessarPrompt(Req: THorseRequest;
                          Res: THorseResponse; Next: TProc);
var
  dm: Tdm;
  prompt: string;
begin
  dm := Tdm.Create(nil);
  try
    try
      prompt := Req.Body<TJsonObject>.GetValue<string>('prompt');

      Res.Send<TJSONObject>(dm.ProcessarPrompt(prompt));

    except on ex:exception do
      Res.Send(ex.Message).Status(500);
    end;

  finally
    dm.Free;
  end;
end;

procedure TFrmPrincipal.FormShow(Sender: TObject);
begin
  THorse.Use(Jhonson());
  THorse.Use(CORS);

  THorse.post('/prompts', ProcessarPrompt);

  THorse.Listen(3001);
end;

end.
