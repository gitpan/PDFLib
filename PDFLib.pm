# $Id: PDFLib.pm,v 1.5 2001/06/06 12:08:15 matt Exp $

package PDFLib;

use strict;
use vars qw/$VERSION/;

use pdflib_pl 4.0;

$VERSION = '0.03';

my %stacklevel = (
        object => 0,
        document => 1,
        page => 2,
        template => 2,
        pattern => 2,
        path => 3,
        );

my %pdfs;

sub new {
    my $class = shift;
    my %params = @_; # params: filename, papersize, creator, author, title
    
    my $pdf = bless {pdf => PDF_new(), %params}, $class;
    
    $pdfs{$pdf + 0} = $pdf->{pdf};
    
    $pdf->filename($pdf->{filename} || "");
    for my $info (qw(creator author title)) {
        if (exists $params{$info}) {
            $pdf->info(ucfirst($info), $params{$info});
        }
    }
    
    $pdf->{images} = [];
    $pdf->{bookmarks} = [];
    $pdf->{stacklevel} = 'document';
    
    return $pdf;
}

sub DESTROY {
    my $pdf = shift;
    if (my $pdf_h = delete $pdfs{$pdf + 0}) {
        if ($pdf->stacklevel >= $stacklevel{'page'}) {
            PDF_end_page($pdf_h);
        }
        PDF_close($pdf_h) unless $pdf->{closed};
        PDF_delete($pdf_h);
    }
}

sub finish {
    my $pdf = shift;
    return if $pdf->{closed};
    if ($pdf->stacklevel >= $stacklevel{'page'}) {
        PDF_end_page($pdf->{pdf});
        $pdf->{stacklevel} = 'document';
    }
#    $pdf->end_page;
#    warn("closing file\n");
    PDF_close($pdf->{pdf});
    $pdf->{stacklevel} = 'object';
    $pdf->{closed}++;
}

sub delete {
    my $pdf = shift;
#    warn("PDF_delete\n");
    PDF_delete($pdf->{pdf});
}

sub get_buffer {
    my $pdf = shift;
    my $obj = $pdf->{pdf};
    $pdf->finish();
    return PDF_get_buffer($obj);
}

sub _pdf {
    my $pdf = shift;
    return $pdf->{pdf};
}

sub filename {
    my $pdf = shift;
    
    my $oldname = $pdf->{filename};
    if (@_) {
        $pdf->{filename} = shift @_;
        
        if (PDF_open_file($pdf->_pdf, $pdf->{filename}) == -1) {
            die "PDF_open_file(\"$pdf->{filename}\") failed";
        }
    }
    return $oldname;
}

sub info {
    my $pdf = shift;
    my $key = shift;
    
    my $old = $pdf->{info}{$key};
    if (@_) {
        $pdf->{info}{$key} = shift(@_);
        PDF_set_info($pdf->_pdf, $key, $pdf->{info}{$key});
    }
    return $old;
}

sub papersize {
    my $pdf = shift;
    
    my $old = $pdf->{papersize};
    if (@_) {
        $pdf->{papersize} = shift @_;
    }
    return $old;
}

sub orientation {
    my $pdf = shift;
    
    my $old = $pdf->{orientation};
    if (@_) {
        $pdf->{orientation} = shift @_;
    }
    return $old;
}

sub stacklevel {
    my $pdf = shift;
    
    return $stacklevel{$pdf->{stacklevel}};
}

sub start_page {
    my $pdf = shift;
    my %params = @_;
    if ($pdf->stacklevel >= $stacklevel{page}) {
        $pdf->end_page;
    }
    $params{orientation} ||= $pdf->orientation;
    $params{papersize} ||= $pdf->papersize;
    # warn("setting papersize to $params{papersize}, orientation to $params{orientation}\n");
    $pdf->{current_page} = PDFLib::Page->new($pdf->_pdf, %params);
    $pdf->set_font(face => 'Helvetica', size => 12.0);
    $pdf->{stacklevel} = 'page';
}

