#!/bin/bash

if [ -z $1 ]
then
  lowerEnv="dev"
else
  lowerEnv=`echo $1 | tr '[A-Z]' '[a-z]'`
fi
upperEnv=`echo $lowerEnv | tr '[a-z]' '[A-Z]'`

now=`date +%Y-%m-%d-%H%M`

##########################################################################
## Provide Application/Project Specific Configuration Values Here
##########################################################################
#**Flag that determines if the script attempts an android build
buildAndroid=false
#**The absolute root output path for the .ipa/.mdx file(s)
archivePath="${HOME}/Path/To/The/outputDirectory"
#**The prefix value for the output files
packagePrefix="RENAME_ME_IN_BUILD_SCRIPT-${lowerEnv}"
#**Uncomment the line below to override the default android build tools
#** version used by cordova.
#androidBuildToolVersion=22.0.1

##########################################################################
## Provide Signing Configuraiton Values Here
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
##########################################################################
#**The Name of your provisioning profile
provisioningProfileSpecifier="<PROVISIONING_PROFILE_NAME>"
#**The Development Team ID
devTeamId="<DEV_TEAM_ID>"
#**The path to the export-ipa.plist template file
exportIpaPlisTemplateLocation="export-ipa.plist"
#**The path to the build.json template file
buildJsonTemplateLocation="build.json"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~
#~~Do any Custom Config or JS Build Work Here
#~~ EXAMPLES: 
#~~    - replacing config.xml with an ENV specific config
#~~    - running the npm build task for the target ENV
#~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# envConfigXmlRoot="."
# echo "------Setting up Configuration for ${upperENV} Copying ENV Config.xml------"
# cp ${envConfigXmlRoot}/config.xml.${lowerEnv} config.xml

# echo "------PRE-BUILDING Application------"
# npm run build:${lowerEnv}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~END CUSTOM WORK SETUP
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## Start Generic Script
## 
## DO NOT MODIFY BELOW UNLESS ABSOLUTELY NECESSARY
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
rawVersion=`cat "config.xml" | grep -e "<widget" | grep -o -e "version=\".*\" xmlns=" | grep -o -e "[0-9\.]"`
version=`echo $rawVersion | sed -e 's/ //g'`
bundleId=`cat config.xml | grep -e "<widget" | grep -o -E "id=\"(.*)\" ver" | sed -e 's/\" ver//g' | sed -e 's/id=\"//g'`
appName=`cat config.xml | grep -e "<name>" | sed -e 's/<name>//g; s/<\/name>//g; s/^\s//g; s/^ *//;s/ *$//;'`
cordovaIosVersion=`cat config.xml | grep -e "<engine name=\"ios\"" | grep -o -E "spec=\"(.*)\"" | sed -e 's/spec=\"//g; s/\"$//g;'`

cat ${buildJsonTemplateLocation} | sed -e "s/~~PROVISIONING_PROFILE_NAME~~/${provisioningProfileSpecifier}/g; s/~~TEAM_ID~~/${devTeamId}/g" \
	> build-complete.json
cat ${exportIpaPlisTemplateLocation} | sed -e "s/~~BUNDLE_ID~~/${bundleId}/g; s/~~PROVISIONING_PROFILE_NAME~~/${provisioningProfileSpecifier}/g; s/~~TEAM_ID~~/${devTeamId}/g" \
	> export-ipa-build.plist

echo "------CONFIG------"
echo "version: ${version}"
echo "bundle id: ${bundleId}"
echo "archivePath: ${archivePath}"
echo "appName: ${appName}"
echo "packagePrefix: ${packagePrefix}"
echo "appName: ${appName}"
echo "cordova-ios version: ${cordovaIosVersion}"
echo "androidBuildToolVersion: ${androidBuildToolVersion}"

archiveLocation="${archivePath}/${now}_${appName}.xcarchive"
exportedIpaRoot="${archivePath}/${upperEnv}"
outputIpaLocation="${archivePath}/${upperEnv}/${packagePrefix}-v${version}.ipa"
ipaLocation="${archivePath}/${appName}.ipa"
xcodeProjectLocation="platforms/ios/${appName}.xcodeproj"
exportPlistLocation="export-ipa-build.plist";
buildJsonLocation="build-complete.json"

#############################################################################################################
## CORDOVA PREPARE SECTION
#############################################################################################################
echo "------RE-ADD iOS PLATFORM------"
cordova platform remove ios
if [ -z "${cordovaIosVersion}" ]
then
	cordova platform add ios
else
	cordova platform add ios@${cordovaIosVersion}
fi

echo "------PRE-BUILDING iOS------"
cordova build --release --buildConfig ${buildJsonLocation}

echo "------Clean Up Cordova Build------"
rm ${buildJsonLocation}

#############################################################################################################
## IOS BUILD SECTION
#############################################################################################################
echo "------Beginning xcodebuild------"
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

echo "-------Cleaning Up Export Config------"
rm ${exportPlistLocation}

#############################################################################################################
## ANDROID BUILD SECTION
#############################################################################################################
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
