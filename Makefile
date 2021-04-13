BUILDDIR=${CURDIR}/build
SOURCEDIR=${CURDIR}/source
PATCHES=${CURDIR}/patches
EXTRA_FILES=${CURDIR}/extra-files
DISTDIR=${CURDIR}/dist

LILYPAD_BRANCH=master
LILYPAD_ARCHIVE=https://github.com/gperciva/lilypad/archive/${LILYPAD_BRANCH}.tar.bz2
LILYPAD_PATCH=${PATCHES}/lilypad-python3.patch

MACPORTS_ROOT=/opt/local

LILYPOND_GIT=https://git.savannah.gnu.org/git/lilypond.git
LILYPOND_VERSION=2.22.0
LILYPOND_BRANCH=release/${LILYPOND_VERSION}-1

VENV=venv

APP_BUNDLE=${BUILDDIR}/LilyPond.app
RESOURCES=${APP_BUNDLE}/Contents/Resources

PATH := ${MACPORTS_ROOT}/bin:${MACPORTS_ROOT}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
SHELL := env PATH="${PATH}" "${SHELL}"

PRIVILEGED := sudo

COPY := cp -av
MKDIR_P := mkdir -p
MOVE := mv -v
PORT := ${PRIVILEGED} "${MACPORTS_ROOT}/bin/port"
LN_S := ${PRIVILEGED} ln -s
RM_RF := rm -rf
ENV_PYTHON := /usr/bin/env python3
bundle-dylib="${MACPORTS_ROOT}/bin/dylibbundler" -cd -of -b -x "$(1)" -d "${RESOURCES}/lib/" -p "@executable_path/../lib/"

TIMESTAMP=$(shell date -j "+%Y%m%d%H%M%S")
VERSION_AND_BUILD=${LILYPOND_VERSION}-build${TIMESTAMP}

default: lilypond-all

all-with-tar: lilypond-all tar

clean: buildclean
	${RM_RF} "${SOURCEDIR}"

buildclean:
	${RM_RF} "${BUILDDIR}"

tar: | ${DISTDIR}
	cd "${BUILDDIR}" &&\
	tar cvjf "${DISTDIR}/lilypond-${VERSION_AND_BUILD}.darwin-64.tar.bz2" LilyPond.app

lilypond-all: bundle-dylibs copy-support-files copy-welcome-file

bundle-dylibs: ${MACPORTS_ROOT}/bin/dylibbundler copy-binaries copy-guile-libraries
	for dir in $$(find "${MACPORTS_ROOT}/lib" -type d -maxdepth 1); do \
	  export DYLD_LIBRARY_PATH="$$dir:$${DYLD_LIBRARY_PATH}";\
	done &&\
	for dir in lib bin libexec; do \
	  for l in $$(find "${RESOURCES}/$${dir}"); do \
	    $(call bundle-dylib,$$l);\
	  done;\
	done &&\
	: "for some reason some of these need an extra pass; maybe a bug in dylibbundler?" &&\
	for l in $$(find "${RESOURCES}/lib"); do \
	  if [ -n "$$(otool -L "$$l" | grep "${MACPORTS_ROOT}")" ]; then \
	    $(call bundle-dylib,$$l);\
	  fi;\
	done

copy-welcome-file: ${RESOURCES}/share
	${COPY} "${RESOURCES}/share/lilypond/${LILYPOND_VERSION}/ly/Welcome-to-LilyPond-MacOS.ly" "${RESOURCES}"

copy-binaries: ${RESOURCES}/bin ${RESOURCES}/libexec/lilypond-bin ${RESOURCES}/share

copy-support-files: ${RESOURCES}/etc ${RESOURCES}/license

${RESOURCES}/libexec/lilypond-bin: ${APP_BUNDLE} ${RESOURCES}/bin
	${MKDIR_P} "${RESOURCES}/libexec" &&\
	${MOVE} "${RESOURCES}/bin/lilypond" "$@" &&\
	${COPY} "${EXTRA_FILES}/lilypond" "${RESOURCES}/bin"

${RESOURCES}/bin: ${APP_BUNDLE} ${BUILDDIR}/bin/lilypond
	${COPY} "${BUILDDIR}/bin" "$@" &&\
	: 'for file in $$(cat "${EXTRA_FILES}/bin"); do \' &&\
	for file in gsc; do \
	  ${COPY} "${MACPORTS_ROOT}/bin/$${file}" "${RESOURCES}/bin/$${file}";\
	done &&\
	: '${COPY} "${EXTRA_FILES}/lilypond" "${RESOURCES}/bin"' &&\
	${MOVE} "${RESOURCES}/bin/gsc" "${RESOURCES}/bin/gs" &&\
	: 'for file in ${RESOURCES}/bin/guile18*; do ${MOVE} "$$file" "$${file/guile18/guile}"; done'
	# TODO: get rid of : 'comment' lines!

${RESOURCES}/share: ${APP_BUNDLE} ${BUILDDIR}/share/lilypond
	${COPY} "${BUILDDIR}/share" "$@" &&\
	xargs -I% <"${EXTRA_FILES}/share" cp -anv "${MACPORTS_ROOT}/share/%" "${RESOURCES}/share/%" &&\
	cd "$@/lilypond" && ln -s "${LILYPOND_VERSION}" current &&\
	cd "$@/ghostscript" && ln -s "$$(ls | grep '^\d')" current

