use Test;
BEGIN {plan tests => 3}

use PDFLib;
#my $pdf = PDFLib->new(filename => "test.pdf");
my $pdf = PDFLib->new();
ok($pdf);

$pdf->start_page;

$pdf->set_font(face => "Helvetica", size => 18.0);
ok(1);

$pdf->print_at("Foo", x => 40, y => 600);
$pdf->print_line("Food");
$pdf->set_font(face => "Times-Roman", size => 18.0);
$pdf->print_line("Bar");

ok($pdf->get_buffer);