sub end_page {
    my $pdf = shift;
    return unless $pdf->stacklevel >= $stacklevel{page};
    $pdf->{stacklevel} = 'document';
    delete $pdf->{current_page};
    PDF_end_page($pdf->{pdf});
}

sub _equals_font {
    my ($old, %new) = @_;
    
    local $^W;
    foreach my $key (qw(face bold italic)) {
        return if ($old->{$key} ne $new{$key});
    }
    return 1;
}

sub set_font {
    my $pdf = shift;
    my %params = @_; # expecting: face, size, bold, italic
    
    if (exists $pdf->{current_font} &&
                $pdf->{current_font}->{face} eq $params{face}) 
    {
        return PDF_setfont($pdf->_pdf, $pdf->{current_font}->{handle}, $params{size} || 12.0);
    }
    
    my $fontstring = ucfirst($params{face});
    
    # warn("PDF_findfont(\$p, '$fontstring', 'host', 0);\n");
    my $font = PDF_findfont($pdf->_pdf, 
                ucfirst($params{face}), 
                $params{encoding} || 'host', 
                $params{embed} || 0
                );
    # warn("font: $font\n");
    
    $pdf->{current_font}->{handle} = $font;
    $pdf->{current_font}->{face} = $params{face};
    
    # warn("font handle: $font (size: $params{size})\n");
    
    # warn("PDF_setfont(\$p, $font, $params{size});\n");
    PDF_setfont($pdf->_pdf, $font, $params{size} || 12.0);
}

sub set_text_pos {
    my $pdf = shift;
    
    $pdf->start_page() unless $pdf->stacklevel >= $stacklevel{'page'};
    
    my ($x, $y) = @_;
    
    PDF_set_text_pos($pdf->_pdf, $x, $y);
}

sub get_text_pos {
    my $pdf = shift;
    
    return $pdf->get_value("textx"), $pdf->get_value("texty");
}

sub print {
    my $pdf = shift;
    
    $pdf->start_page() unless $pdf->stacklevel >= $stacklevel{'page'};
    
    PDF_show($pdf->_pdf, $_[0]);
}

sub print_at {
    my $pdf = shift;
    my ($text, %params) = @_;
    
    $pdf->start_page() unless $pdf->stacklevel >= $stacklevel{'page'};
    
    PDF_show_xy($pdf->_pdf, $text, @params{qw(x y)});
}

sub print_boxed {
    my $pdf = shift;
    my ($text, %params) = @_;
    
    $pdf->start_page() unless $pdf->stacklevel >= $stacklevel{'page'};
    
    $params{mode} ||= 'left';
    $params{blind} ||= "";
    
    PDF_show_boxed($pdf->_pdf, $text, @params{qw(x y w h mode blind)});
#    PDF_rect($pdf->_pdf, @params{qw(x y w h)});
#    PDF_stroke($pdf->_pdf);
}

sub print_line {
    my $pdf = shift;
    
    $pdf->start_page() unless $pdf->stacklevel >= $stacklevel{'page'};
    
    PDF_continue_text($pdf->_pdf, $_[0]);
}

sub get_value {
    my $pdf = shift;
    my $key = shift;
    my $modifier = shift || 0;
    
    return PDF_get_value($pdf->_pdf, $key, $modifier);
}

sub set_value {
    my $pdf = shift;
    
    PDF_set_value($pdf->_pdf, $_[0], $_[1]);
}

sub get_parameter {
    my $pdf = shift;
    my $param = shift;
    my $modifier = shift || 0;
    
    return PDF_get_parameter($pdf->_pdf, $param, $modifier);
}

sub set_parameter {
    my $pdf = shift;
    
    PDF_set_parameter($pdf->_pdf, $_[0], $_[1]);
}

