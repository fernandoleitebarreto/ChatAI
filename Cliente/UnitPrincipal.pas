unit UnitPrincipal;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects;

type
  TForm1 = class(TForm)
    Rectangle1: TRectangle;
    Image1: TImage;
    img_ia: TImage;
    procedure img_iaClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses UnitIA;

procedure TForm1.img_iaClick(Sender: TObject);
begin
  FrmIA.show;
end;

end.
