[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$IdeasPath,
    [Parameter()][string]$InstructionPath = "${PSScriptRoot}\Instruction.HarvestFutureIdeas.md",
    [Parameter()][ValidateSet('Text','Json')][string]$OutputFormat = 'Text'
)

$ErrorActionPreference = 'Stop'

Import-Module -Name "${PSScriptRoot}\common\IdeaDocCore.psm1" -Force

$resolvedIdeasPath = Resolve-IdeaDocPath -Path $IdeasPath
$resolvedInstructionPath = Resolve-IdeaDocPath -Path $InstructionPath

$lines = Read-TextLines -Path $resolvedIdeasPath
if ($lines -is [string]) {
    $lines = @($lines)
}
if ($null -eq $lines) {
    $lines = @()
}
$doc = ConvertFrom-IdeaDoc -Lines $lines
$violations = New-Object System.Collections.Generic.List[object]

function Add-Violation {
    param([string]$Code, [string]$Message, [int]$Line)
    $violations.Add((New-Violation -Code $Code -Message $Message -Line $Line)) | Out-Null
}

# Taxonomy at top
if (-not $doc.TaxonomyLine) {
    Add-Violation -Code 'taxonomy.missing' -Message 'Missing "## Taxonomy" section.' -Line 1
}

$firstTopLevel = $doc.Groups | Where-Object { $_.SubLevel -eq $null -and $_.TopLevel -ne 'Taxonomy' } | Select-Object -First 1
if ($doc.TaxonomyLine -and $firstTopLevel -and $doc.TaxonomyLine -gt $firstTopLevel.Line) {
    Add-Violation -Code 'taxonomy.order' -Message '"## Taxonomy" must appear before idea groups.' -Line $doc.TaxonomyLine
}

# Header hierarchy
foreach ($group in $doc.Groups) {
    if ($group.SubLevel -and -not $group.TopLevel) {
        Add-Violation -Code 'header.missingTop' -Message "SubLevel header without a TopLevel: $($group.SubLevel)" -Line $group.Line
    }
}

# Sorting by TopLevel then SubLevel
$sortedGroups = $doc.Groups | Where-Object { $_.TopLevel -and $_.SubLevel } | ForEach-Object {
    [pscustomobject]@{
        Key = "$($_.TopLevel)|$($_.SubLevel)"
        TopLevel = $_.TopLevel
        SubLevel = $_.SubLevel
        Line = $_.Line
    }
}

$expected = $sortedGroups | Sort-Object TopLevel, SubLevel
for ($i = 0; $i -lt $sortedGroups.Count; $i++) {
    if ($sortedGroups[$i].TopLevel -ne $expected[$i].TopLevel -or $sortedGroups[$i].SubLevel -ne $expected[$i].SubLevel) {
        Add-Violation -Code 'order.group' -Message "Groups are not sorted by TopLevel/SubLevel. Expected '$($expected[$i].TopLevel) > $($expected[$i].SubLevel)' here." -Line $sortedGroups[$i].Line
        break
    }
}

# Entry checks
$requiredFields = @('Status','TopLevel','SubLevel','Priority','Effort','Risk','Origin','Tags','Summary','Rationale')
foreach ($entry in $doc.Entries) {
    if (-not $entry.TopLevel -or -not $entry.SubLevel) {
        Add-Violation -Code 'entry.headerContext' -Message "Entry $($entry.Id) must be under TopLevel/SubLevel headers." -Line $entry.StartLine
        continue
    }

    $fieldMap = Get-FieldMap -EntryLines $entry.Lines
    foreach ($field in $requiredFields) {
        if (-not $fieldMap.ContainsKey($field)) {
            Add-Violation -Code 'entry.missingField' -Message "Entry $($entry.Id) missing field: $field" -Line $entry.StartLine
        }
    }

    if ($fieldMap.ContainsKey('TopLevel') -and $fieldMap['TopLevel'] -ne $entry.TopLevel) {
        Add-Violation -Code 'entry.topMismatch' -Message "Entry $($entry.Id) TopLevel field does not match header ($($entry.TopLevel))." -Line $entry.StartLine
    }

    if ($fieldMap.ContainsKey('SubLevel') -and $fieldMap['SubLevel'] -ne $entry.SubLevel) {
        Add-Violation -Code 'entry.subMismatch' -Message "Entry $($entry.Id) SubLevel field does not match header ($($entry.SubLevel))." -Line $entry.StartLine
    }

    $origin = Get-SectionPresence -EntryLines $entry.Lines -Header 'Origin'
    if ($origin.Found) {
        if (-not ($origin.Items | Where-Object { $_ -match '^-\s+SourceDoc:' })) {
            Add-Violation -Code 'origin.sourceDoc' -Message "Entry $($entry.Id) Origin must include SourceDoc." -Line $entry.StartLine
        }
        if (-not ($origin.Items | Where-Object { $_ -match '^-\s+SourceSection:' })) {
            Add-Violation -Code 'origin.sourceSection' -Message "Entry $($entry.Id) Origin must include SourceSection." -Line $entry.StartLine
        }
        if (-not ($origin.Items | Where-Object { $_ -match '^-\s+Captured:' })) {
            Add-Violation -Code 'origin.captured' -Message "Entry $($entry.Id) Origin must include Captured date." -Line $entry.StartLine
        }
    }

    $criteria = Get-SectionPresence -EntryLines $entry.Lines -Header 'SuccessCriteria'
    if ($criteria.Found -and $criteria.Items.Count -eq 0) {
        Add-Violation -Code 'successCriteria.empty' -Message "Entry $($entry.Id) SuccessCriteria must include at least one bullet." -Line $entry.StartLine
    }
}

# Output
if ($OutputFormat -eq 'Json') {
    $violations | ConvertTo-Json -Depth 5
} else {
    if ($violations.Count -eq 0) {
        Write-Output 'OK: No violations found.'
    } else {
        foreach ($v in $violations) {
            Write-Output ("[$($v.Code)] Line $($v.Line): $($v.Message)")
        }
        Write-Output ("Total violations: $($violations.Count)")
    }
}

if ($violations.Count -gt 0) {
    exit 1
}
