#!/bin/sh
# On success, prints either 'no-change' or 'rebuilt <version>-<release>' to
# stdout and exits 0. Non-zero exit means an actual failure.
set -eu

for cmd in rpmbuild createrepo_c curl sha256sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf '%s\n' "Error: required command not found: $cmd" >&2
        exit 1
    fi
done

cd "$(dirname "$0")"

URL_X86_64=https://downloads.typora.io/linux/Typora-linux-x64.tar.gz
URL_AARCH64=https://downloads.typora.io/linux/Typora-linux-arm64.tar.gz
SPEC=SPECS/typora.spec
git_name=$(git config user.name 2>/dev/null || true)
git_email=$(git config user.email 2>/dev/null || true)
if [ -n "$git_name" ] && [ -n "$git_email" ]; then
    AUTHOR="$git_name <$git_email>"
else
    AUTHOR="Unknown <unknown@example.org>"
    printf '%s\n' "Warn: git user.name/user.email not set; using '$AUTHOR' in changelog." >&2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

VERSION_OVERRIDE=""
VERBOSE=0
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose) VERBOSE=1; shift ;;
        --version)
            if [ -z "${2:-}" ]; then
                printf '%s\n' "Error: --version requires an argument" >&2
                exit 2
            fi
            VERSION_OVERRIDE=$2
            shift 2
            ;;
        *)
            printf '%s\n' "Error: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

log() {
    if [ "$VERBOSE" -eq 1 ]; then
        printf '%s\n' "$@"
    fi
}

run() {
    if [ "$VERBOSE" -eq 1 ]; then
        "$@"
    else
        out=$(mktemp)
        if ! "$@" >"$out" 2>&1; then
            cat "$out" >&2
            rm -f "$out"
            return 1
        fi
        rm -f "$out"
    fi
}

log "Downloading upstream tarballs"
curl -fsSL --retry 3 -o "$TMP/x86_64.tar.gz" "$URL_X86_64"
curl -fsSL --retry 3 -o "$TMP/aarch64.tar.gz" "$URL_AARCH64"

NEW_SHA_X86_64=$(sha256sum "$TMP/x86_64.tar.gz" | awk '{print $1}')
NEW_SHA_AARCH64=$(sha256sum "$TMP/aarch64.tar.gz" | awk '{print $1}')
OLD_SHA_X86_64=$(awk '/^%global[[:space:]]+tarball_sha256_x86_64/ {print $3}' "$SPEC")
OLD_SHA_AARCH64=$(awk '/^%global[[:space:]]+tarball_sha256_aarch64/ {print $3}' "$SPEC")

if [ "$NEW_SHA_X86_64" = "$OLD_SHA_X86_64" ] \
        && [ "$NEW_SHA_AARCH64" = "$OLD_SHA_AARCH64" ] \
        && [ -z "$VERSION_OVERRIDE" ]; then
    printf 'no-change\n'
    exit 0
fi

OLD_REL=$(awk '/^Release:/ {sub(/%.*/, "", $2); print $2}' "$SPEC")
OLD_VERSION=$(awk '/^Version:/ {print $2}' "$SPEC")

if [ -n "$VERSION_OVERRIDE" ]; then
    VERSION=$VERSION_OVERRIDE
else
    VERSION=$(tar -xzOf "$TMP/x86_64.tar.gz" \
            --wildcards '*/resources/package.json' 2>/dev/null \
        | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -n1)
    if [ -z "$VERSION" ]; then
        printf '%s\n' "Error: could not extract upstream version from tarball." \
            "Re-run with --version X.Y.Z to set it explicitly." >&2
        exit 1
    fi
fi

if [ "$VERSION" = "$OLD_VERSION" ]; then
    NEW_REL=$((OLD_REL + 1))
else
    NEW_REL=1
fi

log "Upstream changed:"
log "  x86_64  in spec: $OLD_SHA_X86_64"
log "  x86_64  current: $NEW_SHA_X86_64"
log "  aarch64 in spec: $OLD_SHA_AARCH64"
log "  aarch64 current: $NEW_SHA_AARCH64"

DATE=$(LC_ALL=C date '+%a %b %d %Y')

sed -i "s|^%global[[:space:]]\+tarball_sha256_x86_64.*|%global tarball_sha256_x86_64  $NEW_SHA_X86_64|" "$SPEC"
sed -i "s|^%global[[:space:]]\+tarball_sha256_aarch64.*|%global tarball_sha256_aarch64 $NEW_SHA_AARCH64|" "$SPEC"
sed -i "s|^Version:.*|Version:        $VERSION|" "$SPEC"
sed -i "s|^Release:.*|Release:        ${NEW_REL}|" "$SPEC"

awk -v date="$DATE" -v author="$AUTHOR" -v ver="$VERSION" -v rel="$NEW_REL" '
    /^%changelog/ {
        print
        print "* " date " " author " - " ver "-" rel
        print "- Bump pinned tarball SHA256 for x86_64 and aarch64."
        print ""
        next
    }
    { print }
' "$SPEC" > "$SPEC.new" && mv "$SPEC.new" "$SPEC"

log "Rebuilding RPMs (x86_64, aarch64)"
rm -rf RPMS BUILD SRPMS BUILDROOT
run rpmbuild --target x86_64  --define "_topdir $PWD" -bb "$SPEC"
run rpmbuild --target aarch64 --define "_topdir $PWD" -bb "$SPEC"

rm -f repo/typora-*.rpm
cp "RPMS/x86_64/typora-${VERSION}-${NEW_REL}.x86_64.rpm"   repo/
cp "RPMS/aarch64/typora-${VERSION}-${NEW_REL}.aarch64.rpm" repo/
run createrepo_c --update repo

log ""
log "New RPMs:"
log "  repo/typora-${VERSION}-${NEW_REL}.x86_64.rpm"
log "  repo/typora-${VERSION}-${NEW_REL}.aarch64.rpm"

printf 'rebuilt %s-%s\n' "$VERSION" "$NEW_REL"
