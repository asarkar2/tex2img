#!/usr/bin/perl

use warnings ;
use strict ;
no vars ;
no subs ;
use File::Basename ;
use File::Which ;
use File::Spec ;
use File::Copy ;

our($scriptname,$author,$version);
$scriptname = basename($0) ;
$author = "Anjishnu Sarkar" ;
$version = "0.15" ;
my $texfile ;
my $overwrite = 'FALSE' ;
my $rtn ;

my $latexmk = 'latexmk' ;
my @ltxmk_opts = ('-src-specials', '-silent', '-interaction=nonstopmode', 
    '-shell-escape') ;     
my $ltxmkcmp = '-pdf' ;

my $pdflatex = 'pdflatex' ;
my $latex    = 'latex' ;
my $xelatex  = 'xelatex' ;

my $dvipdf  = 'dvipdf' ;
my $dvips   = 'dvips' ;
my $dvipng  = 'dvipng' ;
my $dvisvgm = 'dvisvgm' ;
my $pdf2svg = 'pdf2svg' ;
my $convert = 'convert' ;

my $pdfinfo = 'pdfinfo' ;
my $pdfcrop  = 'pdfcrop' ;
my $ps2pdf   = 'ps2pdf' ;
my $pdftops   = 'pdftops' ;
my $gs = 'gs' ;
   $gs = "gswin32c" if $^O eq 'MSWin32';
my @gsopts = ('-sDEVICE=pdfwrite','-dNOPAUSE', '-dQUIET', '-dBATCH') ;

my @softwares = ( $pdflatex, $latex, $xelatex, $dvipdf, $dvips, $dvipng, 
    $dvisvgm, $pdf2svg, $convert, $pdfinfo, $pdfcrop, $ps2pdf, $gs, $pdftops) ;

# Required for pdfcrop
my $margins = 5 ; 

# Convert configurations
my $density = '600' ;
my $flatten = '' ;

my %latex_switch = (
    'pdf'     => 'TRUE'  ,
    'dvipdf'  => 'FALSE' ,
    'pdfps'   => 'FALSE' ,
    'xelatex' => 'FALSE' ,
    'pdfpng'  => 'FALSE' ,
    'dvipng'  => 'FALSE' ,
    'pdfsvg'  => 'FALSE' ,
    'dvisvg'  => 'FALSE' ,
    'pdfeps'  => 'FALSE' ,
    'dvieps'  => 'FALSE' ,
) ;

my $devnull = File::Spec->devnull();

# Fix bounding box 
sub fixbb{

    my ($gs_, $ineps, $outeps, $mrgns) = @_ ;

    my @bbox_options = ("-dNOPAUSE", "-dBATCH", "-q", "-sDEVICE=bbox") ;
    my @cmd_result = qx($gs_ @bbox_options $ineps 2>&1) ;
    my $bbname = '%%BoundingBox:' ;
    my $hiresbbname = '%%HiResBoundingBox:' ;
    my ($llx, $lly, $urx, $ury) ; 

    my @bbox = grep(/$bbname/,@cmd_result);
    $bbox[0] =~ s/$bbname *// ;

    # Grab the bounding box
    if ( $bbox[0] =~ /^\s*([\-\.\d]+)\s+([\-\.\d]+)\s+([\-\.\d]+)\s+([\-\.\d]+)\s*$/){
        ($llx, $lly, $urx, $ury) = ($1, $2, $3, $4) ;
    } else {
        die("Couldn't parse the bounding box for \"$ineps\".\n") ;
    }

    my ($nllx, $nlly, $nurx, $nury) = ( $llx-$mrgns, $lly-$mrgns, $urx+$mrgns, 
                                        $ury+$mrgns ) ;

    open(INEPS, "<$ineps") or die "$!";
    open(OUTEPS, ">$outeps") or die "$!";

    while(<INEPS>){
        if (/$bbname/) {

            s/$bbname *// ;

            print OUTEPS "$bbname $nllx $nlly $nurx $nury\n" ;

        } elsif (/$hiresbbname/) {
            # print "Omitting Hi resolution\n" ;
            next ;

        } elsif (/%!PS-Adobe-2.0/) {
            print OUTEPS '%!PS-Adobe-2.0 EPSF-2.0', "\n" ;

        } else {
            print OUTEPS $_ ;
        }        
    }
    
    close(OUTEPS) ;
    close(INEPS) ;

}

