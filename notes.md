# Build notes for LilyPad

I'm mostly following the build process in the README, but with Python 2.7.

## Pip

First we need pip. I'm following the instructions at http://johnlaudun.org/20150512-installing-and-setting-pip-with-macports/ and using the py27-pip MacPorts package.

`sudo port install py27-pip`

For some reason this is reinstalling python27; perhaps there was an upgrade to the MacPorts package...

```
sudo port select --set python python27
sudo port select --set pip pip27
```

Now we have pip working.

## Virtualenv

I'm installing virtualenv so that we don't have to mess with our Python global setup. Looks like it's available through MacPorts.

```
sudo port install py27-virtualenv
sudo port select --set virtualenv virtualenv27
```

Now we can set up a virtualenv:
`virtualenv venv`

And activate it:
`source venv/bin/activate`

## Get pyobjc

For the moment, setup.py requires pyobjc==2.3.1, which isn't in PyPI. The README advises getting it from SVN (!):
`svn co http://svn.red-bean.com/pyobjc/tags/pyobjc-2.3.1/`

But pip now has the ability to install a package from a repo, and Pyobjc now has a Mercurial repo:
`pip install 'hg+https://bitbucket.org/ronaldoussoren/pyobjc@pyobjc-2.3.1#egg=pyobjc'`

This required installing Mercurial (which I did with the MacPorts `mercurial` package, but any method should work).

Unfortunately, it still didn't work because pip install expects a setup.py file in the module that wasn't actually there. So I'm reluctantly going with the method in the README, modified as follows for the current Python installation and current sed regex syntax:

```
svn co http://svn.red-bean.com/pyobjc/tags/pyobjc-2.3.1/
cd pyobjc-2.3.1
sed -E -i .bak -e 's*(/usr/bin/)?python2.5*python*' 02-develop-all.sh
./02-develop-all.sh # detached while this was in progress: compilation takes forever, or maybe it just hung
cd pyobjc
python setup.py develop
```

...except that that didn't work: pyobjc 2.3.1 hung on compilation (`testFunctions (PyObjCTest.test_abaddressbookc.TestABAddressBookC) ...`). So I'm trying the latest version.  That worked, but created an app bundle that (on Mojave) gives an uninformative "LilyPond error" when opened.  Following the advice at https://stackoverflow.com/questions/53524071/py2app-app-not-launching-just-asks-if-i-want-to-terminate-the-app-or-open-consol led me to see that I was getting a BadPrototypeError on many methods. Since those methods are only called from Python, not Obj-C, https://github.com/robertklep/quotefixformac/issues/75 suggests that annotating them as @objc.python_method might be useful.

That did indeed work, and I committed that code. So really all I needed to do was `MACOSX_DEPLOYMENT_TARGET=10.5 python setup.py --verbose  py2app --icon=lilypond.icns`, although it might help to do it outside the venv...

## Installing LilyPond binaries into the bundle

There appears to be no automated way to figure out which Lilypond binaries are supposed to be in the bundle; even the README file just suggests copying them from an existing bundle.  So I'm looking at the existing app bundle to find a list. More info is at https://gist.github.com/marnen/137b056d95b1c8400af8f823dced54f0.

Basically, within Contents/Resources, bin, etc, license, share, var, and possibly site.py need to be copied. There are also a bunch of files in lib that need to be copied, but I suspect dylibbundler will do that.

I'm putting a list of filenames to copy into extra-files; paths are relative to Contents/Resources. Then we'll have to figure out how to get these into the bundle.

### bin

Most of these should be able to be copied from the MacPorts installation directory where I built Lilypond. Then we'll have to use `file` to figure out which ones are wrapper scripts (for example, MacPorts `lilypond` is a wrapper script for `libexec/lilypond-bin`, whereas the bundle expects the real binary). The downloaded bundle is in ~/32-bit-app so we can compare.

Some of the binaries come from the fondu port, which I had to install separately (`port install fondu`).

Once I installed Fondu and copied the MacPorts binaries over, here's what I used to run the diff on filetypes:
`diff -y --suppress-common-lines <(xargs <extra-files/bin echo 'cd ~/32-bit-app/LilyPond.app/Contents/Resources/bin && file' | sh) <(xargs <extra-files/bin echo 'cd dist/LilyPond.app/Contents/Resources/bin && file' | sh)`

