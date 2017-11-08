# Provides
 - Script to Build, Sign, and Package iOS app without Opening XCode
 - Build and Package Android app from command line
 - Places output archives (.ipa and .apk) to specified directory
 - Reads App Name and version from config.xml to properly name the output .ipa/.apk file(s)

# Usage:
 1. Place copy of build.sh, build.json, and export-ipa.plist in root of your cordova project (sibling of www folder)

 2. Look up your TeamId, Provisioning Profile Name, and TeamName from your signing Provisioning Profile. You can run the command below:

     ```bash
     security cms -D -i "/path/to/your/TargetProfile.mobileprovision"
     ```
  Note the following values:

  Key Name | Maps To Placeholder
  |:-----:|:--------:|
   TeamIdentifier | DEV_TEAM_ID 
   TeamName | DEV_TEAM_NAME
   Name | PROVISIONING_PROFILE_NAME
   
 3. Open build.sh and edit the top section for your application and environment, replacing any placeholder values with the values found in step #2 or your own custom values where applicable.
 
 4. Open build.json and verify the non placeholder values are correct for your desired build
    - You can change the release configuration to use `app-store` or other package types, and add any additional build flags you might need
    
    > NOTE: The values like `~~TEAM_ID~~` will be replaced by the script. Leave the `~~**~~` placeholder values in place

 5. Open export-ipa.plist and makes sure the value for `<key>method</key>` matches what you have in `packageType` for the build.json. Also verify any other keys that don't have `~~*~~` placeholder values.
     
     > NOTE: The values like `~~TEAM_ID~~` will be replaced by the script. Leave the `~~**~~` placeholder values in place

 6. Run the script

```
  ./build.sh
```

# Notes
- The script will use `dev` for the environment, but you can provide the env as a parameter like below, to have the output name the files appropriately. 

    ```
    ./build.sh prod
    ```
- The script renames the output archives to include the version and ENV in the output .ipa/.apk files

- The appname and version are read from the config.xml. You may want to create `config.xml.dev`, `config.xml.test`, `config.xml.prod`, etc if you have multiple versions and need to swap the names/versions of the app. Then just `cp config.xml.${env} config.xml` before running the build script.

    - This might be an additional automated feature in the future. There is an example of doing this in the custom config block of `build.sh`