sub load_image {
    my $pdf = shift;
    die "Cannot load images unless at document level"
                if $pdf->stacklevel > $stacklevel{document};
    
    my %params = @_;
    
    my $img = PDFLib::Image->open(pdf => $pdf, %params);
    
    push @{$pdf->{images}}, $img;
    
    return $img;
}

sub add_image {
    my $pdf = shift;
    my %params = @_;
    
    $pdf->start_page() unless $pdf->stacklevel >= $stacklevel{'page'};
    
    PDF_place_image($pdf->_pdf, $params{img}->img, 
                $params{x}, 
                $params{y}, 
                $params{scale} || 1.0);
}

sub add_bookmark {
    my $pdf = shift;
    my %params = @_;
    
    $params{parent_of} ||= 0;
    $params{open} ||= 0;
    
    return PDF_add_bookmark($pdf->_pdf, $params{text}, $params{parent_of}, $params{open});
}

sub add_link {
    my $pdf = shift;
    
    my %params = @_;
    
    my $link = $params{link};
    my ($llx, $lly) = @params{'x', 'y'};
    my ($urx, $ury) = ($llx + $params{w}, $lly + $params{h});
    if ($link =~ /^(https?|ftp|mailto):/) {
        PDF_add_weblink($pdf->_pdf, $llx, $lly, $urx, $ury, $link);
    }
}

sub set_border_style {
    my $pdf = shift;
    my ($style, $width) = @_;
    
    PDF_set_border_style($pdf->_pdf, $style, $width);
}

package PDFLib::Page;

use pdflib_pl 4.0;

my %papersizes = (
        a0 => [2380, 3368],
        a1 => [1684, 2380],
        a2 => [1190, 1684],
        a3 => [842, 1190],
        a4 => [595, 842],
        a5 => [421, 595],
        a6 => [297, 421],
        b5 => [501, 709],
        letter => [612, 792],
        legal => [612, 1008],
        ledger => [1224, 792],
        11x17 => [792, 1224],
        slides => [612, 450],
        );

sub new {
    my $class = shift;
    my ($pdf, %params) = @_;
    
    $params{papersize} ||= 'a4';
    $params{orientation} ||= 'portrait';
    
    my ($x, $y) = @{$papersizes{$params{papersize}}};
    if ($params{orientation} eq 'landscape') {
#        warn("swapping aspect\n");
        ($x, $y) = ($y, $x); # swap around!
    }
    
#    warn("PDF_begin_page($x, $y)\n");
    PDF_begin_page($pdf, $x, $y);
    
    $params{pdf} = $pdf;
    
    return bless \%params, $class;
}

sub DESTROY {
    my $self = shift;
}

package PDFLib::Image;

use pdflib_pl 4.0;

sub open {
    my $class = shift;
    my %params = @_;
    
    PDF_set_parameter($params{pdf}->_pdf, "imagewarning", "true");
    
    my $image_handle = PDF_open_image_file(
                $params{pdf}->_pdf,
                $params{filetype},
                $params{filename},
                $params{stringparam} || "",
                $params{intparam} || 0,
                );
    
    if ($image_handle == -1) {
        PDF_set_parameter($params{pdf}->_pdf, "imagewarning", "true");
        die "Cannot open image file '$params{filename}'";
    }
    
    $params{handle} = $image_handle;
    return bless \%params, $class;
}

sub img {
    my $self = shift;
    return $self->{handle};
}

sub width {
    my $self = shift;
    return $self->{pdf}->get_value("imagewidth", $self->img);
}

sub height {
    my $self = shift;
    return $self->{pdf}->get_value("imageheight", $self->img);
}

sub close {
    my $self = shift;
    PDF_close_image(shift, $self->{handle});
}

1;
__END__

=head1 NAME

PDFLib - More OO interface to pdflib_pl.pm

=head1 SYNOPSIS

  use PDFLib;
  my $pdf = PDFLib->new("foo.pdf");

=head1 DESCRIPTION

