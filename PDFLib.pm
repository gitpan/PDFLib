# $Id: PDFLib.pm,v 1.3 2001/05/15 07:42:07 matt Exp $

package PDFLib;

use strict;
use vars qw/$VERSION/;

use pdflib_pl 4.0;

$VERSION = '0.01';

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
            $pdf->info($info, $params{$info});
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
    warn("PDF_delete\n");
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
    
    if (_equals_font($pdf->{current_font}, %params)) {
        # warn("Only setting size of $pdf->{current_font}{face} to $params{size}\n");
        # warn("PDF_setfont(\$p, $pdf->{current_font}->{handle}, $params{size});\n");
        return PDF_setfont($pdf->_pdf, $pdf->{current_font}->{handle}, $params{size});
    }
    
    my $fontstring = ucfirst($params{face});
    $fontstring .= '-' if $params{bold} || $params{italic};
    $fontstring .= 'Bold' if $params{bold};
    $fontstring .= 'Italic' if $params{italic};
    
    my %font = %params;
    delete $font{size};
    
    $pdf->{current_font} = \%font;
    
    # warn("PDF_findfont(\$p, '$fontstring', 'host', 0);\n");
    my $font = PDF_findfont($pdf->_pdf, $fontstring, $params{encoding} || 'host', $params{embed} || 0);
    # warn("font: $font\n");
    
    $pdf->{current_font}->{handle} = $font;
    
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

=head1 AUTHOR

AxKit.com Ltd,

Matt Sergeant, matt@axkit.com

=head1 LICENSE

This is free software. You may distribute it under the same terms as Perl itself.

=cut
