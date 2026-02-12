Set-StrictMode -Version Latest

function Resolve-IdeaDocPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    $resolved = Resolve-Path -Path $Path -ErrorAction Stop
    return $resolved.Path
}

function Read-TextLines {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ($null -eq $raw -or $raw.Length -eq 0) {
        return @()
    }
    return ($raw -split "`r?`n")
}

function New-Violation {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][int]$Line
    )

    [pscustomobject]@{
        Code = $Code
        Message = $Message
        Line = $Line
    }
}

function Convert-ToLineIndexMap {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines
    )

    $map = @{}
    for ($i = 0; $i -lt $Lines.Length; $i++) {
        $map[$i] = $i + 1
    }
    return $map
}

function ConvertFrom-IdeaDoc {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines
    )

    if ($Lines -is [string]) {
        if ([string]::IsNullOrEmpty($Lines)) {
            $Lines = @()
        } else {
            $Lines = $Lines -split "`r?`n"
        }
    }

    $lineNumbers = Convert-ToLineIndexMap -Lines $Lines
    if ($null -eq $lineNumbers) {
        $lineNumbers = @{}
    }

    function Get-LineNumberForIndex {
        param([int]$Index)
        if ($lineNumbers.ContainsKey($Index)) {
            return $lineNumbers[$Index]
        }
        return $Index + 1
    }

    $result = [pscustomobject]@{
        Lines = $Lines
        LineNumbers = $lineNumbers
        TaxonomyLine = $null
        Groups = @()
        Entries = @()
    }

    $currentTop = $null
    $currentSub = $null

    for ($i = 0; $i -lt $Lines.Length; $i++) {
        $line = $Lines[$i]

        if ($line -match '^##\s+(?<title>.+)$') {
            $title = $Matches['title'].Trim()
            if ($title -eq 'Taxonomy') {
                if (-not $result.TaxonomyLine) {
                    $result.TaxonomyLine = Get-LineNumberForIndex -Index $i
                }
                $currentTop = $null
                $currentSub = $null
                continue
            }

            $currentTop = $title
            $currentSub = $null
            $result.Groups += [pscustomobject]@{
                TopLevel = $currentTop
                SubLevel = $null
                Line = Get-LineNumberForIndex -Index $i
            }
            continue
        }

        if ($line -match '^###\s+(?<title>.+)$') {
            $title = $Matches['title'].Trim()
            $currentSub = $title
            $result.Groups += [pscustomobject]@{
                TopLevel = $currentTop
                SubLevel = $currentSub
                Line = Get-LineNumberForIndex -Index $i
            }
            continue
        }

        if ($line -match '^####\s+\[(?<id>FI-[^\]]+)\]\s+(?<title>.+)$') {
            $entryStart = $i
            $entryId = $Matches['id']
            $entryTitle = $Matches['title'].Trim()

            $entryLines = @($line)
            $j = $i + 1
            for (; $j -lt $Lines.Length; $j++) {
                $next = $Lines[$j]
                if ($next -match '^####\s+\[' -or $next -match '^###\s+' -or $next -match '^##\s+') {
                    break
                }
                $entryLines += $next
            }

            $result.Entries += [pscustomobject]@{
                Id = $entryId
                Title = $entryTitle
                TopLevel = $currentTop
                SubLevel = $currentSub
                StartLine = Get-LineNumberForIndex -Index $entryStart
                Lines = $entryLines
            }

            $i = $j - 1
        }
    }

    return $result
}

function Get-FieldMap {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$EntryLines
    )

    $fields = @{}
    foreach ($line in $EntryLines) {
        if ($line -match '^(?<key>[A-Za-z][A-Za-z ]+):\s*(?<value>.*)$') {
            $key = $Matches['key'].Trim()
            $value = $Matches['value'].Trim()
            if (-not $fields.ContainsKey($key)) {
                $fields[$key] = $value
            }
        }
    }
    return $fields
}

function Get-SectionPresence {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$EntryLines,
        [Parameter(Mandatory = $true)][string]$Header
    )

    $index = -1
    for ($i = 0; $i -lt $EntryLines.Length; $i++) {
        if ($EntryLines[$i] -match "^$([regex]::Escape($Header)):\s*$") {
            $index = $i
            break
        }
    }

    if ($index -lt 0) {
        return [pscustomobject]@{ Found = $false; Items = @() }
    }

    $items = @()
    for ($j = $index + 1; $j -lt $EntryLines.Length; $j++) {
        $line = $EntryLines[$j]
        if ($line -match '^[A-Za-z][A-Za-z ]+:') {
            break
        }
        if ($line -match '^\-\s+') {
            $items += $line
        }
    }

    return [pscustomobject]@{ Found = $true; Items = $items }
}

Export-ModuleMember -Function *
