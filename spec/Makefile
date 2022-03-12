#=======================================================================
# Makefile for generating latex documents
#-----------------------------------------------------------------------
#
# This is a simple makefile for generating latex documents. It will
# run bibtex, generate eps from xfig figures, and make pdfs. The
# makefile supports builds in non-source directories: just make a
# build directory, copy the makefile there, and change the srcdir
# variable accordingly.
#
# Note that the makefile assumes that the default dvips/ps2pdfwr
# commands "do the right thing" for fonts in pdfs. This is true on
# Athena/Linux and Fedora Core but is not true for older redhat installs ...
#
# At a minimum you should just change the main variable to be
# the basename of your toplevel tex file. If you use a bibliography
# then you should set the bibfile variable to be the name of your
# .bib file (assumed to be in the source directory).
#

srcdir  = .

main = fpga_project
srcs = $(wildcard *.tex)
figs = $(wildcard figs/*)
bibs =

#=======================================================================
# You shouldn't need to change anything below this
#=======================================================================

default : pdf

#------------------------------------------------------------
# PDF

output_pdf = $(main).pdf
pdf : $(output_pdf)
.PHONY: pdf

$(output_pdf) : $(srcs) $(figs) $(bibs)
	texfot pdflatex -shell-escape $(main)
ifneq ($(strip $(bibs)),)
	texfot bibtex $(main)
	texfot pdflatex -shell-escape $(main)
endif
	texfot pdflatex -shell-escape $(main)

junk += $(output_pdf) *.aux *.log *.toc *.out _minted-fpga_project

#------------------------------------------------------------
# Other Targets

clean :
	rm -rf $(junk) *~ \#*