## Helptext
sub helptext{
    
    my ($sname, $au, $ver, $mrgns, @soft) = @_ ;

    my ( $pdflatex_, $latex_, $xelatex_, $dvipdf_, $dvips_, $dvipng_, 
    $dvisvgm_, $pdf2svg_, $convert_, $pdfinfo_, $pdfcrop_, $ps2pdf_, $gs_,
    $pdftops_) = @soft ;
    
    print
    "Converts each page of a tex file to a figure with cropped borders.\n",
    "Usage: $sname [options] file.tex\n\n",
    "Author: $au\n",
    "Version: $ver\n",
    "Options:\n",
    "-h|--help          Show this help and exit.\n",
    "-t                 Creates a template tex file.\n",
    "-f                 Option to overwrite the template tex file if it exists",
    "\n",
    "-pdf               Generate pdf by $pdflatex_. Default.\n",
    "-dvipdf            Generate pdf by $dvipdf_.\n",
    "-pspdf             Generate pdf by $dvips_ & $ps2pdf_.\n",
    "-xelatex           Generate pdf by $xelatex_.\n",
    "-png|-pdfpng       Generate png by $pdflatex_ and $convert_.\n",
    "-dvipng            Generate png by $dvipng_.\n",
    "-svg|-pdfsvg       Generate svg by using $pdflatex_ and $pdf2svg_\n",
    "-dvisvg            Generate svg by $dvisvgm_.\n",
    "-eps|-pdfeps       Generate eps by $pdftops_.\n",
    "-dvieps            Generate eps by $dvips_.\n",
    "-m <margins>       Specify the margins. Default $mrgns.\n",
    "                   Not valid for '-dvipng', and '-dvisvg' options.\n",    
    "-flatten           White background for png file created using -pdfpng\n",
    "\n",
    "Softwares required are:\n",
    "pdf    : ($pdflatex_)|($latex_, $dvipdf_)|($latex_, $dvips_, $ps2pdf_)",
            "|($xelatex_)\n",
    "         $pdfinfo_, $gs_, $pdfcrop_\n",
    "pdfpng : $pdflatex_, $pdfinfo_, $gs_, $pdfcrop_, $convert_\n", 
    "dvipng : $latex_, $dvipng_\n",
    "pdfsvg : $pdflatex_, $pdfinfo_, $gs_, $pdfcrop_, $pdf2svg_\n",
    "dvisvg : $latex_, $dvisvgm_\n",
    "pdfeps : $latex_, $pdfinfo_, $gs_, $pdfcrop_, $pdftops_\n",
    "dvieps : $latex_, $dvips_, $gs_\n",
    ;
}

## Radio switches
sub radio_switch_on {
    my ($turnon,%allsw) = @_ ;
    foreach my $sw (keys %allsw) {
        $allsw{$sw} = 'FALSE' if ( $allsw{$sw} eq 'TRUE' ) ;
    }
    $allsw{$turnon} = 'TRUE' ;
    return %allsw ;
}

## Create template file
sub mktemplate{

    my ($tfile, $ovrwrt) = @_ ;

    die("No template file defined.\n") if (!$tfile) ;

    # Check if file already exists
    if (-e $tfile) {
        if  ($ovrwrt eq 'TRUE') {
            # If overwrite then remove it.
            unlink($tfile) ;
        } else {
            # If not overwrite, then stop
            print("File \"$tfile\" exists. To overwrite, use the flag '-f'. ",
                "Aborting.\n") ;
            exit 1 ;
        }
    }

    open(TFILE,">$tfile") or die "$!" ;
    print TFILE
    '\documentclass[12pt]{article}',"\n",
    '\usepackage[usenames,dvipsnames]{color}',"\n",
    '\usepackage{amsmath,amssymb}',"\n\n",
    '\pagestyle{empty}',"\n",
    '\boldmath',"\n",
    '\begin{document}',"\n",
    '% \color{Red}',"\n\n",
    '\begin{displaymath}',"\n\n",
    '\end{displaymath}',"\n\n",
    '% \newpage',"\n%\n",
    '% \begin{displaymath}',"\n%\n",
    '% \end{displaymath}',"\n\n",
    '\end{document}',"",
    ;
    close(TFILE) or die "$!" ;

    exit 0 ;
}

## Check for required dependencies
sub check_dep{
    my @depends = @_ ; 
    foreach my $software (@depends){
        my $exe_path = which($software);
        die ("\"$software\" not found.\n") if ( !defined($exe_path) ) ;
    }
}

## To get number of pages of a pdf file
sub numpdfpgs{

    my ($pinfo, $pfile) = @_ ;
    my @allpdfinfo = `$pinfo $pfile` ;
    my @pageinfo = grep(/Pages:/,@allpdfinfo) ;
    my (undef,$pagenums) = split(/:/,join('',@pageinfo)) ;
    chomp($pagenums) ;
    $pagenums =~ s/^[ \t]*// ;
    $pagenums =~ s/[ \t]$// ;
    return $pagenums ;
}

