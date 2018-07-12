Enum Encoding {
    Default
    utf8
    utf8NoBOM
    utf8BOM
    utf32
    unicode
    bigendianunicode
    ascii
}


#region Get-TargetResource
function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]
        $Value = '',

        [Parameter(Mandatory = $false)]
        [Encoding]
        $Encoding = 'utf8NoBOM',

        [Parameter(Mandatory = $false)]
        [ValidateSet('CRLF', 'LF')]
        [string]
        $NewLine = 'CRLF'
    )

    $Result = @{
        Ensure = 'Present'
        Path   = $Path
        Key    = $null
        Value  = $null
    }

    $ValueObject = $null
    if ($Value) {
        $tmp = try {
            ConvertFrom-Json -InputObject $Value -ErrorAction Ignore
        }
        catch {}

        if ($null -eq $tmp) {
            $ValueObject = $Value
        }
        elseif ($tmp.GetType().Name -eq 'PSCustomObject') {
            $ValueObject = ConvertTo-HashTable -InputObject $tmp
        }
        else {
            $ValueObject = $tmp
        }
    }

    # check file exists
    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Verbose ('File "{0}" not found.' -f $Path)
        $Result.Ensure = 'Absent'
    }
    else {
        # Read JSON
        $Json = try {
            $PSEncoder = Get-PSEncoding -Encoding $Encoding
            Get-Content -Path $Path -Raw -Encoding $PSEncoder | ConvertFrom-Json -ErrorAction Ignore
        }
        catch {}

        if (-not $Json) {
            Write-Verbose ("Couldn't read {0}" -f $Path)
            $Result.Ensure = 'Absent'
        }

        else {
            $JsonHash = ConvertTo-HashTable -InputObject $Json

            $KeyHierarchy = $Key -split '/'
            $tHash = $JsonHash
            for ($i = 0; $i -lt $KeyHierarchy.Count; $i++) {
                $local:tKey = $KeyHierarchy[$i]

                if (-not $tHash.ContainsKey($tKey)) {
                    Write-Verbose ('The key "{0}" is not found' -f $tKey)
                    $Result.Ensure = 'Absent'
                    break
                }

                if ($i -gt ($KeyHierarchy.Count - 2)) {
                    $Result.Key = $Key
                    $Result.Value = ($tHash.$tKey | ConvertTo-Json -Compress)

                    if (-not (Compare-MyObject $tHash.$tKey $ValueObject)) {
                        Write-Verbose 'The Value of Key is not matched'
                        $Result.Ensure = 'Absent'
                    }

                    break
                }
                else {
                    $tHash = $tHash.$tKey
                }
            }
        }
    }

    $Result
}
#endregion Get-TargetResource


#region Test-TargetResource
function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]
        $Value = '',

        [Parameter(Mandatory = $false)]
        [Encoding]
        $Encoding = 'utf8NoBOM',

        [Parameter(Mandatory = $false)]
        [ValidateSet('CRLF', 'LF')]
        [string]
        $NewLine = 'CRLF'
    )

    [bool]$result = (Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure
    return $result
}
#endregion Test-TargetResource


#region Set-TargetResource
function Set-TargetResource {
    param
    (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Present", "Absent")]
        [string]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]
        $Value = '',

        [Parameter(Mandatory = $false)]
        [Encoding]
        $Encoding = 'utf8NoBOM',

        [Parameter(Mandatory = $false)]
        [ValidateSet('CRLF', 'LF')]
        [string]
        $NewLine = 'CRLF'
    )

    $PSEncoder = Get-PSEncoding -Encoding $Encoding

    $ValueObject = $null
    if ($Value) {
        $tmp = try {
            ConvertFrom-Json -InputObject $Value -ErrorAction Ignore
        }
        catch {}

        if ($null -eq $tmp) {
            $ValueObject = $Value
        }
        elseif ($tmp.GetType().Name -eq 'PSCustomObject') {
            $ValueObject = ConvertTo-HashTable -InputObject $tmp
        }
        else {
            $ValueObject = $tmp
        }
    }

    $JsonHash = $null
    if (Test-Path -Path $Path -PathType Leaf) {
        $JsonHash = try {
            $Json = Get-Content -Path $Path -Raw -Encoding $PSEncoder | ConvertFrom-Json -ErrorAction Ignore
            if ($Json) {
                ConvertTo-HashTable -InputObject $Json
            }
        }
        catch {}
    }

    # Ensure = "Absent"
    if ($Ensure -eq 'Absent') {
        if ($JsonHash) {
            $KeyHierarchy = $Key -split '/'
            $expression = '$JsonHash'
            for ($i = 0; $i -lt $KeyHierarchy.Count; $i++) {
                if ($i -ne ($KeyHierarchy.Count - 1)) {
                    $expression += ('.{0}' -f $KeyHierarchy[$i])
                }
                else {
                    if (Invoke-Expression -Command $expression) {
                        $expression += (".Remove('{0}')" -f $KeyHierarchy[$i])
                    }
                }
            }

            Invoke-Expression -Command $expression

            if (('utf8', 'utf8NoBOM') -eq $Encoding) {
                $JsonHash | ConvertTo-Json | Format-Json | Out-String | Convert-NewLine -NewLine $NewLine | ForEach-Object { [System.Text.Encoding]::UTF8.GetBytes($_) } | Set-Content -Path $Path -Encoding Byte -NoNewline -Force
            }
            else {
                $JsonHash | ConvertTo-Json | Format-Json | Convert-NewLine -NewLine $NewLine | Set-Content -Path $Path -Encoding $PSEncoder -NoNewline -Force
            }
        }
    }
    else {
        # Ensure = "Present"
        if ($null -eq $JsonHash) {
            $JsonHash = @{}
        }

        # Workaroud for ConvertTo-Json bug
        # https://github.com/PowerShell/PowerShell/issues/3153
        if ($ValueObject -is [Array]) {
            $ValueObject = $ValueObject.SyncRoot
        }

        $KeyHierarchy = $Key -split '/'
        $tHash = $JsonHash
        for ($i = 0; $i -lt $KeyHierarchy.Count; $i++) {
            if ($i -lt ($KeyHierarchy.Count - 1)) {

                if (-not $tHash.ContainsKey($KeyHierarchy[$i])) {
                    $tHash.($KeyHierarchy[$i]) = @{}
                }
                elseif ($tHash.($KeyHierarchy[$i]) -isnot [hashtable]) {
                    $tHash.($KeyHierarchy[$i]) = @{}
                }

                $tHash = $tHash.($KeyHierarchy[$i])
            }
            else {
                $tHash.($KeyHierarchy[$i]) = $ValueObject
                break
            }
        }

        if (('utf8', 'utf8NoBOM') -eq $Encoding) {
            $JsonHash | ConvertTo-Json | Format-Json | Out-String | Convert-NewLine -NewLine $NewLine | ForEach-Object { [System.Text.Encoding]::UTF8.GetBytes($_) } | Set-Content -Path $Path -Encoding Byte -NoNewline -Force
        }
        else {
            $JsonHash | ConvertTo-Json | Format-Json | Convert-NewLine -NewLine $NewLine | Set-Content -Path $Path -Encoding $PSEncoder -NoNewline -Force
        }
    }
}
#endregion Set-TargetResource


