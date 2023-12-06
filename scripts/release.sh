#!/usr/bin/env bash
set -euxo pipefail

git config --global user.name rtx-vm
git config --global user.email 123107610+rtx-vm@users.noreply.github.com

RTX_VERSION=$(cd rtx && ./scripts/get-version.sh)
RELEASE_DIR=releases
export RTX_VERSION RELEASE_DIR
rm -rf "${RELEASE_DIR:?}/$RTX_VERSION"
mkdir -p "$RELEASE_DIR/$RTX_VERSION"

targets=(
	x86_64-unknown-linux-gnu
	aarch64-unknown-linux-gnu
	arm-unknown-linux-gnueabihf
	armv7-unknown-linux-gnueabihf
	x86_64-apple-darwin
	aarch64-apple-darwin
)
for target in "${targets[@]}"; do
	cp "artifacts/tarball-$target/"*.tar.gz "$RELEASE_DIR/$RTX_VERSION"
	cp "artifacts/tarball-$target/"*.tar.xz "$RELEASE_DIR/$RTX_VERSION"
done

platforms=(
	linux-x64
	linux-arm64
	linux-armv6
	linux-armv7
	macos-x64
	macos-arm64
)
for platform in "${platforms[@]}"; do
	cp "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform.tar.gz" "$RELEASE_DIR/rtx-latest-$platform.tar.gz"
	cp "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform.tar.xz" "$RELEASE_DIR/rtx-latest-$platform.tar.xz"
	tar -xvzf "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform.tar.gz"
	cp -v rtx/bin/rtx "$RELEASE_DIR/rtx-latest-$platform"
	cp -v rtx/bin/rtx "$RELEASE_DIR/$RTX_VERSION/rtx-$RTX_VERSION-$platform"
done

pushd "$RELEASE_DIR"
echo "$RTX_VERSION" | tr -d 'v' >VERSION
cp rtx-latest-linux-x64 rtx-latest-linux-amd64
cp rtx-latest-macos-x64 rtx-latest-macos-amd64
sha256sum ./rtx-latest-* >SHASUMS256.txt
sha512sum ./rtx-latest-* >SHASUMS512.txt
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS256.txt >SHASUMS256.asc
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS512.txt >SHASUMS512.asc
popd

pushd "$RELEASE_DIR/$RTX_VERSION"
sha256sum ./* >SHASUMS256.txt
sha512sum ./* >SHASUMS512.txt
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS256.txt >SHASUMS256.asc
gpg --clearsign -u 408B88DB29DDE9E0 <SHASUMS512.txt >SHASUMS512.asc
popd

./rtx/scripts/render-install.sh >"$RELEASE_DIR"/install.sh
gpg -u 408B88DB29DDE9E0 --output "$RELEASE_DIR"/install.sh.sig --sign "$RELEASE_DIR"/install.sh

NPM_PREFIX=@jdxcode/rtx ./rtx/scripts/release-npm.sh
NPM_PREFIX=rtx-cli ./rtx/scripts/release-npm.sh
#AWS_S3_BUCKET=rtx.pub ./rtx/scripts/publish-s3.sh
./rtx/scripts/publish-r2.sh

./rtx/scripts/render-homebrew.sh >homebrew-tap/rtx.rb
pushd homebrew-tap
git add . && git commit -m "rtx ${RTX_VERSION#v}"
popd