# Clean subroutine
sub clean {

    my $fname = shift ;

    print "Removing junk files.\n" ;
    my @extns = ("aux","log","dvi","ps","pdf","fls","fdb_latexmk",
        "synctex.gz","xdv") ;
    foreach my $ext (@extns){
        unlink("$fname.$ext");
    }
}

## Parse arguments
while ( $_ = $ARGV[0] ){
    if ((/^-h$/) || (/^-help$/) || (/^--help$/)) {
        &helptext($scriptname, $author, $version, $margins, @softwares) ;
        exit 0 ;

    } elsif ( /\.tex$/ ){
        $texfile = $_ ;

    } elsif  ( /^-pdf$/ )  {
        %latex_switch = &radio_switch_on('pdf',%latex_switch) ;
        $ltxmkcmp = '-pdf' ;
        &check_dep($pdflatex) ;

    } elsif  ( /^-dvipdf$/ )  {
        %latex_switch = &radio_switch_on('dvipdf',%latex_switch) ;
        $ltxmkcmp = '-pdfdvi' ;
        &check_dep($latex,$dvipdf) ;

    } elsif  ( /^-pspdf$/ )  {
        %latex_switch = &radio_switch_on('pdfps',%latex_switch) ;
        $ltxmkcmp = '-pdfps' ;
        &check_dep($latex,$dvips,$ps2pdf) ;

    } elsif  ( /^-xelatex$/ )  {
        %latex_switch = &radio_switch_on('xelatex',%latex_switch) ;
        $ltxmkcmp = '-xelatex' ;
        &check_dep($xelatex) ;

    } elsif (( /^-png$/ ) || (/^-pdfpng$/)) {
        %latex_switch = &radio_switch_on('pdfpng',%latex_switch) ;
        $ltxmkcmp = '-pdf' ;
        &check_dep($pdflatex,$convert) ;

    } elsif (/^-dvipng$/) {
        %latex_switch = &radio_switch_on('dvipng',%latex_switch) ;
        $ltxmkcmp = '' ;
        &check_dep($latex,$dvipng) ;

    } elsif ((/^-svg$/) || ( /^-pdfsvg$/ )) {
        %latex_switch = &radio_switch_on('pdfsvg',%latex_switch) ;
        $ltxmkcmp = '-pdf' ;
        &check_dep($pdflatex,$pdf2svg) ;

    } elsif (/^-dvisvg$/) {
        %latex_switch = &radio_switch_on('dvisvg',%latex_switch) ;
        $ltxmkcmp = '' ;
        &check_dep($latex,$dvisvgm) ;

    } elsif ( ( /^-eps$/ ) || (/^-pdfeps$/) ) {
        %latex_switch = &radio_switch_on('pdfeps',%latex_switch) ;
        $ltxmkcmp = '-pdf' ;
        &check_dep($latex,$pdftops) ;

    } elsif (/^-dvieps$/) {
        %latex_switch = &radio_switch_on('dvieps',%latex_switch) ;
        $ltxmkcmp = '' ;
        &check_dep($latex,$dvips) ;

    } elsif (/^-m$/) {
        $margins = $ARGV[1] ;
        shift ;

    } elsif (/^-flatten$/) {
        $flatten = "-flatten" ;

    } elsif (/^-f$/) {
        $overwrite = "TRUE" ;

    } elsif (/^-t$/) {
        my $templatefile = $ARGV[1] ;
        &mktemplate($templatefile,$overwrite) ;
        shift ;

    } else {
        die("Unspecified option.\n");

    }
    shift ;
}

# Check dependencies
&check_dep($latexmk) ;

## Check whether tex file has been supplied or not
die("No tex file supplied.\n") if (!$texfile) ;

## Check existence of input tex file
die("File \"$texfile\" not found.\n") if (! -e $texfile ) ;

## Get filename
my $filename = basename($texfile,".tex") ;
my $pdffile = $filename . ".pdf" ;
my $dvifile = $filename . ".dvi" ;
my $psfile  = $filename . ".ps" ;

# my $pdffilefmt = $filename . '-%03d.pdf' ;
my $pngfilefmt = $filename . '-%03d.png' ;
my $svgfilefmt = '%f-%3p.svg' ;
    $svgfilefmt = '%%f-%%3p.svg' if  $^O eq 'MSWin32' ;

## Run pdflatex / latex / xelatex 
print "Running $latexmk $ltxmkcmp\n" ;
$rtn = system("$latexmk $ltxmkcmp @ltxmk_opts $texfile > $devnull") ;
die("Problem in running \'$latexmk $ltxmkcmp\'.\n") if ($rtn != 0) ;

