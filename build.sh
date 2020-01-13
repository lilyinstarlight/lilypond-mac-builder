#!/usr/bin/env bash

# from macosx directory
export MACPORTS_ROOT=~/lilypond-bundle
export APP_BUNDLE=dist/LilyPond.app
export RESOURCES=${APP_BUNDLE}/Contents/Resources

for dir in bin share; do
  mkdir ${RESOURCES}/${dir}
  xargs -I% <extra-files/${dir} cp -av ${MACPORTS_ROOT}/${dir}/% ${RESOURCES}/${dir}/%
done

cp -av extra-files/lilypond ${RESOURCES}/bin
mv -v ${RESOURCES}/bin/gsc ${RESOURCES}/bin/gs

mkdir ${RESOURCES}/libexec
cp -av ${MACPORTS_ROOT}/libexec/lilypond-bin ${RESOURCES}/libexec
for file in ${RESOURCES}/bin/guile18*; do mv -v $file ${file/guile18/guile}; done
# TODO: not sure what to do about gapplication

export OLD_BUNDLE=~/32-bit-app/LilyPond.app
export OLD_RESOURCES=${OLD_BUNDLE}/Contents/Resources
for dir in etc license; do cp -av ${OLD_RESOURCES}/${dir} ${RESOURCES}/${dir}; done

# extra config for Ghostscript
cp -av extra-files/gs.reloc "${RESOURCES}/etc/relocate"

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

# for some reason some of these need an extra pass; maybe a bug in dylibbundler?
for l in $(find ${RESOURCES}/lib); do
  if [ -n "$(otool -L "$l" | grep "${MACPORTS_ROOT}")" ]; then
     dylibbundler -cd -of -b -x $l -d ${RESOURCES}/lib/ -p @executable_path/../lib/
  fi
done
