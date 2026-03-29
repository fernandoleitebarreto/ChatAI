program ERP;

uses
  System.StartUpCopy,
  FMX.Forms,
  UnitPrincipal in 'UnitPrincipal.pas' {Form1},
  UnitIA in 'UnitIA.pas' {FrmIA},
  uLoading in 'Utils\uLoading.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TFrmIA, FrmIA);
  Application.Run;
end.
