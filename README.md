# tex2img
Perl script to convert each page of a tex file to an image: pdf, eps, svg, png

## Requirements:

### pdf image: 
(pdflatex) or (latex, dvipdf) or (latex, dvips, ps2pdf) or (xelatex)
pdfinfo, gs, pdfcrop

### png image: 
(latex, dvipng) or (pdflatex, pdfinfo, gs, pdfcrop, imagemagick)

### svg image: 
(latex, dvisvgm) or (pdflatex, pdfinfo, gs, pdfcrop, pdf2svg)

### eps image:
(latex, dvips, gs) or (pdflatex, pdfinfo, gs, pdfcrop, pdftops)

Also see:
https://github.com/asarkar2/tex2img2