function Convert-NewLine {
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]
        $InputObject,

        [Parameter(Position = 1)]
        [ValidateSet('CRLF', 'LF')]
        [string]
        $NewLine = 'CRLF'
        
    )

    if ($NewLine -eq 'LF') {
        $InputObject.Replace("`r`n", "`n")
    }
    else {
        $InputObject -replace "[^\r]\n", "`r`n"
    }
}


function Get-PSEncoding {
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Encoding]
        $Encoding
    )

    switch -wildcard ($Encoding) {
        'utf8*' {
            'utf8'
            break
        }
        Default {
            $_.toString()
        }
    }
}


#region ConvertTo-HashTable
function ConvertTo-HashTable {

    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PSObject]
        $InputObject
    )

    $Output = @{}
    $InputObject.psobject.properties | Where-Object {$_.MemberType -eq 'NoteProperty'} | ForEach-Object { 
        
        
        if ($_.Value -is [System.Management.Automation.PSCustomObject]) {
            $Output[$_.Name] = ConvertTo-HashTable -InputObject $_.Value
        }
        else {
            $Output[$_.Name] = $_.Value
        }
    }

    $Output
}
#endregion ConvertTo-HashTable


#region Compare-Hashtable
function Compare-Hashtable {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable]$Left,
    
        [Parameter(Mandatory = $true)]
        [Hashtable]$Right		
    )
    
    $Result = $true
        
    if ($Left.Keys.Count -ne $Right.keys.Count) {
        $Result = $false
    }
    
    $Left.Keys | ForEach-Object {
    
        if (-not $Result) {
            return
        }

        if (-not (Compare-MyObject -Left $Left[$_] -Right $Right[$_])) {
            $Result = $false
        }
    }
    
    $Result
}
#endregion Compare-Hashtable


#region Compare-MyObject
function Compare-MyObject {
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory = $true)]
        [Object]$Left,
    
        [Parameter(Mandatory = $true)]
        [Object]$Right
    )

    $Result = $true

    if (($Left -as [HashTable]) -and ($Right -as [HashTable])) {
        if (-not (Compare-Hashtable $Left $Right)) {
            $Result = $false
        }
    }
    elseif ($Left.GetType().FullName -ne $Right.GetType().FullName) {
        $Result = $false
    }
    elseif ($Left.Count -ne $Right.Count) {
        $Result = $false
    }
    elseif ($Left.Count -gt 1) {
        if (-not (($Left -join ';') -ceq ($Right -join ';'))) {
            $Result = $false
        }
    }
    else {
        if (Compare-Object $Left $Right -CaseSensitive) {
            $Result = $false
        }
    }

    $Result
}
#endregion Compare-MyObject


#region Format-Json
# Original code obtained from https://github.com/PowerShell/PowerShell/issues/2736
# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json {
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]
        $json
    ) 

    $indent = 0;
    $result = ($json -Split '\n' |
            % {
            if ($_ -match '[\}\]]') {
                # This line contains  ] or }, decrement the indentation level
                $indent--
            }
            $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
            if ($_ -match '[\{\[]') {
                # This line contains [ or {, increment the indentation level
                $indent++
            }
            $line
        }) -Join "`n"
    
    # Unescape Html characters (<>&')
    $result.Replace('\u0027', "'").Replace('\u003c', "<").Replace('\u003e', ">").Replace('\u0026', "&")
    
}
#endregion Format-Json


Export-ModuleMember -Function *-TargetResource
