#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analyzes an idea document and presents statistics.

.DESCRIPTION
    Parses an idea document (typically FutureIdeas.md) and generates statistics
    including counts by category, status, priority, effort, risk, tags, and more.

.PARAMETER IdeasPath
    Path to the ideas document to analyze (e.g., docs/FutureIdeas.md).

.PARAMETER OutputFormat
    Output format: Text (human-readable) or Json. Default: Text.

.PARAMETER Top
    Number of top items to show for ranked lists (e.g., top tags). Default: 10.

.EXAMPLE
    .\IdeasDatabaseManagement\Analyze-IdeaDoc.ps1 -IdeasPath .\docs\FutureIdeas.md

.EXAMPLE
    .\IdeasDatabaseManagement\Analyze-IdeaDoc.ps1 -IdeasPath .\docs\FutureIdeas.md -OutputFormat Json
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$IdeasPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Text', 'Json')]
    [string]$OutputFormat = 'Text',

    [Parameter(Mandatory=$false)]
    [int]$Top = 10
)

$ErrorActionPreference = 'Stop'

# Import the core module
$moduleDir = Join-Path $PSScriptRoot 'common'
$modulePath = Join-Path $moduleDir 'IdeaDocCore.psm1'
Import-Module $modulePath -Force

# Resolve and read the document
$resolvedPath = Resolve-IdeaDocPath -Path $IdeasPath
$lines = Read-TextLines -Path $resolvedPath
$doc = ConvertFrom-IdeaDoc -Lines $lines


# Calculate statistics
$stats = @{
    TotalIdeas = 0
    ByTopLevel = @{}
    BySubLevel = @{}
    ByStatus = @{}
    ByPriority = @{}
    ByEffort = @{}
    ByRisk = @{}
    TagFrequency = @{}
    SourceDocuments = @{}
    WithDependencies = 0
    WithoutSuccessCriteria = 0
    RecentIdeas = @()
}

# Process each entry
foreach ($entry in $doc.Entries) {
    $stats.TotalIdeas++

    $topLevel = $entry.TopLevel
    $subLevel = $entry.SubLevel

    # Initialize counters
    if (-not $stats.ByTopLevel.ContainsKey($topLevel)) {
        $stats.ByTopLevel[$topLevel] = 0
    }
    $stats.ByTopLevel[$topLevel]++

    $subLevelKey = "$topLevel > $subLevel"
    if (-not $stats.BySubLevel.ContainsKey($subLevelKey)) {
        $stats.BySubLevel[$subLevelKey] = 0
    }
    $stats.BySubLevel[$subLevelKey]++

    $fields = Get-FieldMap -EntryLines $entry.Lines

        # Status
        $status = $fields['Status']
        if ($status) {
            if (-not $stats.ByStatus.ContainsKey($status)) {
                $stats.ByStatus[$status] = 0
            }
            $stats.ByStatus[$status]++
        }

        # Priority
        $priority = $fields['Priority']
        if ($priority) {
            if (-not $stats.ByPriority.ContainsKey($priority)) {
                $stats.ByPriority[$priority] = 0
            }
            $stats.ByPriority[$priority]++
        }

        # Effort
        $effort = $fields['Effort']
        if ($effort) {
            if (-not $stats.ByEffort.ContainsKey($effort)) {
                $stats.ByEffort[$effort] = 0
            }
            $stats.ByEffort[$effort]++
        }

        # Risk
        $risk = $fields['Risk']
        if ($risk) {
            if (-not $stats.ByRisk.ContainsKey($risk)) {
                $stats.ByRisk[$risk] = 0
            }
            $stats.ByRisk[$risk]++
        }

        # Tags
        $tagsLine = $fields['Tags']
        if ($tagsLine) {
            # Extract tags from [tag1, tag2, tag3] format
            if ($tagsLine -match '\[(.*?)\]') {
                $tagsList = $matches[1] -split ',\s*'
                foreach ($tag in $tagsList) {
                    $tag = $tag.Trim()
                    if ($tag) {
                        if (-not $stats.TagFrequency.ContainsKey($tag)) {
                            $stats.TagFrequency[$tag] = 0
                        }
                        $stats.TagFrequency[$tag]++
                    }
                }
            }
        }

    # Origin - SourceDoc
    $origin = Get-SectionPresence -EntryLines $entry.Lines -Header 'Origin'
    if ($origin) {
        foreach ($line in $entry.Lines[$origin.Start..$origin.End]) {
            if ($line -match '^\s*-\s*SourceDoc:\s*(.+)$') {
                $sourceDoc = $matches[1].Trim()
                if (-not $stats.SourceDocuments.ContainsKey($sourceDoc)) {
                    $stats.SourceDocuments[$sourceDoc] = 0
                }
                $stats.SourceDocuments[$sourceDoc]++
                break
            }
        }
    }

    # Dependencies
    $dependencies = $fields['Dependencies']
    if ($dependencies) {
        $stats.WithDependencies++
    }

    # SuccessCriteria
    $criteria = Get-SectionPresence -EntryLines $entry.Lines -Header 'SuccessCriteria'
    if (-not $criteria) {
        $stats.WithoutSuccessCriteria++
    }

    # Recent ideas (captured in last 30 days)
    $captured = $fields['Captured']
    if ($captured) {
        try {
            $capturedDate = [DateTime]::Parse($captured)
            $daysSince = ((Get-Date) - $capturedDate).Days
            if ($daysSince -le 30) {
                $stats.RecentIdeas += [PSCustomObject]@{
                    Id = $entry.Id
                    TopLevel = $topLevel
                    SubLevel = $subLevel
                    Captured = $captured
                    DaysAgo = $daysSince
                }
            }
        }
        catch {
            # Ignore parse errors
        }
    }
}

