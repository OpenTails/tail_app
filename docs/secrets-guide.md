# Repository Secrets

Some of these values aren't actually secret and can be shared. Specifically the sentry ones

## Sentry

| Name              | Example Value                             | How to get                                      | Uses                                       |
|-------------------|-------------------------------------------|-------------------------------------------------|--------------------------------------------|
| SENTRY_AUTH_TOKEN | sntrys_eyJpYXQiOjE3MTYyNTky...            | Go to Sentry -> Settings -> Auth Token          | Authenticate with sentry to upload symbols |
| SENTRY_ORG        | Sentry                                    | Listed at the top left of sentry when logged in | Which org to upload symbols to             |
| SENTRY_PROJECT    | tail_app                                  | Whatever the project is named in sentry         | Which project to upload symbols to         |
| SENTRY_URL        | <https://sentry.io/>                      | The url to the sentry instance                  | Which instance to upload symbols to        |
| SENTRY_DSN        | <https://sdfghjssdh.ingest.de.sentry.io/> | The dsn for the sentry project                  | Which instance to upload errors to         |

## App Stores Deployment

| Name                    | Example Value                                                                                                                                                            | How to get                                                                                                    | Uses                                            |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| FASTLANE_GITHUB         | JeqGFIV1yb7emBFLkBk/dA==                                                                                                                                                 | echo -n your_github_username:your_personal_access_token \| base64 -w 0                                        | Store certificates for fastlane match           |
| APPLE                   | {"key_id": "D383SF739", "issuer_id": "6053b7fe-68a8-4acb-89be-165aa6465141", "key": "-----BEGIN PRIVATE KEY-----MIGTAgEAMB----END PRIVATE KEY-----", "in_house": false } | Json file of apple credentials <https://docs.fastlane.tools/app-store-connect-api/>                           | Authenticate with Apple to upload to TestFlight |
| FASTLANE_PATCH_PASSWORD | hunter2                                                                                                                                                                  | Make a password                                                                                               | Encrypt match certificates                      |
| ANDROID_KEY_PROPERTIES  | storePassword=hunter2 <br> keyPassword=hunter2 <br> keyAlias=upload <br> storeFile=key.jks                                                                               | generate an android signing certificate and fill out [key.example.properties](android/key.example.properties) | sign apks                                       |
| ANDROID_KEY_JKS         | sdfsfasdFSDgjklsgklsjdfASGHSDLGHJFSD=                                                                                                                                    | cat AndroidKeystoreCodel1417.jks \| base64 -w 0                                                               | base64 form of the jks file                     |
| GOOGLE_SECRETS          | {"type": "service_account",                                                                                                                                              | Json file of google credentials <https://docs.fastlane.tools/actions/upload_to_play_store/>                   | Authenticate to google to upload builds         |

# Firebase

| Name             | File Location                         | How to get                                                                         | Uses                               |
|------------------|---------------------------------------|------------------------------------------------------------------------------------|------------------------------------|
| ANDROID_FIREBASE | /android/app/google-services.json     | From the Firebase [Console](https://console.firebase.google.com/) Android settings | Firebase ID for push notifications |
| IOS_FIREBASE     | ./ios/Runner/GoogleService-Info.plist | From the Firebase [Console](https://console.firebase.google.com/) IOS settings     |                                    |
| DART_FIREBASE    | ./lib/firebase_options.dart           | From the flutter flutterfire_cli                                                   |                                    |
