binary_name="net.downloadhelper.coapp"
app_id=$(jq -r '.id' ./config.json)
app_version=$(jq -r '.version' ./package.json)
pkg_filename="vdh-coapp-$app_version"
pkg_version=`date +%s`

# Create .app

dot_app_path=$dist/dotApp/
app_path=$dot_app_path/$app_id.app
macos_dir=$app_path/Contents/MacOS
ffmpeg_dir=$macos_dir/ffmpeg
res_dir=$app_path/Contents/Resources

mkdir -p $macos_dir
mkdir -p $ffmpeg_dir
mkdir -p $res_dir

scripts_dir=$dist/scripts
mkdir -p $scripts_dir

echo "Fetching ffmpeg…"
cd $ffmpeg_dir
tmpfile=$(mktemp /tmp/coapp-build.XXXXXX)
curl -L $ffmpeg_url > $tmpfile
echo "Extracting ffmpeg"
tar -xf $tmpfile
mv ffmpeg-mac-$target_arch/ffmpeg ffmpeg-mac-$target_arch/ffprobe ffmpeg-mac-$target_arch/presets .
rmdir ffmpeg-mac-$target_arch
rm $tmpfile
cd -

echo "Building single executable"
pkg ./app/main.js \
  --target node18-macos-$target_arch \
  --output $macos_dir/bin/$binary_name

echo "Creating pkg config files"

tmpfile=$(mktemp /tmp/coapp-build.XXXXXX)
jq -n --argfile config config.json \
  --argfile package package.json \
  "{config:\$config, manifest:\$package, version:$pkg_version, binaryName:\"$binary_name\"}" \
  > $tmpfile

ejs -f $tmpfile ./assets/pkg-distribution.xml.ejs > $dist/pkg-distribution.xml
ejs -f $tmpfile ./assets/pkg-component.plist.ejs > $dist/pkg-component.plist
ejs -f $tmpfile ./assets/Info.plist.ejs > $app_path/Contents/Info.plist
ejs -f $tmpfile ./assets/setup-mac-pkg.sh.ejs > $scripts_dir/postinstall

rm $tmpfile

chmod +x $scripts_dir/postinstall

cp LICENSE.txt assets/README.txt $macos_dir/
cp assets/icon.icns $res_dir

jq "{id, name, description, allowed_extensions}" ./config.json > $macos_dir/config.json

echo "Building $pkg_filename.pkg"

pkgbuild \
  --root $dot_app_path \
  --install-location /Applications \
  --scripts $scripts_dir \
  --identifier $app_id \
  --component-plist $dist/pkg-component.plist \
  --version $pkg_version \
  --sign "Developer ID Installer: ACLAP" \
  $dist/$pkg_filename.pkg

sudo productbuild --package /path_to_saved_package/packagename.pkg       --content /path_to_app/         --sign "Developer ID Installer: *******"       /path_to_signed_pkg/signed.pkg

echo "Building $pkg_filename.dmg"

# FIXME: doc about create-dmg
create-dmg --volname "DownloadHelper Co-app" \
  --background ./assets/dmg-background.tiff \
  --window-pos 200 120 --window-size 500 400 --icon-size 70 \
  --icon "net.downloadhelper.coapp.app" 100 200 \
  --app-drop-link 350 200 \
  $dist/$pkg_filename.dmg \
  $dot_app_path