A cleaner API than pdflib_pl.pm, which is a very low-level (non-OO) interface.

=head1 PDFLib API

=head2 new(...)

Construct a new PDF object. No parameters required.

Parameters are passed as name/value pairs (i.e. a hash):

=over 4

=item filename

A filename to save the PDF to. If not supplied the PDF will be generated in
memory.

=item papersize

The papersize can either be an array ref of [x, y], or can be a string 
containing one of the below listed paper sizes. This defaults to "a4".

=item creator

The creator of the document.

=item author

The author of the document

=item title

The title of the document

=item orientation

The orientation of the pages. This defaults to "portrait".

=back

Example:

  my $pdf = PDFLib->new(creator => "My PDF Program", 
        author => "Me",
        title => "Business Report");

=head2 finish

Let PDFLib know you are finished processing this PDF. This method should
not normally need to be called, as it is called automatically for you.

=head2 delete

Only call this if you are manually calling finish() also. It deletes the
used memory for this PDF.

=head2 get_buffer

If (and only if) you didn't supply a filename in the call to new(), then
get_buffer will return to you the PDF as a string. Very useful for generating
PDFs on the fly for a web server.

=head2 filename(...)

A getter and setter method for the PDF's filename. Pass in a filename as
a string to set a new filename. returns the old filename.

=head2 info(key => value)

A getter and setter method for the PDF info fields (such as Title, Creator,
Author, etc). A key is required. If you pass in a value it will set the
new value. Returns the old value.

=head2 papersize(...)

A getter and setter for the current paper size. An optional value that can
be an array ref of [x, y], or a string from the list of paper sizes below,
will set the current paper size. Returns the old/current paper size.

=head2 orientation(...)

A getter and setter for the current page orientation. All this really does
is swap the x and y values in the paper size if orientation == "landscape".
Returns the current/old orientation.

=head2 start_page(...)

Start a new page. If a page has already been started, this will call end_page()
automatically for you.

Options are passed in as name/value pairs, and are passed to PDFLib::Page->new()
below.

=head2 end_page

End the current page. It should not normally be necessary to call this.

=head2 set_font(...)

Set the current font being used. The parameters allowed are:

=over 4

=item face

The font face to use. Best to choose from one of the 14 builtin fonts:

  Courier
  Courier-Bold
  Courier-BoldOblique
  Courier-Oblique
  Helvetica
  Helvetica-Bold
  Helvetica-BoldOblique
  Helvetica-Oblique
  Symbol
  Times-Roman
  Times-Bold
  Times-BoldItalic
  Times-Italic
  ZapfDingbats

=item size

The font size in points. This defaults to 12.0

=item encoding

One of "host" (default), "builtin", "winansi", "ebcdic", or "macroman".

See the pdflib documentation for more details.

=item embed

If set to a true value, this will embed the font in the PDF file. This can
be useful if using fonts outside of the 14 listed above, but extra font
metrics information is required and you will need to read the pdflib
documentation for more information.

=back

=head2 set_text_pos(x, y)

Sets the current text output position.

=head2 get_text_pos

Returns the current text output position as a list (x, y).

=head2 print($text)

Prints the text passed as a parameter to the current page (and creates
a new page if there is no current page) at the current output position.

Note: this will B<not> wrap, and text can and will fall off the edge of
your page.

=head2 print_at($text, x => $x, y => $y)

Prints text at the given X and Y coordinates.

=head2 print_boxed($text, ...)

This is perhaps the most interesting output method as it allows you to define
a bounding box to put the text into, and PDFLib will wrap the text for you.

The parameters you can pass are:

=over 4

=item mode

One of "left", "right", "center", "justify" or "fulljustify".

=item blind

This parameter allows you to output invisible text. Useful for testing
whether the text will fit into your bounding box.

=item x and y

The X and Y positions (bottom left hand corner) of your bounding box.

=item w and h

