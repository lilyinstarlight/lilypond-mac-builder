BUILDDIR=${CURDIR}/build
SOURCEDIR=${CURDIR}/source
EXTRA_FILES=${CURDIR}/extra-files
DISTDIR=${CURDIR}/dist
LILYPAD_BRANCH=mac-64-bit
LILYPAD_ARCHIVE=https://github.com/marnen/lilypad/archive/${LILYPAD_BRANCH}.tar.gz# at least until we get https://github.com/gperciva/lilypad/pull/12 merged
MACPORTS_ROOT=${CURDIR}/macports
LILYPOND_GIT=https://git.savannah.gnu.org/git/lilypond.git
LILYPOND_BRANCH=stable/test
VENV=venv
APP_BUNDLE=${BUILDDIR}/LilyPond.app
RESOURCES=${APP_BUNDLE}/Contents/Resources
OLD_BUNDLE=${HOME}/32-bit-app/LilyPond.app
OLD_RESOURCES=${OLD_BUNDLE}/Contents/Resources

PATH := ${MACPORTS_ROOT}/bin:${MACPORTS_ROOT}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
SHELL := env PATH="${PATH}" "${SHELL}"

COPY := cp -av
MKDIR_P := mkdir -p
MOVE := mv -v
PORT := "${MACPORTS_ROOT}/bin/port"
RM_RF := rm -rf

LILYPOND_VERSION=2.19.83# TODO: we should be able to get this from the source
TIMESTAMP=$(shell date -j "+%Y%m%d%H%M%S")

default: lilypond-all

clean:
	${RM_RF} ${BUILDDIR} ${SOURCEDIR}

buildclean:
	${RM_RF} ${BUILDDIR}

tar: | ${DISTDIR}
	cd "${BUILDDIR}" &&\
	tar cvzf "${DISTDIR}/lilypond-${LILYPOND_VERSION}.build${TIMESTAMP}-darwin-64.tar.gz" LilyPond.app

lilypond-all: bundle-dylibs copy-support-files

bundle-dylibs: copy-binaries copy-guile-libraries
	for dir in $$(find "${MACPORTS_ROOT}/lib" -type d -maxdepth 1); do \
	  export DYLD_LIBRARY_PATH="$$dir:$${DYLD_LIBRARY_PATH}";\
	done &&\
	for dir in lib bin libexec; do \
	  for l in $$(find "${RESOURCES}/$${dir}"); do \
	    dylibbundler -cd -of -b -x "$$l" -d "${RESOURCES}/lib/" -p "@executable_path/../lib/";\
	  done;\
	done &&\
	: "for some reason some of these need an extra pass; maybe a bug in dylibbundler?" &&\
	for l in $$(find "${RESOURCES}/lib"); do \
	  if [ -n "$$(otool -L "$$l" | grep "${MACPORTS_ROOT}")" ]; then \
	    dylibbundler -cd -of -b -x "$$l" -d "${RESOURCES}/lib/" -p "@executable_path/../lib/";\
	  fi;\
	done

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
	xargs -I% <"${EXTRA_FILES}/share" cp -anv "${MACPORTS_ROOT}/share/%" "${RESOURCES}/share/%"

${RESOURCES}/etc: ${APP_BUNDLE}
	${MKDIR_P} "${RESOURCES}/etc" &&\
	${COPY} "${OLD_RESOURCES}/etc/" "${RESOURCES}/etc" &&\
	${COPY} "${EXTRA_FILES}/gs.reloc" "${RESOURCES}/etc/relocate"

${RESOURCES}/license: ${APP_BUNDLE}
	${MKDIR_P} "${RESOURCES}/license" &&\
	${COPY} "${OLD_RESOURCES}/license/" "${RESOURCES}/license"

copy-guile-libraries: ${APP_BUNDLE} ${BUILDDIR}/bin/lilypond
	${MKDIR_P} "${RESOURCES}/lib" &&\
	${COPY} "${MACPORTS_ROOT}/lib/guile18" "${RESOURCES}/lib" &&\
	${COPY} "${MACPORTS_ROOT}/lib/libguile"* "${RESOURCES}/lib"

${BUILDDIR}/bin/lilypond: ${SOURCEDIR}/lilypond/configure ${SOURCEDIR}/lilypond/build ${MACPORTS_ROOT}/include/libguile.h | ${BUILDDIR} ${SOURCEDIR}/lilypond/build
	cd "${SOURCEDIR}/lilypond/build" &&\
	${PORT} select --set gcc mp-gcc9 &&\
	export CC="${MACPORTS_ROOT}/bin/gcc" &&\
	export CXX="${MACPORTS_ROOT}/bin/g++" &&\
	export LTDL_LIBRARY_PATH="${MACPORTS_ROOT}/lib" &&\
	export GUILE="${MACPORTS_ROOT}/bin/guile18" &&\
	export GUILE_CONFIG="${MACPORTS_ROOT}/bin/guile18-config" &&\
	export GUILE_TOOLS="${MACPORTS_ROOT}/bin/guile18-tools" &&\
	../configure --with-texgyre-dir="${MACPORTS_ROOT}/share/texmf-texlive/fonts/opentype/public/tex-gyre/" --prefix="${BUILDDIR}" &&\
	${MAKE} && ${MAKE} install


${APP_BUNDLE}: | lilypad-venv
	cd "${SOURCEDIR}/lilypad/macosx" &&\
	source "${VENV}/bin/activate" &&\
	MACOSX_DEPLOYMENT_TARGET=10.5 python ./setup.py --verbose py2app --icon=lilypond.icns --dist-dir "${BUILDDIR}"

lilypad-venv: ${SOURCEDIR}/lilypad/macosx/${VENV}

${SOURCEDIR}/lilypad/macosx/${VENV}: ${SOURCEDIR}/lilypad select-python
	cd "${SOURCEDIR}/lilypad/macosx" && virtualenv "${VENV}"

${SOURCEDIR}/lilypad: | ${SOURCEDIR}
	cd "${SOURCEDIR}" &&\
	curl -L "${LILYPAD_ARCHIVE}" | tar xvz &&\
	${RM_RF} lilypad &&\
	mv "lilypad-${LILYPAD_BRANCH}" lilypad

select-python: ${MACPORTS_ROOT}/bin/python2.7 ${MACPORTS_ROOT}/bin/virtualenv-2.7
	${PORT} select --set python python27 && ${PORT} select --set virtualenv virtualenv27

${MACPORTS_ROOT}/bin/python2.7:
	${PORT} install python27

${MACPORTS_ROOT}/bin/virtualenv-2.7:
	${PORT} install py27-virtualenv

${MACPORTS_ROOT}/include/libguile.h: ${MACPORTS_ROOT}/include/libguile18.h
	ln -s "$<" "$@"

${MACPORTS_ROOT}/include/libguile18.h:
	${PORT} install guile18

${SOURCEDIR}/lilypond/configure: | ${SOURCEDIR}/lilypond
	cd "$|" && ./autogen.sh --noconfigure

${SOURCEDIR}/lilypond: | ${SOURCEDIR}
	cd "${SOURCEDIR}" &&\
	if [ ! -d lilypond ]; then \
	  git clone "${LILYPOND_GIT}" lilypond;\
	fi &&\
	cd lilypond && git checkout "${LILYPOND_BRANCH}" && git pull

${BUILDDIR} ${SOURCEDIR} ${SOURCEDIR}/lilypond/build ${DISTDIR}:
	${MKDIR_P} "$@"

.PHONY: default clean buildclean lilypond-all copy-binaries copy-guile-libraries copy-support-files bundle-dylibs lilypad-venv select-python tar
