#!/bin/bash
set -e

NAME="PythonSkeleton"
IDENTIFIER="com.example.PythonSkeleton"
OSXVERSION=10.9
APPLICATION=application

BASE=`pwd`
PREFIX="$BASE/dist"
BREW=/usr/local

brew update

function brew_install {
    pkg=$1
    brew list | grep -q $pkg || brew install $pkg
    brew outdated $pkg || brew upgrade $pkg
}

brew_install openssl
brew_install sqlite
brew_install xz
brew_install readline

# add lxml dependencies
brew_install libxml2
brew_install libxslt

# Python
CPPFLAGS="-I$BREW/opt/openssl/include/openssl"
LDFLAGS=""
for pkg in openssl sqlite readline xz; do
    CPPFLAGS="$CPPFLAGS -I$BREW/opt/$pkg/include"
    LDFLAGS="$LDFLAGS -L$BREW/opt/$pkg/lib"
done
export CPPFLAGS
export LDFLAGS

version=3.5.2
url="https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz"
name=`basename $url .tar.xz`
tar=`basename $url`

test -e $tar || curl -O $url
test -e $name || tar xf $tar
cd $name
./configure MACOSX_DEPLOYMENT_TARGET=$OSXVERSION --prefix="$PREFIX"
make -j8
make altinstall

unset CPPFLAGS
unset LDFLAGS

ln -sf pip3.5 "$PREFIX/bin/pip"
ln -sf pip3.5 "$PREFIX/bin/pip3"
ln -sf python3.5 "$PREFIX/bin/python3"


PATH="$PREFIX/bin:$PATH"
cd "$BASE"
test -e requirements.txt && pip3.5 install -r requirements.txt

chmod -R +rw "$PREFIX/lib"
# make self contained
for lib in \
    opt/libxml2/lib/libxml2.2.dylib \
    opt/libxslt/lib/libexslt.0.dylib \
    opt/libxslt/lib/libxslt.1.dylib \
    opt/openssl/lib/libcrypto.1.0.0.dylib \
    opt/openssl/lib/libssl.1.0.0.dylib \
    opt/readline/lib/libreadline.6.dylib \
    opt/sqlite/lib/libsqlite3.0.dylib \
    opt/xz/lib/liblzma.5.dylib \
; do
    target="$PREFIX/lib/`basename "$lib"`"
    rm -f "$target"
    cp -a "$BREW/$lib" "$target"
done
chmod -R +rw "$PREFIX/lib"
mkdir -p "$PREFIX/etc/openssl/certs"
cp /usr/local/etc/openssl/cert.pem "$PREFIX/etc/openssl"

# cleanup
rm -rf \
    "$PREFIX/lib/python3.5/test" \
    "$PREFIX/bin/openssl" \
    "$PREFIX/etc/openssl/man" \
    "$PREFIX/bin/c_rehash" \
    "$PREFIX/bin/2to3-3.5" \
    "$PREFIX/bin/easy_install-3.5" \
    "$PREFIX/bin/idle3.5" \
    "$PREFIX/bin/pyvenv-3.5" \
    "$PREFIX/bin/c_rehash" \
    "$PREFIX/bin/pydoc3.5"

for bin in $PREFIX/bin/pip3.5 $PREFIX/bin/python3.5m-config; do
    sed "s#$PREFIX/bin/python3.5#/usr/bin/env python3.5#g" "$bin" > "$bin.t"
    mv "$bin.t" "$bin"
    chmod +x "$bin"
done

find "$PREFIX" -d -name "__pycache__" -type d -exec rm -r "{}" \;
find "$PREFIX" -name "*.pyc" -exec rm "{}" \;
find "$PREFIX" -name "*.a" -exec rm -f "{}" \;

