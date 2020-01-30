# Prerequisites for building LilyPond

## MacPorts

### Required

LilyPond needs the following MacPorts packages in order to compile, according to its `configure` utility:

```
TeX Gyre fonts OTF (install the fc-list utility from FontConfig, or use --with-texgyre-dir) msgfmt mf-nowin mf mfw mfont mpost kpsewhich metapost CTAN package (texlive-metapost) guile-config (guile-devel, guile-dev or libguile-dev package) libguile (libguile-dev, guile-devel or guile-dev package). GUILE-with-rational-bugfix fontforge t1asm pkg-config gs makeinfo >= 4.11 (installed: 4.8) texi2html dblatex bibtex xelatex pdflatex pdfetex pdftex etex epsf.tex lh CTAN package (texlive-lang-cyrillic or texlive-texmf-fonts) pngtopnm convert
```

This distills to the following packages to be port installed (with their dependencies) and config options:

* texlive-fonts-recommended (`--with-texgyre-dir=${MACPORTS_ROOT}/share/texmf-texlive/fonts/opentype/public/tex-gyre/`)
* texlive-metapost
* guile18 (which needs to be symlinked: `ln -s ${MACPORTS_ROOT}/include/libguile18.h ${MACPORTS_ROOT}/include/libguile.h`, and set env: `GUILE="${MACPORTS_ROOT}/bin/guile18" GUILE_CONFIG="${MACPORTS_ROOT}/bin/guile18-config" GUILE_TOOLS="${MACPORTS_ROOT}/bin/guile18-tools"`)
* fontforge
* texi2html
* t1utils
* dblatex
* texlive-lang-cyrillic

and for optional dependencies:
* urw-core35-fonts
* extractpdfmark

...as well as the following for dev tools:

* gcc9 (requires `port -f deactivate libunwind-headers` to build; `port select --set gcc mp-gcc9; CC="${MACPORTS_ROOT}/bin/gcc"; CXX="${MACPORTS_ROOT}/bin/g++"` to use)
* python27 (`port select --set python python27`)
* py27-virtualenv (`port select --set virtualenv virtualenv27`)
* dylibbundler