${RESOURCES}/etc: ${APP_BUNDLE}
	${MKDIR_P} "${RESOURCES}/etc" &&\
	${COPY} "${EXTRA_FILES}/etc/" "${RESOURCES}/etc"

${RESOURCES}/license: ${APP_BUNDLE}
	${MKDIR_P} "${RESOURCES}/license" &&\
	${COPY} "${EXTRA_FILES}/license/" "${RESOURCES}/license"

copy-guile-libraries: ${APP_BUNDLE} ${BUILDDIR}/bin/lilypond
	${MKDIR_P} "${RESOURCES}/lib" &&\
	${COPY} "${MACPORTS_ROOT}/lib/guile18" "${RESOURCES}/lib" &&\
	${COPY} "${MACPORTS_ROOT}/lib/libguile"* "${RESOURCES}/lib"

${BUILDDIR}/bin/lilypond: ${SOURCEDIR}/lilypond/configure ${SOURCEDIR}/lilypond/build ${MACPORTS_ROOT}/include/libguile.h | ${BUILDDIR} ${SOURCEDIR}/lilypond/build select-python3
	cd "${SOURCEDIR}/lilypond/build" &&\
	${PORT} install gcc_select gcc9 &&\
	${PORT} select --set gcc mp-gcc9 &&\
	${PORT} install pkgconfig flex bison texlive-fonts-recommended texlive-metapost fontforge t1utils dblatex urw-core35-fonts extractpdfmark &&\
	export CC="${MACPORTS_ROOT}/bin/gcc" &&\
	export CXX="${MACPORTS_ROOT}/bin/g++" &&\
	export CXXCPP="${MACPORTS_ROOT}/bin/g++ -E" &&\
	export LTDL_LIBRARY_PATH="${MACPORTS_ROOT}/lib" &&\
	export PKG_CONFIG="${MACPORTS_ROOT}/bin/pkg-config" &&\
	export GUILE_FLAVOR="guile-1.8" &&\
	../configure --with-flexlexer-dir="${MACPORTS_ROOT}/include" --with-texgyre-dir="${MACPORTS_ROOT}/share/texmf-texlive/fonts/opentype/public/tex-gyre/" --prefix="${BUILDDIR}" --disable-documentation &&\
	${MAKE} PYTHON="${ENV_PYTHON} -tt" TARGET_PYTHON="${ENV_PYTHON} -tt" && ${MAKE} install


${APP_BUNDLE}: | lilypad-venv
	cd "${SOURCEDIR}/lilypad/macosx" &&\
	source "${VENV}/bin/activate" &&\
	echo "${LILYPOND_VERSION}\c" >|VERSION &&\
	MACOSX_DEPLOYMENT_TARGET=10.5 python ./setup.py --verbose py2app --icon=lilypond.icns --dist-dir "${BUILDDIR}"

lilypad-venv: ${SOURCEDIR}/lilypad/macosx/${VENV}

${SOURCEDIR}/lilypad/macosx/${VENV}: ${SOURCEDIR}/lilypad select-python3
	cd "${SOURCEDIR}/lilypad/macosx" && virtualenv "${VENV}"

${SOURCEDIR}/lilypad: | ${SOURCEDIR}
	cd "${SOURCEDIR}" &&\
	curl -L "${LILYPAD_ARCHIVE}" | tar xvz &&\
	patch -p1 -d "lilypad-${LILYPAD_BRANCH}" <"${LILYPAD_PATCH}" &&\
	${RM_RF} lilypad &&\
	mv "lilypad-${LILYPAD_BRANCH}" lilypad

select-python3: ${MACPORTS_ROOT}/bin/python3.8 ${MACPORTS_ROOT}/bin/virtualenv-3.8
	${PORT} select --set python python38 && ${PORT} select --set virtualenv virtualenv38

${MACPORTS_ROOT}/bin/python3.8:
	${PORT} install python38

${MACPORTS_ROOT}/bin/virtualenv-3.8:
	${PORT} install py38-virtualenv

${MACPORTS_ROOT}/include/libguile.h: ${MACPORTS_ROOT}/include/libguile18.h
	${LN_S} "$<" "$@"

${MACPORTS_ROOT}/include/libguile18.h:
	${PORT} install guile18

${MACPORTS_ROOT}/bin/dylibbundler:
	${PORT} install dylibbundler

${SOURCEDIR}/lilypond/configure: | ${SOURCEDIR}/lilypond
	cd "$|" && ./autogen.sh --noconfigure

${SOURCEDIR}/lilypond: | ${SOURCEDIR}
	cd "${SOURCEDIR}" &&\
	if [ ! -d lilypond ]; then \
	  git clone "${LILYPOND_GIT}" lilypond;\
	fi &&\
	cd lilypond && git fetch origin && git checkout "${LILYPOND_BRANCH}"

${BUILDDIR} ${SOURCEDIR} ${SOURCEDIR}/lilypond/build ${DISTDIR}:
	${MKDIR_P} "$@"

.PHONY: default all-with-tar clean buildclean lilypond-all copy-binaries copy-guile-libraries copy-support-files copy-welcome-file bundle-dylibs lilypad-venv select-python3 tar
