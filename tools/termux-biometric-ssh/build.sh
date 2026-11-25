#!/bin/sh
set -eu
umask 077
cd "$(dirname "$0")"
build_dir=${XDG_CACHE_HOME:-$HOME/.cache}/termux-biometric-ssh
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/termux-biometric-ssh
rm -rf "$build_dir/classes" "$build_dir/dex"
mkdir -p "$build_dir/classes" "$build_dir/dex" "$state_dir"
chmod 700 "$state_dir"
if [ ! -f "$build_dir/android.jar" ]; then
    base64 -d "$build_dir/android.jar.b64" > "$build_dir/android.jar"
fi
javac -encoding UTF-8 -source 8 -target 8 -classpath "$build_dir/android.jar" -d "$build_dir/classes" src/local/termux/biometricssh/*.java
jar cf "$build_dir/classes.jar" -C "$build_dir/classes" .
d8 --lib "$build_dir/android.jar" --min-api 30 --output "$build_dir/dex" "$build_dir/classes.jar"
aapt package -f -M AndroidManifest.xml -I "$build_dir/android.jar" -F "$build_dir/unsigned.apk"
cp "$build_dir/unsigned.apk" "$build_dir/app.apk"
(cd "$build_dir/dex" && zip -q "$build_dir/app.apk" classes.dex)
if [ ! -f "$state_dir/signing.p12" ]; then
    keytool -genkeypair -keystore "$state_dir/signing.p12" -storepass android -keypass android -alias local -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Local SSH Biometric'
    chmod 600 "$state_dir/signing.p12"
fi
apksigner sign --ks "$state_dir/signing.p12" --ks-pass pass:android --out "$build_dir/ssh-biometric.apk" "$build_dir/app.apk"
apksigner verify "$build_dir/ssh-biometric.apk"
printf 'APK: %s\n' "$build_dir/ssh-biometric.apk"
