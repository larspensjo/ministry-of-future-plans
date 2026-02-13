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

function ConvertFrom-TagString {
    param(
        [Parameter(Mandatory = $false)][AllowNull()][AllowEmptyString()][string]$TagString
    )

    $trimmed = $TagString.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }

    if ($trimmed -match '^\[(?<inner>.*)\]$') {
        $inner = $Matches['inner']
    } else {
        $inner = $trimmed
    }

    if ([string]::IsNullOrWhiteSpace($inner)) {
        return @()
    }

    $tags = New-Object System.Collections.Generic.List[string]
    foreach ($part in ($inner -split ',')) {
        $tag = $part.Trim()
        if (-not [string]::IsNullOrWhiteSpace($tag)) {
            $tags.Add($tag)
        }
    }

    return @($tags)
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

    $startIndex = -1
    for ($i = 0; $i -lt $EntryLines.Length; $i++) {
        if ($EntryLines[$i] -match "^$([regex]::Escape($Header)):\s*$") {
            $startIndex = $i
            break
        }
    }

    if ($startIndex -lt 0) {
        return [pscustomobject]@{
            Found = $false
            Items = @()
            StartIndex = -1
            EndIndex = -1
            Start = -1
            End = -1
        }
    }

    $items = @()
    $endIndex = $startIndex
    for ($j = $startIndex + 1; $j -lt $EntryLines.Length; $j++) {
        $line = $EntryLines[$j]
        if ($line -match '^[A-Za-z][A-Za-z ]+:') {
            break
        }
        $endIndex = $j
        if ($line -match '^\-\s+') {
            $items += $line
        }
    }

    return [pscustomobject]@{
        Found = $true
        Items = $items
        StartIndex = $startIndex
        EndIndex = $endIndex
        Start = $startIndex
        End = $endIndex
    }
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

    function Get-LineNumberForIndex {
        param([int]$Index)
        if ($lineNumbers.ContainsKey($Index)) {
            return $lineNumbers[$Index]
        }
        return $Index + 1
    }

    function Parse-Origin {
        param([string[]]$EntryLines)

        $origin = Get-SectionPresence -EntryLines $EntryLines -Header 'Origin'
        $sourceDoc = $null
        $sourceSection = $null
        $capturedRaw = $null
        $captured = $null

        foreach ($item in $origin.Items) {
            if ($item -match '^\-\s+SourceDoc:\s*(?<value>.+)$') {
                $sourceDoc = $Matches['value'].Trim()
                continue
            }
            if ($item -match '^\-\s+SourceSection:\s*(?<value>.+)$') {
                $sourceSection = $Matches['value'].Trim()
                continue
            }
            if ($item -match '^\-\s+Captured:\s*(?<value>.+)$') {
                $capturedRaw = $Matches['value'].Trim()
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($capturedRaw)) {
            try {
                $captured = [datetime]::Parse($capturedRaw, [System.Globalization.CultureInfo]::InvariantCulture)
            } catch {
                $captured = $null
            }
        }

        return [pscustomobject]@{
            SourceDoc = $sourceDoc
            SourceSection = $sourceSection
            CapturedRaw = $capturedRaw
            Captured = $captured
        }
    }

    function Parse-SectionList {
        param(
            [string[]]$EntryLines,
            [string]$Header
        )

        $section = Get-SectionPresence -EntryLines $EntryLines -Header $Header
        if (-not $section.Found) {
            return @()
        }

        $values = New-Object System.Collections.Generic.List[string]
        foreach ($item in $section.Items) {
            if ($item -match '^\-\s*(?<value>.*)$') {
                $value = $Matches['value'].Trim()
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    $values.Add($value)
                }
            }
        }

        return @($values)
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

            $fieldMap = Get-FieldMap -EntryLines $entryLines
            $origin = Parse-Origin -EntryLines $entryLines
            $successCriteria = Parse-SectionList -EntryLines $entryLines -Header 'SuccessCriteria'

            $entry = [pscustomobject]@{
                Id = $entryId
                Title = $entryTitle
                TopLevel = $currentTop
                SubLevel = $currentSub
                Status = $fieldMap['Status']
                Priority = $fieldMap['Priority']
                Effort = $fieldMap['Effort']
                Risk = $fieldMap['Risk']
                Tags = @(ConvertFrom-TagString -TagString ($fieldMap['Tags']))
                Summary = $fieldMap['Summary']
                Rationale = $fieldMap['Rationale']
                Captured = $origin.Captured
                CapturedRaw = $origin.CapturedRaw
                OriginSourceDoc = $origin.SourceDoc
                OriginSection = $origin.SourceSection
                SuccessCriteria = @($successCriteria)
                Dependencies = @(ConvertFrom-TagString -TagString ($fieldMap['Dependencies']))
                Related = @(ConvertFrom-TagString -TagString ($fieldMap['Related']))
                Notes = $fieldMap['Notes']
                StartLine = Get-LineNumberForIndex -Index $entryStart
                LineNumber = Get-LineNumberForIndex -Index $entryStart
                RawLines = $entryLines
                Lines = $entryLines
            }

            $result.Entries += $entry
            $i = $j - 1
        }
    }

    return $result
}

Export-ModuleMember -Function *