## Create separate image files
if ( ( $latex_switch{'pdf'}     eq 'TRUE' ) || 
     ( $latex_switch{'dvipdf'}  eq 'TRUE' ) || 
     ( $latex_switch{'pdfps'}   eq 'TRUE' ) || 
     ( $latex_switch{'xelatex'} eq 'TRUE' ) ||
     ( $latex_switch{'pdfpng'} eq 'TRUE' )  ||
     ( $latex_switch{'pdfsvg'} eq 'TRUE' )  ||
     ( $latex_switch{'pdfeps'} eq 'TRUE' )  
    ) {
    
    &check_dep($pdfinfo,$gs,$pdfcrop) ;

    my $pages = &numpdfpgs($pdfinfo,$pdffile) ;

    ## Convert each page to pdf image file
    for ( my $i = 1 ; $i <= $pages ; $i++ ){

        my $pgn = sprintf('%03d',$i) ;

        ## Filenames of each n-th page of the pdf file
        my $ithpdf = $filename . "-" . $pgn . ".pdf" ;

        print "Running $gs to create $ithpdf...\n" ;
        $rtn = system("$gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dFirstPage=$i -dLastPage=$i -sOutputFile=$ithpdf $pdffile") ;
        die("Problem in running $gs.\n") if ($rtn != 0) ;

        print "Running $pdfcrop on $ithpdf...\n" ;
        $rtn = system("$pdfcrop --margins $margins $ithpdf $ithpdf > $devnull") ;
        die("Problem in running $pdfcrop.\n") if ($rtn != 0) ;

        ## If png is required from the pdf file
        if  ( $latex_switch{'pdfpng'} eq 'TRUE' ) {
            
            ## Filenames of each n-th page of the pdf file
            my $ithpng = $filename . "-" . $pgn . ".png" ;
            
            print "Running $convert on $ithpdf...\n" ;
            $rtn = system("$convert -units PixelsPerInch -density $density $flatten +profile 'icc' \"$ithpdf\" \"$ithpng\" >$devnull");

            die("Problem in running $convert on $ithpdf.\n") if ($rtn != 0) ;
        }

        ## If svg is required from the pdf file
        if  ( $latex_switch{'pdfsvg'} eq 'TRUE' ) {
            
            ## Filenames of each n-th page of the pdf file
            my $ithsvg = $filename . "-" . $pgn . ".svg" ;

            print "Running $pdf2svg on $ithpdf...\n" ;
            $rtn = system("$pdf2svg $ithpdf $ithsvg") ;

            die("Problem in running $pdf2svg on $ithpdf.\n") if ($rtn != 0) ;
        }

        ## If eps is required from the pdf file
        if  ( $latex_switch{'pdfeps'} eq 'TRUE' ) {

            ## Filenames of each n-th page of the eps file
            my $itheps = $filename . "-" . $pgn . ".eps" ;

            print "Running $pdftops to create $itheps...\n" ;
            $rtn = system("$pdftops -level3 -eps $ithpdf $itheps") ;
            die("Problem in running $pdftops on $ithpdf.\n") if ($rtn != 0) ;
        }

    }

} elsif ( $latex_switch{'dvipng'} eq 'TRUE' ) {
 
    ## Create separate png files
    print "Running $dvipng...\n" ;
    $rtn = system("$dvipng -D $density -T tight -bg Transparent $dvifile -o $pngfilefmt") ;
    die("Problem in running $dvipng.\n") if ($rtn != 0) ;

} elsif ( $latex_switch{'dvisvg'} eq 'TRUE' ) {

    ## Create separate svg files
    my $scale = 5 ;
    my $page = '-' ;
    print "Running $dvisvgm...\n" ;
    $rtn = system("$dvisvgm -c $scale --no-fonts -o $svgfilefmt --exact --page=$page $dvifile 2> $devnull") ;
    die("Problem in running $dvisvgm.\n") if ($rtn != 0) ;

} elsif ( $latex_switch{'dvieps'} eq 'TRUE' ) {
 
    ## Create separate eps files
    print "Running $dvips...\n" ;
    $rtn = system("$dvips -q -i -E $dvifile") ;
    die("Problem in running $dvips.\n") if ($rtn != 0) ;

    ## Rename the eps files in the correct format
    my @epsfiles = glob("$filename.[0-9][0-9][0-9]") ;
    my $i = 0 ;
    foreach my $oldeps (@epsfiles){
        $i = $i + 1 ;
        my $pgn = sprintf('%03d',$i) ;
        my $neweps = $filename . '-' . $pgn . '.eps' ;
   
        # Fix bounding box 
        print("Fixing the bounding box of \"$neweps\"...\n") ;
        &fixbb($gs,$oldeps,$neweps,$margins) ;        
        unlink($oldeps) ;
    }
}

# Delete junk files
&clean($filename) ;

