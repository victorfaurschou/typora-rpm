%global debug_package %{nil}
%global __strip /bin/true

%global tarball_url_x86_64     https://downloads.typora.io/linux/Typora-linux-x64.tar.gz
%global tarball_sha256_x86_64  4e6e835ec944485cab066fc41a8ab2b37b849e2437f8d55e219806c8095794a5
%global tarball_url_aarch64    https://downloads.typora.io/linux/Typora-linux-arm64.tar.gz
%global tarball_sha256_aarch64 ac5cf81d4d819e492ac96e4f7dc4a6a6a36f26eced0a92bb2e791c3fc9c2cd41

%ifarch x86_64
%global tarball_url    %{tarball_url_x86_64}
%global tarball_sha256 %{tarball_sha256_x86_64}
%endif
%ifarch aarch64
%global tarball_url    %{tarball_url_aarch64}
%global tarball_sha256 %{tarball_sha256_aarch64}
%endif

Name:           typora
Version:        1.13.4
Release:        3
Summary:        Minimal Markdown editor (installer - downloads binary at install time)

License:        Proprietary
URL:            https://typora.io/
Source0:        typora.desktop

ExclusiveArch:  x86_64 aarch64
AutoReqProv:    no

Requires:       curl
Requires:       tar
Requires:       gzip
Requires:       nss
Requires:       nspr
Requires:       alsa-lib
Requires:       libXScrnSaver
Requires:       libXtst
Requires:       libxkbcommon
Requires:       libdrm
Requires:       mesa-libgbm
Requires:       at-spi2-atk
Requires:       at-spi2-core
Requires:       cups-libs
Requires:       libsecret
Requires:       gtk3
Requires:       libnotify
Requires:       hicolor-icon-theme

%description
Typora is a minimal Markdown editor with live preview. This package is
an installer: it does NOT contain the Typora binary. On installation it
downloads the official tarball from downloads.typora.io and unpacks it
into /opt/typora. Typora itself is proprietary commercial software; a
license must be purchased from https://typora.io/ for continued use.

%prep
# Nothing to prep - no upstream source bundled.

%build
# Nothing to build.

%install
rm -rf %{buildroot}
install -d %{buildroot}/opt/typora
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_datadir}/applications
ln -s /opt/typora/Typora %{buildroot}%{_bindir}/typora
install -m 0644 %{SOURCE0} %{buildroot}%{_datadir}/applications/typora.desktop

%post
set -eu
TARBALL_URL='%{tarball_url}'
INSTALL_DIR=/opt/typora
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

printf '%s\n' "Downloading Typora from $TARBALL_URL ..."
if ! curl -fL --retry 3 --connect-timeout 30 --max-time 600 \
        -o "$TMPDIR/typora.tar.gz" "$TARBALL_URL"; then
    rc=$?
    printf '%s\n' "typora: download failed (curl exit $rc) from $TARBALL_URL" >&2
    exit 1
fi

printf '%s\n' "Verifying SHA256 ..."
printf '%s\n' "%{tarball_sha256}  $TMPDIR/typora.tar.gz" | sha256sum -c - || {
    printf '%s\n' "typora: tarball SHA256 mismatch - refusing to install." >&2
    exit 1
}

printf '%s\n' "Unpacking to $INSTALL_DIR ..."
tar -xzf "$TMPDIR/typora.tar.gz" -C "$TMPDIR"

# Locate the directory containing the Typora binary (tarball nests it under
# bin/Typora-linux-x64/) and flatten its contents into /opt/typora.
TYPORA_BIN=$(find "$TMPDIR" -type f -name Typora -perm -u+x | head -n1)
if [ -z "$TYPORA_BIN" ]; then
    printf '%s\n' "typora: could not locate Typora binary in extracted tarball" >&2
    exit 1
fi
SRCDIR=$(dirname "$TYPORA_BIN")

rm -rf "${INSTALL_DIR:?}"/*
cp -a "$SRCDIR"/. "$INSTALL_DIR"/

if [ ! -x "$INSTALL_DIR/Typora" ]; then
    printf '%s\n' "typora: post-copy verification failed - $INSTALL_DIR/Typora missing or not executable" >&2
    exit 1
fi

# Install icons from the unpacked payload, if present.
for size in 16 32 128 256 512; do
    icon="$INSTALL_DIR/resources/assets/icon/icon_${size}x${size}.png"
    if [ -f "$icon" ]; then
        install -Dm 0644 "$icon" \
            "%{_datadir}/icons/hicolor/${size}x${size}/apps/typora.png"
    fi
done
gtk-update-icon-cache -q %{_datadir}/icons/hicolor 2>/dev/null || :
update-desktop-database -q 2>/dev/null || :

%postun
if [ "$1" -eq 0 ]; then
    rm -rf /opt/typora
    for size in 16 32 128 256 512; do
        rm -f "%{_datadir}/icons/hicolor/${size}x${size}/apps/typora.png"
    done
    gtk-update-icon-cache -q %{_datadir}/icons/hicolor 2>/dev/null || :
    update-desktop-database -q 2>/dev/null || :
fi

%files
%dir /opt/typora
%{_bindir}/typora
%{_datadir}/applications/typora.desktop

%changelog
* Sun May 17 2026 Victor Faurschou <mail@victorfaurschou.com> - 1.13.4-3
- Bump pinned tarball SHA256 for x86_64 and aarch64.

* Sun May 17 2026 Victor Faurschou <mail@victorfaurschou.com> - 1.13.4-2
- Bump pinned tarball SHA256 for x86_64 and aarch64.

* Sat May 16 2026 Victor Faurschou <mail@victorfaurschou.com> - 1.13.4-1
- Bump pinned tarball SHA256 for x86_64 and aarch64.