The significant parts of the diff (that is, removing lines where the difference is meaningless) are as follows:
```diff
gapplication:           Mach-O executable i386              |    gapplication:           cannot open `gapplication' (No such f
glib-genmarshal:        Mach-O executable i386              |    glib-genmarshal:        a /usr/bin/python script text executa
gs:                     Mach-O executable i386              |    gs:                     broken symbolic link to gsc
guile:                  Mach-O executable i386              |    guile:                  cannot open `guile' (No such file or
guile-snarf:            POSIX shell script text executable    |    guile-snarf:            cannot open `guile-snarf' (No such fi
guile-tools:            POSIX shell script text executable    |    guile-tools:            cannot open `guile-tools' (No such fi
lilypond:               Mach-O executable i386              |    lilypond:               POSIX shell script text executable
```

So:
* gs is a symlink to gsc. We could either copy gsc as is or rename it so that no symlink is necessary.
* lilypond is a wrapper script around ~/lilypond-bundle/libexec/lilypond-bin. It just sets some environment variables, so we were just replacing it with the bin itself. However, we need those environment variables set, so we need to keep the script. I tried `@executable_path`, but that won't work in a Unix script, so I'm using a solution based on https://stackoverflow.com/a/18443300.
* gapplication doesn't exist and I'm not sure where we get it from.
* glib-genmarshal is a Python script rather than a native executable, but *seems* to be complete in itself. I hope.
* guile* is guile18* because of our MacPorts installation. We can copy them in with the new names.

These modifications are reflected in the script below.

### etc and license

These are all text files, so we should just be able to copy them over from the official bundle for now. I'd like to find an authoritative source for them, though.

### share

All text files and some .pyc. The .pyc are for Python 2.4, and we're using 2.7, but they should be automatically rebuilt as necessary, so I think we can just copy them over.

However, it looks like the naming of the files (at least as relates to Guile, which MacPorts calls guile18) isn't quite right, so we'll need to take the same approach we did with bin: list all the stuff in the bundle and copy it in from MacPorts.

### var

Empty except for cache directories. We may need to create it, but probably not even that.

### lib

Mostly dylibs, which can be populated by using https://github.com/auriamg/macdylibbundler to move all the executables' dependencies in here. I'm installing 0.4.4 through MacPorts.

But also, there seem to be some necessary Guile libraries that don't get copied that way (perhaps because Scheme is interpreted, not compiled and linked), so we have to move those in manually. Except that we can't seem to get those to get picked up, except possibly by setting environment variables, and that is suboptimal since we want to be able to call the LilyPond binary without going through the GUI app if necessary...but it turns out that LilyPond sets `INSTALLER_PREFIX` to its own directory, so that works. The remaining problem with finding them: according to https://lists.gnu.org/archive/html/bug-guile/2010-02/msg00000.html, it seems like they might need an .so extension.

It seems that @executable_path refers to the path of whichever executable is linking to the library, not necessarily the .app bundle's main file.

### Script to populate files

The build.sh script now contains a script incorporating these research notes (including the extra configuration for Ghostscript below).

## Ghostscript configuration

The above instructions produce a working app bundle, but LilyPond still won't run properly (at least for PDF output) because Ghostscript isn't properly configured:

```
Relocation file: /Users/marnen/Downloads/LilyPond.app/Contents/Resources/bin/../libexec/../etc/relocate//gs.reloc
warning: no such directory: /Users/marnen/Downloads/LilyPond.app/Contents/Resources/bin/../libexec/../share/ghostscript/9.21/fonts for GS_FONTPATH
warning: no such directory: /Users/marnen/Downloads/LilyPond.app/Contents/Resources/bin/../libexec/../share/gs/fonts for GS_FONTPATH
warning: no such directory: /Users/marnen/Downloads/LilyPond.app/Contents/Resources/bin/../libexec/../share/ghostscript/9.21/Resource for GS_LIB
warning: no such directory: /Users/marnen/Downloads/LilyPond.app/Contents/Resources/bin/../libexec/../share/ghostscript/9.21/Resource/Init for GS_LIB
```

It looks like what's going on is that we built this bundle with GS 9.50, so the path names are a bit different. So we just need to replace the gs.reloc file.

## TODO

Going forward we should probably use pipenv and a Pipfile to manage the dependencies.
