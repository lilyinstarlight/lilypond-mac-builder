BUILDDIR=${CURDIR}/build
SOURCEDIR=${CURDIR}/source
EXTRA_FILES=${CURDIR}/extra-files
DISTDIR=${CURDIR}/dist
LILYPAD_BRANCH=mac-64-bit
LILYPAD_ARCHIVE=https://github.com/marnen/lilypad/archive/${LILYPAD_BRANCH}.tar.gz# at least until we get https://github.com/gperciva/lilypad/pull/12 merged
MACPORTS_ROOT=${HOME}/lilypond-bundle# TODO: need to put this in SOURCEDIR
VENV=venv
APP_BUNDLE=${BUILDDIR}/LilyPond.app
RESOURCES=${APP_BUNDLE}/Contents/Resources
OLD_BUNDLE=${HOME}/32-bit-app/LilyPond.app
OLD_RESOURCES=${OLD_BUNDLE}/Contents/Resources

LILYPOND_VERSION=2.19.83# TODO: we should be able to get this from the source
TIMESTAMP=$(shell date -j "+%Y%m%d%H%M%S")

default: lilypond-all

clean:
	rm -rf ${BUILDDIR} ${SOURCEDIR}

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
	    dylibbundler -cd -of -b -x "$$l" -d "${RESOURCES}/lib/" -p "@executable_path/.. 	/lib/";\
	  fi;\
	done

copy-binaries: ${RESOURCES}/bin ${RESOURCES}/libexec ${RESOURCES}/share

copy-support-files: ${RESOURCES}/etc ${RESOURCES}/license

${RESOURCES}/bin: ${APP_BUNDLE} ${MACPORTS_ROOT}/bin/lilypond
	mkdir -p "${RESOURCES}/bin" &&\
	for file in $$(cat "${EXTRA_FILES}/bin"); do \
	  cp -av "${MACPORTS_ROOT}/bin/$${file}" "${RESOURCES}/bin/$${file}";\
	done &&\
	cp -av "${EXTRA_FILES}/lilypond" "${RESOURCES}/bin" &&\
	mv -v "${RESOURCES}/bin/gsc" "${RESOURCES}/bin/gs" &&\
	for file in ${RESOURCES}/bin/guile18*; do mv -v "$$file" "$${file/guile18/guile}"; done

${RESOURCES}/libexec: ${APP_BUNDLE} ${MACPORTS_ROOT}/bin/lilypond
	mkdir -p "${RESOURCES}/libexec" &&\
	cp -av "${MACPORTS_ROOT}/libexec/lilypond-bin" "${RESOURCES}/libexec"

${RESOURCES}/share: ${APP_BUNDLE} ${MACPORTS_ROOT}/share/lilypond
	mkdir -p "${RESOURCES}/share" &&\
	xargs -I% <"${EXTRA_FILES}/share" cp -av "${MACPORTS_ROOT}/share/%" "${RESOURCES}/share/%"

${RESOURCES}/etc: ${APP_BUNDLE}
	mkdir -p "${RESOURCES}/etc" &&\
	cp -av "${OLD_RESOURCES}/etc/" "${RESOURCES}/etc" &&\
	cp -av "${EXTRA_FILES}/gs.reloc" "${RESOURCES}/etc/relocate"

${RESOURCES}/license: ${APP_BUNDLE}
	mkdir -p "${RESOURCES}/license" &&\
	cp -av "${OLD_RESOURCES}/license/" "${RESOURCES}/license"

copy-guile-libraries: ${APP_BUNDLE} ${MACPORTS_ROOT}/bin/lilypond
	mkdir -p "${RESOURCES}/lib" &&\
	cp -av "${MACPORTS_ROOT}/lib/guile18" "${RESOURCES}/lib" &&\
	cp -av ${MACPORTS_ROOT}/lib/libguile* "${RESOURCES}/lib"

${APP_BUNDLE}: | lilypad-venv
	cd "${SOURCEDIR}/lilypad/macosx" &&\
	source "${VENV}/bin/activate" &&\
	MACOSX_DEPLOYMENT_TARGET=10.5 python ./setup.py --verbose py2app --icon=lilypond.icns --dist-dir "${BUILDDIR}"

lilypad-venv: ${SOURCEDIR}/lilypad/macosx/${VENV}

${SOURCEDIR}/lilypad/macosx/${VENV}: ${SOURCEDIR}/lilypad
	cd "${SOURCEDIR}/lilypad/macosx" && virtualenv "${VENV}"

${SOURCEDIR}/lilypad: | ${SOURCEDIR}
	cd "${SOURCEDIR}" &&\
	curl -L "${LILYPAD_ARCHIVE}" | tar xvz &&\
	rm -rf lilypad &&\
	mv "lilypad-${LILYPAD_BRANCH}" lilypad

${SOURCEDIR}:
	mkdir -p "${SOURCEDIR}"

${MACPORTS_ROOT}/bin/lilypond:
	cd "${MACPORTS_ROOT}" && bin/port install lilypond-devel

.PHONY: default clean lilypond-all copy-binaries copy-guile-libraries copy-support-files bundle-dylibs lilypad-venv