for plib in \
    $PREFIX/lib/python3.5/site-packages/lxml/etree.cpython-35m-darwin.so \
    $PREFIX/lib/python3.5/site-packages/lxml/objectify.cpython-35m-darwin.so \
    $PREFIX/lib/python3.5/lib-dynload/_hashlib.cpython-35m-darwin.so \
    $PREFIX/lib/python3.5/lib-dynload/_lzma.cpython-35m-darwin.so \
    $PREFIX/lib/python3.5/lib-dynload/_sqlite3.cpython-35m-darwin.so \
    $PREFIX/lib/python3.5/lib-dynload/_ssl.cpython-35m-darwin.so \
    $PREFIX/lib/python3.5/lib-dynload/readline.cpython-35m-darwin.so \
; do
    if [ -e "$plib" ]; then
        for lib in \
            $BREW/Cellar/libxslt/1.1.28_1/lib/libxslt.1.dylib \
            $BREW/Cellar/openssl/1.0.2d_1/lib/libcrypto.1.0.0.dylib \
            $BREW/opt/libxml2/lib/libxml2.2.dylib \
            $BREW/opt/libxslt/lib/libexslt.0.dylib \
            $BREW/opt/libxslt/lib/libxslt.1.dylib \
            $BREW/opt/openssl/lib/libcrypto.1.0.0.dylib \
            $BREW/opt/openssl/lib/libssl.1.0.0.dylib \
            $BREW/opt/readline/lib/libreadline.6.dylib \
            $BREW/opt/sqlite/lib/libsqlite3.0.dylib \
            $BREW/opt/xz/lib/liblzma.5.dylib \
            $PREFIX/lib/libcrypto.1.0.0.dylib \
            $PREFIX/lib/libexslt.0.dylib \
            $PREFIX/lib/liblzma.5.dylib \
            $PREFIX/lib/libreadline.6.dylib \
            $PREFIX/lib/libsqlite3.0.dylib \
            $PREFIX/lib/libssl.1.0.0.dylib \
            $PREFIX/lib/libxml2.2.dylib \
            $PREFIX/lib/libxslt.1.dylib \
            /usr/lib/libexslt.0.dylib \
            /usr/lib/libreadline.6.dylib \
            /usr/lib/libxml2.2.dylib \
            /usr/lib/libxslt.1.dylib \
        ; do
            name=`basename $lib`
            otool -L "$plib" | grep -q "$lib" && install_name_tool -change "$lib" "@executable_path/../lib/$name" "$plib"
        done
        otool -L "$plib"
    fi
done

mkdir -p "${NAME}.app/Contents/MacOS"
mv $PREFIX "${NAME}.app/Contents/Python"
cat > "$NAME.app/Contents/MacOS/$NAME" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
PREFIX="\$(dirname "\$(pwd)")/Python"
export SSL_CERT_FILE="\$PREFIX/etc/openssl/cert.pem"
export SSL_CERT_DIR="\$PREFIX/etc/openssl/certs"
"\$PREFIX/bin/python3.5" -m $APPLICATION
EOF
chmod +x "$NAME.app/Contents/MacOS/$NAME"

cat > "$NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildMachineOSBuild</key>
	<string>15C50</string>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
    <string>${NAME}</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
    <string>${IDENTIFIER}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
    <string>${NAME}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.8</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>DTPlatformBuild</key>
	<string>7C68</string>
	<key>DTPlatformVersion</key>
	<string>GM</string>
	<key>DTSDKBuild</key>
	<string>15C43</string>
	<key>DTSDKName</key>
	<string>macosx10.10</string>
	<key>DTXcode</key>
	<string>0720</string>
	<key>DTXcodeBuild</key>
	<string>7C68</string>
	<key>LSMinimumSystemVersion</key>
    <string>${OSXVERSION}</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>No Copyright</string>
	<key>NSMainNibFile</key>
	<string>MainMenu</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

test -e test.py && "${NAME}.app/Contents/Python/bin/python3.5" test.py

find "${NAME}.app" -d -name "__pycache__" -type d -exec rm -r "{}" \;
find "${NAME}.app" -name "*.pyc" -exec rm "{}" \;