# Sort recent ideas by date (most recent first)
$stats.RecentIdeas = $stats.RecentIdeas | Sort-Object -Property DaysAgo

# Output results
if ($OutputFormat -eq 'Json') {
    $stats | ConvertTo-Json -Depth 10
}
else {
    # Text output
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  IDEA DATABASE ANALYSIS" -ForegroundColor Cyan
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""

    # Overview
    Write-Host "OVERVIEW" -ForegroundColor Yellow
    Write-Host "  Total Ideas: $($stats.TotalIdeas)" -ForegroundColor White
    Write-Host "  Top-Level Categories: $($stats.ByTopLevel.Count)" -ForegroundColor White
    Write-Host "  Sub-Level Categories: $($stats.BySubLevel.Count)" -ForegroundColor White
    Write-Host "  Unique Tags: $($stats.TagFrequency.Count)" -ForegroundColor White
    Write-Host "  Source Documents: $($stats.SourceDocuments.Count)" -ForegroundColor White
    Write-Host ""

    if ($stats.TotalIdeas -eq 0) {
        Write-Host "No ideas found in the document." -ForegroundColor Red
        Write-Host ""
        return
    }

    # By Top-Level Category
    Write-Host "BY TOP-LEVEL CATEGORY" -ForegroundColor Yellow
    $sortedTopLevel = $stats.ByTopLevel.GetEnumerator() | Sort-Object -Property Value -Descending
    foreach ($item in $sortedTopLevel) {
        $bar = "#" * [Math]::Min(50, [Math]::Floor($item.Value / $stats.TotalIdeas * 50))
        $line = '  {0,-30} {1,4} {2}' -f $item.Key, $item.Value, $bar
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    # By Status
    Write-Host "BY STATUS" -ForegroundColor Yellow
    $sortedStatus = $stats.ByStatus.GetEnumerator() | Sort-Object -Property Value -Descending
    foreach ($item in $sortedStatus) {
        $percentage = [Math]::Round($item.Value / $stats.TotalIdeas * 100, 1)
        $line = '  {0,-20} {1,4} ({2,5}%)' -f $item.Key, $item.Value, $percentage
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    # By Priority
    Write-Host "BY PRIORITY" -ForegroundColor Yellow
    $priorityOrder = @('P1', 'P2', 'P3', 'P4')
    foreach ($p in $priorityOrder) {
        if ($stats.ByPriority.ContainsKey($p)) {
            $count = $stats.ByPriority[$p]
            $percentage = [Math]::Round($count / $stats.TotalIdeas * 100, 1)
            $line = '  {0,-20} {1,4} ({2,5}%)' -f $p, $count, $percentage
            Write-Host $line -ForegroundColor White
        }
    }
    Write-Host ""

    # By Effort
    Write-Host "BY EFFORT" -ForegroundColor Yellow
    $effortOrder = @('S', 'M', 'L', 'XL')
    foreach ($e in $effortOrder) {
        if ($stats.ByEffort.ContainsKey($e)) {
            $count = $stats.ByEffort[$e]
            $percentage = [Math]::Round($count / $stats.TotalIdeas * 100, 1)
            $line = '  {0,-20} {1,4} ({2,5}%)' -f $e, $count, $percentage
            Write-Host $line -ForegroundColor White
        }
    }
    Write-Host ""

    # By Risk
    Write-Host "BY RISK" -ForegroundColor Yellow
    $riskOrder = @('L', 'M', 'H')
    foreach ($r in $riskOrder) {
        if ($stats.ByRisk.ContainsKey($r)) {
            $count = $stats.ByRisk[$r]
            $percentage = [Math]::Round($count / $stats.TotalIdeas * 100, 1)
            $line = '  {0,-20} {1,4} ({2,5}%)' -f $r, $count, $percentage
            Write-Host $line -ForegroundColor White
        }
    }
    Write-Host ""

    # Top Tags
    Write-Host "TOP $Top TAGS" -ForegroundColor Yellow
    $topTags = $stats.TagFrequency.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $Top
    foreach ($item in $topTags) {
        $percentage = [Math]::Round($item.Value / $stats.TotalIdeas * 100, 1)
        $line = '  {0,-30} {1,4} ({2,5}%)' -f $item.Key, $item.Value, $percentage
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    # Top Source Documents
    Write-Host "TOP SOURCE DOCUMENTS" -ForegroundColor Yellow
    $topSources = $stats.SourceDocuments.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $Top
    foreach ($item in $topSources) {
        $line = '  {0,-50} {1,4}' -f $item.Key, $item.Value
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    # Additional Metrics
    Write-Host "ADDITIONAL METRICS" -ForegroundColor Yellow
    $line1 = '  Ideas with Dependencies: {0,4}' -f $stats.WithDependencies
    Write-Host $line1 -ForegroundColor White
    $line2 = '  Ideas without SuccessCriteria: {0,4}' -f $stats.WithoutSuccessCriteria
    Write-Host $line2 -ForegroundColor White
    Write-Host ""

    # Recent Ideas (last 30 days)
    if ($stats.RecentIdeas.Count -gt 0) {
        Write-Host "RECENT IDEAS (Last 30 days)" -ForegroundColor Yellow
        foreach ($idea in $stats.RecentIdeas) {
            $color = if ($idea.DaysAgo -eq 0) { "Green" } elseif ($idea.DaysAgo -le 7) { "Cyan" } else { "White" }
            $line = '  {0,-45} {1,2} days ago  ({2} > {3})' -f $idea.Id, $idea.DaysAgo, $idea.TopLevel, $idea.SubLevel
            Write-Host $line -ForegroundColor $color
        }
        Write-Host ""
    }

    # Busiest Sub-Level Categories
    Write-Host "TOP $Top BUSIEST SUB-LEVEL CATEGORIES" -ForegroundColor Yellow
    $topSubLevels = $stats.BySubLevel.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $Top
    foreach ($item in $topSubLevels) {
        $line = '  {0,-50} {1,4}' -f $item.Key, $item.Value
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""
}
