use Test;
BEGIN { plan tests => 3 }
use PDFLib;

my $pdf;
$pdf = PDFLib->new(filename => "test.pdf");

ok($pdf);

$pdf->start_page;

{
    my $bb = $pdf->new_bounding_box(
        x => 30, y => 800, w => 300, h => 800
    );

    $bb->set_value(leading => $bb->get_value("fontsize") + 2);

    $bb->print(<<'EOT');
This module is a port and enhancement of the AxKit presentation tool,
B<AxPoint>. It takes an XML description of a slideshow, and generates
a PDF. The resulting presentations are very nice to look at, possibly
rivalling PowerPoint, and almost certainly better than most other
freeware presentation tools on Unix/Linux.

EOT

    $bb->print_line("");
    $bb->print_line("");

    $bb->set_font(face => "Times", italic => 1);
    $bb->set_value(leading => $bb->get_value("fontsize") + 2);

    $bb->print(<<'EOT');
The presentations support slide transitions, PDF bookmarks, bullet
points, source code (fixed font) sections, images, colours, bold and
italics, hyperlinks, and transition effects for all the bullet
points, source, and image sections.

EOT

    $bb->print_line("");
    $bb->print_line("");
    
    $bb->set_color(rgb => [1,0,1]);

    $bb->print(<<'EOT');
Rather than describing the format in detail, it is far easier to
examine (and copy) the example in the testfiles directory in the
distribution. We have included that verbatim here in case you lost it
during the install
EOT

    $bb->finish;
}

$pdf->finish;

undef $pdf;

ok(-e "test.pdf");
ok(-M _ <= 0);

