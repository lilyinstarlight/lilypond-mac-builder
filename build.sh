#!/usr/bin/env bash

BUILD_PATH=${PWD}/build
EXTRA_FILES=${PWD}/extra-files
LILYPAD_PATH=${BUILD_PATH}/lilypad
LILYPAD_REPO=git@github.com:marnen/lilypad.git # at least until we get https://github.com/gperciva/lilypad/pull/12 merged
LILYPAD_BRANCH=mac-64-bit # ditto
LILYPAD_VENV=venv

function warn {
  echo >&2 $*
}

warn 'Getting LilyPad source...'
mkdir -p "$BUILD_PATH"
cd "$BUILD_PATH"
if [ ! -d "${LILYPAD_PATH}/.git" ]; then
  git clone "$LILYPAD_REPO" "$LILYPAD_PATH"
fi
cd "$LILYPAD_PATH"
git checkout "$LILYPAD_BRANCH"
git pull

warn 'Building LilyPad shell...'
cd "${LILYPAD_PATH}/macosx"

warn 'Activating venv...'
if [ ! -d "$LILYPAD_VENV" ]; then
  virtualenv "$LILYPAD_VENV"
fi
source "${LILYPAD_VENV}/bin/activate"

warn 'Generating .app bundle...'
MACOSX_DEPLOYMENT_TARGET=10.5 python ./setup.py --verbose py2app --icon=lilypond.icns

warn 'Copying LilyPond files into bundle...'
MACPORTS_ROOT=~/lilypond-bundle
APP_BUNDLE=${LILYPAD_PATH}/macosx/dist/LilyPond.app
RESOURCES=${APP_BUNDLE}/Contents/Resources

for dir in bin share; do
  mkdir ${RESOURCES}/${dir}
  xargs -I% <"${EXTRA_FILES}/${dir}" cp -av "${MACPORTS_ROOT}/${dir}/%" "${RESOURCES}/${dir}/%"
done

cp -av "${EXTRA_FILES}/lilypond" "${RESOURCES}/bin"
mv -v "${RESOURCES}/bin/gsc" "${RESOURCES}/bin/gs"

mkdir "${RESOURCES}/libexec"
cp -av "${MACPORTS_ROOT}/libexec/lilypond-bin" "${RESOURCES}/libexec"
for file in ${RESOURCES}/bin/guile18*; do mv -v "$file" "${file/guile18/guile}"; done
# TODO: not sure what to do about gapplication

export OLD_BUNDLE=~/32-bit-app/LilyPond.app
export OLD_RESOURCES=${OLD_BUNDLE}/Contents/Resources
for dir in etc license; do cp -av ${OLD_RESOURCES}/${dir} ${RESOURCES}/${dir}; done

# extra config for Ghostscript
cp -av ${EXTRA_FILES}/gs.reloc "${RESOURCES}/etc/relocate"

warn 'Bundling dylibs...'
mkdir ${RESOURCES}/lib
cp -av ${MACPORTS_ROOT}/lib/guile18 ${RESOURCES}/lib
cp -av ${MACPORTS_ROOT}/lib/libguile* ${RESOURCES}/lib

for dir in $(find "${MACPORTS_ROOT}/lib" -type d -maxdepth 1); do
  export DYLD_LIBRARY_PATH="${dir}:${DYLD_LIBRARY_PATH}"
done

for dir in lib bin libexec; do
  for l in $(find ${RESOURCES}/${dir}); do
    dylibbundler -cd -of -b -x $l -d ${RESOURCES}/lib/ -p @executable_path/../lib/
  done
done

warn 'Finding any dylibs we missed...'
# for some reason some of these need an extra pass; maybe a bug in dylibbundler?
for l in $(find ${RESOURCES}/lib); do
  if [ -n "$(otool -L "$l" | grep "${MACPORTS_ROOT}")" ]; then
     dylibbundler -cd -of -b -x $l -d ${RESOURCES}/lib/ -p @executable_path/../lib/
  fi
done

warn 'Done!'
