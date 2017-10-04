#!/bin/bash

if [ -z $1 ]
then
  lowerEnv="dev"
else
  lowerEnv=`echo $1 | tr '[A-Z]' '[a-z]'`
fi
upperEnv=`echo $lowerEnv | tr '[a-z]' '[A-Z]'`

now=`date +%Y-%m-%d-%H%M`

#Update Application Specific Values HERE
buildAndroid=false
indexWaitTime=20
archivePath="${HOME}/Path/To/The/outputDirectory"
packagePrefix="<DESIRED-OUTPUT-PREFIX>-${lowerEnv}"
codeSignIdentity="iPhone Distribution"
exportPlistLocation="export-ipa.plist";
buildJsonFile="build.json"

#Update with your Signing values here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# To Find these values if you aren't sure of them you can run the
# following command on your target provisioning profile:
#
#  security cms -D -i "/path/to/your/TargetProfile.mobileprovision"
#
# in the output look for the Name and TeamIdentifier Keys
#  <key>Name</key>
#  <string>NAME OF YOUR PROVISIONING PROFILE IS HERE</string>
#
#  <key>TeamIdentifier</key>
#  <array>
#    <string>DEVELOPMENT TEAM ID IS HERE</string>
#  </array>
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
provisioningProfileSpecifier="<PROVISIONING_PROFILE_NAME>"
developmentTeamId="<DEV_TEAM_ID>"

## Uncomment the line below to override the default android build tools
## version used by cordova.
# androidBuildToolVersion=22.0.1

#############################################################################################################
#Start Generic Script
#DO NOT MODIFY BELOW UNLESS ABSOLUTELY NECESSARY
#############################################################################################################

echo "-------Extracting Version, BundleId, and AppName from config.xml------"
rawVersion=`cat "config.xml" | grep -e "<widget" | grep -o -e "version=\".*\" xmlns=" | grep -o -e "[0-9\.]"`
version=`echo $rawVersion | sed -e 's/ //g'`
bundleId=`cat config.xml | grep -e "<widget" | grep -o -E "id=\"(.*)\" ver" | sed -e 's/\" ver//g' | sed -e 's/id=\"//g'`
appName=`cat config.xml | grep -e "<name>" | sed -e 's/<name>//g; s/<\/name>//g; s/^\s//g; s/^ *//;s/ *$//;'`

echo "------CONFIG------"
echo "version: ${version}"
echo "bundleId: ${bundleId}"
echo "archivePath: ${archivePath}"
echo "appName: ${appName}"
echo "packagePrefix: ${packagePrefix}"
echo "indexWaitTime: ${indexWaitTime}"
echo "androidBuildToolVersion: ${androidBuildToolVersion}"

archiveLocation="${archivePath}/${now}_${appName}.xcarchive"
exportedIpaRoot="${archivePath}/${upperEnv}"
outputIpaLocation="${archivePath}/${upperEnv}/${packagePrefix}-v${version}.ipa"
ipaLocation="${archivePath}/${appName}.ipa"
xcodeProjectLocation="platforms/ios/${appName}.xcodeproj"

echo "------RE-ADD iOS PLATFORM------"
cordova platform remove ios
cordova platform add ios

echo "------PRE-BUILDING iOS------"
cordova build --release --buildConfig build.json ios

open "${xcodeProjectLocation}"
echo "---------Waiting ${indexWaitTime} seconds to let project index---------"
sleep $indexWaitTime
echo "Closing Xcode"
osascript -e 'quit app "Xcode"'

echo "---------Beginning xcodebuild---------"
xcodebuild \
  -sdk iphoneos \
  -project "${xcodeProjectLocation}" \
  -scheme "${appName}" \
  -configuration Release build \
  -archivePath "${archiveLocation}" \
  archive \
  DEVELOPMENT_TEAM="${devTeamId}" \
  PROVISIONING_PROFILE_SPECIFIER="${provisioningProfileSpecifier}"

echo "------Export Archive Props------"
echo "Archive Loction: ${archiveLocation}"
echo "Export PLIST File: ${exportPlistLocation}"
echo "Export Path: ${exportedIpaRoot}"
xcodebuild \
  -exportArchive \
  -archivePath "${archiveLocation}" \
  -exportPath "${exportedIpaRoot}" \
  -exportOptionsPlist "${exportPlistLocation}" \

echo "-------Renaming Exported IPA------"
mv "${exportedIpaRoot}/${appName}.ipa" ${outputIpaLocation}

#BUILDING ANDROID
if [ "$buildAndroid" = true ]
then
  echo "------RE-ADDING ANDROID PLATFORM------"
  cordova platform remove android
  cordova platform add android

  echo "------BUILDING ANDROID------"
  if [ -z "$androidBuildToolVersion" ]
  then
    echo "---------No Android Build Tool Version set. Default to Cordova's Default"
    cordova build android
  else
    echo "---------Android Build Tool Version set. Using ${androidBuildToolVersion}"
    cordova build android -- --gradleArg=-PcdvBuildToolsVersion=${androidBuildToolVersion}
  fi

  cp ./platforms/android/build/outputs/apk/android-debug.apk "${archivePath}/${packagePrefix}-v${version}.apk"
fi

echo "------Archives Built-------"
open ${archivePath}
