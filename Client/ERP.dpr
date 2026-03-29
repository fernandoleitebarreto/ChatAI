program ERP;

uses
  System.StartUpCopy,
  FMX.Forms,
  UnitIA in 'UnitIA.pas' {FrmIA},
  uLoading in 'Utils\uLoading.pas',
  UnitMain in 'UnitMain.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmIA, FrmIA);
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
