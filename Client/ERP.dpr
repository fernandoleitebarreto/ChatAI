program ERP;

uses
  System.StartUpCopy,
  FMX.Forms,
  UnitAI in 'UnitAI.pas' {FrmAI},
  uLoading in 'Utils\uLoading.pas',
  UnitMain in 'UnitMain.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmAI, FrmAI);
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
