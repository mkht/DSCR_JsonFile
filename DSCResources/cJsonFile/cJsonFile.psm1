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
        $Value = ''
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
        $Json = try {
            Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Ignore
        }
        catch {}

        if (-not $Json) {
            Write-Verbose ("Couldn't read {0}" -f $Path)
            $Result.Ensure = 'Absent'
        }

        else {
            $JsonHash = ConvertTo-HashTable -InputObject $Json

            if (-not $JsonHash.ContainsKey($Key)) {
                Write-Verbose ('The key "{0}" is not found' -f $Key)
                $Result.Ensure = 'Absent'
            }
            else {
                $Result.Key = $Key
                $Result.Value = $JsonHash.$Key

                if (-not (Compare-MyObject $JsonHash.$Key $ValueObject)) {
                    Write-Verbose 'The Value of Key is not matched'
                    $Result.Ensure = 'Absent'
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
        $Value = ''
    )

    [bool]$result = (Get-TargetResource -Ensure $Ensure -Path $Path -Key $Key -Value $Value).Ensure -eq $Ensure
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
        $Value = ''
    )

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
            $Json = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Ignore
            if ($Json) {
                ConvertTo-HashTable -InputObject $Json
            }
        }
        catch {}
    }

    # Ensure = "Absent"
    if ($Ensure -eq 'Absent') {
        if ($JsonHash) {
            $JsonHash.Remove($Key)
            $JsonHash | ConvertTo-Json | Format-Json | Out-File -FilePath $Path -Encoding utf8 -Force
        }
    }
    else {
        # Ensure = "Present"
        if ($null -eq $JsonHash) {
            $JsonHash = @{}
        }
        $JsonHash[$Key] = $ValueObject
        $JsonHash | ConvertTo-Json | Format-Json | Out-File -FilePath $Path -Encoding utf8 -Force
    }
}
#endregion Set-TargetResource


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
