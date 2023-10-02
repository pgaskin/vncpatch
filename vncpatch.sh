#!/bin/sh
set -eu

apk_default_url="https://help.realvnc.com/hc/en-us/article_attachments/12641645401885/com.realvnc.viewer.android_4.6.1.50575.apk"
apk_default_sha="2b0af1a60ccfbf7620277621e770820d98f0e1b82ffdfa32fadf3b042948c64f"

nosave=""
java="java"
zipalign="zipalign"
apktool="lib/apktool-2.8.1.jar"
apksigner="lib/apksigner-0.9.jar"
keystore="generate"
apk="download"

usage() {
    echo "usage: $0 [options] [apk_file]"
    echo
    echo "options:"
    echo "  -h        show this help text"
    echo "  -n        do not re-generate patch files"
    echo "  -j path   java (>= 11) path ($java)"
    echo "  -z path   zipalign path ($zipalign)"
    echo "  -t path   apktool.jar (= 2.8.1) path ($apktool)"
    echo "  -s path   apksigner.jar (>= 0.9) path ($apksigner)"
    echo "  -k path   keystore path for signing apk ($keystore)"
    echo
    echo "arguments:"
    echo "  apk_file  the apk file to patch; only required the first time ($apk)"
    exit 2
}

# parse command line
while getopts ":hnj:z:t:s:k:" arg; do
  case "$arg" in
    n) nosave=1 ;;
    j) java="$(realpath -e "$OPTARG" || exit 1)" || usage ;;
    z) zipalign="$(realpath -e "$OPTARG" || exit 1)" || usage ;;
    t) apktool="$(realpath -e "$OPTARG" || exit 1)" || usage ;;
    s) apksigner="$(realpath -e "$OPTARG" || exit 1)" || usage ;;
    k) keystore="$(realpath -e "$OPTARG" || exit 1)" || usage ;;
    h|*) usage ;;
  esac
done
if [ $# -gt 0 ]; then
    apk="$(realpath -e "$1" || exit 1)" || usage
    shift
fi
if [ $# -ne 0 ]; then
    usage
fi

# cd to the script dir
cd "$(dirname "$0")"

# ensure the apk dir exists
if [ ! -f src/.git/apksum ] || [ -n "$apk" ]; then

    # download the apk if we need to
    if [ "$apk" = "download" ]; then
        if [ ! -d download ]; then
            mkdir download
        fi
        apk="download/${apk_default_url##*/}"
        if [ -f "$apk" ]; then
            sha="$(sha256sum "$apk")"
            sha="${sha%% *}"
        else
            sha=
        fi
        if [ "$sha" != "$apk_default_sha" ]; then
            printf '\n\x1b[1;34m> %s\x1b[0m\n' "Downloading APK"
            wget -O "$apk" "$apk_default_url"
            test -f "$apk"
            sha="$(sha256sum "$apk")"
            sha="${sha%% *}"
            if [ "$sha" != "$apk_default_sha" ]; then
                echo "error: apk checksum mismatch (expected $apk_default_sha, got $sha)" >&2
                exit 1
            fi
        fi
    fi

    # decompile apk
    if [ ! -d src/.git ] || ! git -C src rev-list -1 refs/tags/apk >/dev/null 2>&1; then
        printf '\n\x1b[1;34m> %s\x1b[0m\n' "Decompiling APK"
        rm -rf src
        "$java" -jar "$apktool" decode --output src "$apk"
        git init src
        echo /build >> src/.git/info/exclude
        git -C src add .
        git -C src commit --quiet --message='import apk'
        git -C src tag apk
    fi

    # ensure we have the same apk we decompiled
    if [ -n "$apk" ]; then
        sha="$(sha256sum "$apk")"
        sha="${sha%% *}"
        if [ ! -f src/.git/apksum ]; then
            echo "$sha" > src/.git/apksum
        elif [ "$sha" != "$(cat src/.git/apksum)" ]; then
            echo "error: apk mismatch; please delete the src folder and start again" >&2
            exit 1
        fi
    fi
fi

# if we haven't finished applying, show the status and stop
if [ -d src/.git/rebase-apply ]; then
    printf '\n\x1b[1;34m> %s\x1b[0m\n' "Applying patches"
    git -C src status
    exit 1
fi

# apply patches
if [ "$(git -C src rev-list -1 refs/tags/apk)" = "$(git -C src rev-list -1 HEAD)" ]; then
    printf '\n\x1b[1;34m> %s\x1b[0m\n' "Applying patches"
    git -C src am "$PWD"/patches/*.patch
fi

# format new patches
if [ -z "$nosave" ]; then
    printf '\n\x1b[1;34m> %s\x1b[0m\n' "Saving patches"
    rm -rf ../patches
    git -C src format-patch --output-directory ../patches/ --no-stat --no-signature --numbered --no-attach --ignore-if-in-upstream --always refs/tags/apk
fi

# create build dir
if [ -d build ]; then
    rm -rf build
fi
mkdir build

# build
printf '\n\x1b[1;34m> %s\x1b[0m\n' "Building APK"
"$java" -jar "$apktool" build --output build/patched.apk src

# align
printf '\n\x1b[1;34m> %s\x1b[0m\n' "Aligning APK"
"$zipalign" -p 8 build/patched.apk build/aligned.apk

# sign
printf '\n\x1b[1;34m> %s\x1b[0m\n' "Signing APK"
if [ "$keystore" = "generate" ]; then
    test -f "default.jks" || keytool -genkeypair -v -keystore "default.jks" -keyalg "RSA" -storepass "default" -alias "default" -dname "CN=vncpatch, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=CA"
    "$java" -jar "$apksigner" sign --min-sdk-version=30 --ks "default.jks" --ks-pass "pass:default" --pass-encoding utf-8 --out build/signed.apk build/aligned.apk
else
    "$java" -jar "$apksigner" sign --min-sdk-version=30 --ks "$keystore" --out build/signed.apk build/aligned.apk
fi

# done
printf '\n\x1b[1;34m> %s\x1b[0m\n' "Done"
echo "Saved signed APK to build/signed.apk."
