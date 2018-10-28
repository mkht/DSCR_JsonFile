DSCR_JsonFile
====

## This repository is no longer maintained ! :no_entry:
Please use [DSCR_FileContent](https://github.com/mkht/DSCR_FileContent/) module.

----
PowerShell DSC Resource to create JSON format file.

## Install
You can install Resource through [PowerShell Gallery](https://www.powershellgallery.com/packages/DSCR_JsonFile/).
```Powershell
Install-Module -Name DSCR_JsonFile
```

## Properties
+ [string] **Ensure** (Write):
    + Specify the key exists or not.
    + The default value is `Present`. (`Present` | `Absent`)

+ [string] **Path** (Key):
    + The path of the JSON file.

+ [string] **Key** (Key):
    + Key element.

+ [string] **Value** (Key):
    + The value corresponding to the key.
    + The value of this parameter must be a JSON formatted string.

+ [string] **Encoding** (Write):
    + You can choose text encoding for the JSON file.
    + utf8NoBOM (default) / utf8BOM / utf32 / unicode / bigendianunicode / ascii

+ [string] **NewLine** (Write):
    + You can choose new line code for the JSON file.
    + CRLF (default) / LF

## Examples
+ **Example 1**: Sample configuration
```Powershell
Configuration Example1 {
    Import-DscResource -ModuleName DSCR_JsonFile
    cJsonFile String {
        Path = 'C:\Test.json'
        Key = 'StringValue'
        Value = '"Apple"'
    }
    cJsonFile Bool {
        Path = 'C:\Test.json'
        Key = 'BoolValue'
        Value = 'true'
    }
    cJsonFile Array {
        Path = 'C:\Test.json'
        Key = "ArrayValue"
        Value = '[true, 123, "banana"]'
    }
}
```

The result of executing the above configuration, the following JSON file will output to `C:\Test.json`
```json
{
  "BoolValue": true,
  "StringValue": "Apple",
  "ArrayValue": [
    true,
    123,
    "banana"
  ]
}
```

----
## ChangeLog
### 0.2.3
 + Fixed an issue that Set-TargetResource fails when the parent folder of the `Path` is not exist.

### 0.2.2
 + Fix casing miss of the module name
 + Remove unnecessary files in the published package

### 0.2.0
 + Initial public release
