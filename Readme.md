PaperShell — A Flexible LaTeX Article Environment
=================================================

PaperShell is a boilerplate environment for writing LaTeX articles using the
templates of many publishers (Springer, IEEE, ACM, AAAI, Elsevier, etc.) while
keeping a **single source document independent of the target style**.

The project provides:

- Up-to-date class and bibliography files for many publishers
- A Lua-based template system that generates the proper preamble automatically
- Direct compatibility with Overleaf
- A build process based on `latexmk`
- Scripts to export editor-ready sources
- Helper scripts for bibliography cleanup, diffs, and packaging

Compared to older versions, PaperShell no longer requires external scripts to
switch styles. This is now handled internally by LuaLaTeX.

Optional PHP scripts are still provided for maintenance tasks such as exporting
sources or updating bundled styles, but they are **not required for writing or
compiling a paper**.


Why this environment?
---------------------

If you have written many Computer Science papers, you have probably used several
different document classes:

- `aaai`
- `acmart`
- `easychair`
- `elsarticle`
- `eptcs`
- `IEEEtran`
- `lipics`
- `llncs`
- `sig-alternate`
- `svjour`
- `usenix`
- etc.

Each class defines its own syntax for:

- title
- authors
- affiliations
- abstract
- front matter

Switching from one class to another usually requires tedious rewriting.

PaperShell separates:


paper content
publisher style
preamble generation


so that the same document can be compiled with multiple styles.


What changed in the new version
-------------------------------

Previous versions of PaperShell used PHP scripts to generate the preamble.
The current version uses LuaLaTeX instead.

Advantages:

- Styles can be switched directly from Overleaf
- No external script is required for normal compilation
- The generated files are plain LaTeX
- Final sources can be compiled with pdfLaTeX
- Simpler build process (`latexmk` only)

LuaLaTeX is only required to generate the preamble.  
Once generated, the document is ordinary LaTeX.


Basic workflow
--------------

PaperShell generates the files


gen/preamble.inc.tex
gen/midamble.inc.tex
gen/postamble.inc.tex


automatically during compilation.

Your main document simply contains:


\input{gen/preamble.inc.tex}
\input{gen/midamble.inc.tex}

... paper content ...

\input{gen/postamble.inc.tex}


Changing the publisher only requires changing the configuration and recompiling.


Quick start
-----------

1. Clone or download PaperShell.

2. Edit the setup block in `settings.tex`:


\papershellsetup{
publisher = lncs,
title = {Applications of the Flux Capacitor},
authors = {Emmett Brown, Marty McFly},
year = 2026
}


3. Compile once with LuaLaTeX:


latexmk -lualatex paper.tex


4. Compile normally:


latexmk -pdf paper.tex


5. To switch style, change `publisher` and recompile with LuaLaTeX.


Overleaf usage
--------------

PaperShell works directly in Overleaf.

To switch style:

1. Change the publisher in the setup block
2. Compile once with LuaLaTeX
3. Compile again normally

After generation, the project can be compiled with pdfLaTeX,
which is useful for final submission to editors.


Exporting final sources
-----------------------

Editors often require a flat bundle of sources.

PaperShell can export a stand-alone version containing:

- one `.tex` file
- bibliography included
- all figures
- class files

The exported version does not require LuaLaTeX and can be compiled with:


pdflatex


This avoids problems with publisher build systems.

Helper scripts are provided for exporting and packaging sources.


Compilation
-----------

Use `latexmk`:


latexmk -pdf paper.tex


To regenerate style files:


latexmk -lualatex paper.tex


To clean:


latexmk -c


No Makefile is required.


Dependencies
------------

Required:

- LaTeX distribution (TeX Live / MikTeX)
- latexmk
- LuaLaTeX (for style generation)

Optional:

- PHP (for export / packaging / maintenance scripts)
- latexdiff (for diffing versions)
- aspell / textidote (spell checking)


Project structure
-----------------


paper.tex
settings.tex
tpl/
lua/
gen/
fig/
bib/


- `tpl/` — publisher templates
- `lua/` — template engine
- `gen/` — generated files (do not edit)
- `fig/` — figures
- `bib/` — bibliography


Philosophy
----------

PaperShell follows these principles:

- Write the paper once
- Switch publisher without rewriting the document
- Keep generated files plain LaTeX
- Make final sources editor-friendly
- Work with Overleaf
- Avoid external build tools when possible


Optional helper scripts
-----------------------

Some scripts are still written in PHP.  
They are optional and not required for normal use.

They provide:

- exporting a flat source bundle
- packaging files for submission
- updating bundled styles
- bibliography cleanup
- diffing two versions of a paper

These scripts can be used locally but are not needed when working in Overleaf.


About
-----

PaperShell is maintained by  
Sylvain Hallé  
Université du Québec à Chicoutimi  
Canada