The width and height of your bounding box.

=back

Returns zero, or the number of characters from your text that would not
fit into the box.

=head2 print_line($text)

Print the text at the current output position, with a carriage return
at the end.

=head2 get_value($key, [$modifier])

There are many values that you can retrieve from pdflib, all are covered
in the extensive documentation. This method is a wrapper for that.

=head2 set_value($key => $value)

PDFLib also allows you to set values. This method does just that. Note that
not all values that you can "get" allow you to also "set" that value. Read
the pdflib documentation for more information on values you can set.

=head2 get_parameter($param, [$modifier])

This is very similar to get_value above. No, I don't know why pdflib makes
this distinction, before you ask :-)

=head2 set_parameter($param => $value)

Same again. See the pdflib docs for which options are available.

=head2 load_image(...)

Load an image. Parameters available are:

=over 4

=item filetype

One of "png", "gif", "jpeg", or "tiff". Unfortunately PDFLib does not do
filetype sniffing, yet.

=item filename

The name of the image file to open.

=item stringparam and intparam

See the pdflib documentation for PDF_open_image for more details.

=back

This returns a PDFLib::Image object.

=head2 add_image(...)

Add an image to the current page (or creates a new page if necessary).

Options are passed as name/value pairs. Available options are:

=over 4

=item img

The PDFLib::Image object, returned from load_image() above.

=item x

The x coordinate

=item y

The y coordinate

=item scale

The scaling of the image. Note that only full scaling is possible, not
separate X and Y scaling. This defaults to 1.0.

=back

=head2 add_bookmark(...)

Adds a bookmark to the PDF file (normally displayed in a tree view on the left
hand side of the pages in Adobe acrobat reader). Takes the following parameters:

=over 4

=item text

The text of the bookmark

=item parent_of

The parent bookmark for generating hierarchies. This should be a value returned
from a previous call to add_bookmark, e.g.

  my $root_bm = $pdf->add_bookmark(text => "My Root Bookmark");
  $pdf->add_bookmark(text => "Child Bookmark", parent_of => $root_bm);

=item open

Whether this bookmark is expanded by default when the PDF is first opened.

=back

=head2 add_link(...)

Turns a square area of the page into a web link. Takes the following parameters:

=over 4

=item x, y, w, h

X and Y coordinates of the lower left hand side of the box, and width and
height of the box.

=item link

The actual link. Must start with one of "http:", "https:", "ftp:", or
"mailto:".

=back

=head2 set_border_style($style, $width)

The border in question here is a border around a link. Style must be one
of "solid" or "dashed". Note that links have a border around them by default,
so you need to unset that with:

  $pdf->set_border_style("solid", 0);

Unless you want all your links to have ugly boxes around them.

=head1 PDFLib::Image API

The following methods are available on the object returned from load_image
above.

=head2 width

Return the image's width in points.

=head2 height

Return the image's height in points.

=head1 Default Paper Sizes

The following paper sizes are available. Units are in "points". Any of these
can be rotated by providing an orientation of "landscape". Alternate paper sizes
can be used by passing an array ref of [x, y] to anything requiring a
papersize, but that generally shouldn't be necessary.

=over 4

=item a0

2380 x 3368

=item a1

1684 x 2380

=item a2

1190 x 1684

=item a3

842 x 1190

=item a4

595 x 842

=item a5

421 x 595

=item a6

297 x 421

=item b5

501 x 709

=item letter

612 x 792

=item legal

612 x 1008

=item ledger

1224 x 792

=item 11x17

792 x 1224

=item slides

612 x 450

=back

=head1 TODO

Lots more of the pdflib API needs to be added and tested here. Notably the
support for other types of attachments, and support for all of the
graphics primatives.

=head1 AUTHOR

AxKit.com Ltd,

Matt Sergeant, matt@axkit.com

=head1 LICENSE

This is free software. You may distribute it under the same terms as Perl itself.

=cut
