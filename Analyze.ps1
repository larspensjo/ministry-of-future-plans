#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analyzes an idea document and presents statistics.
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

$moduleDir = Join-Path $PSScriptRoot 'common'
$modulePath = Join-Path $moduleDir 'IdeaDocCore.psm1'
Import-Module $modulePath -Force

$resolvedPath = Resolve-IdeaDocPath -Path $IdeasPath
$lines = Read-TextLines -Path $resolvedPath
$doc = ConvertFrom-IdeaDoc -Lines $lines

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

foreach ($entry in $doc.Entries) {
    $stats.TotalIdeas++

    if (-not $stats.ByTopLevel.ContainsKey($entry.TopLevel)) {
        $stats.ByTopLevel[$entry.TopLevel] = 0
    }
    $stats.ByTopLevel[$entry.TopLevel]++

    $subLevelKey = "$($entry.TopLevel) > $($entry.SubLevel)"
    if (-not $stats.BySubLevel.ContainsKey($subLevelKey)) {
        $stats.BySubLevel[$subLevelKey] = 0
    }
    $stats.BySubLevel[$subLevelKey]++

    if ($entry.Status) {
        if (-not $stats.ByStatus.ContainsKey($entry.Status)) {
            $stats.ByStatus[$entry.Status] = 0
        }
        $stats.ByStatus[$entry.Status]++
    }

    if ($entry.Priority) {
        if (-not $stats.ByPriority.ContainsKey($entry.Priority)) {
            $stats.ByPriority[$entry.Priority] = 0
        }
        $stats.ByPriority[$entry.Priority]++
    }

    if ($entry.Effort) {
        if (-not $stats.ByEffort.ContainsKey($entry.Effort)) {
            $stats.ByEffort[$entry.Effort] = 0
        }
        $stats.ByEffort[$entry.Effort]++
    }

    if ($entry.Risk) {
        if (-not $stats.ByRisk.ContainsKey($entry.Risk)) {
            $stats.ByRisk[$entry.Risk] = 0
        }
        $stats.ByRisk[$entry.Risk]++
    }

    foreach ($tag in @($entry.Tags)) {
        if (-not [string]::IsNullOrWhiteSpace($tag)) {
            if (-not $stats.TagFrequency.ContainsKey($tag)) {
                $stats.TagFrequency[$tag] = 0
            }
            $stats.TagFrequency[$tag]++
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($entry.OriginSourceDoc)) {
        if (-not $stats.SourceDocuments.ContainsKey($entry.OriginSourceDoc)) {
            $stats.SourceDocuments[$entry.OriginSourceDoc] = 0
        }
        $stats.SourceDocuments[$entry.OriginSourceDoc]++
    }

    if (@($entry.Dependencies).Count -gt 0) {
        $stats.WithDependencies++
    }

    if (@($entry.SuccessCriteria).Count -eq 0) {
        $stats.WithoutSuccessCriteria++
    }

    if ($entry.Captured -is [datetime]) {
        $daysSince = ((Get-Date) - $entry.Captured).Days
        if ($daysSince -le 30) {
            $stats.RecentIdeas += [PSCustomObject]@{
                Id = $entry.Id
                TopLevel = $entry.TopLevel
                SubLevel = $entry.SubLevel
                Captured = $entry.Captured.ToString('yyyy-MM-dd')
                DaysAgo = $daysSince
            }
        }
    }
}

$stats.RecentIdeas = $stats.RecentIdeas | Sort-Object -Property DaysAgo

if ($OutputFormat -eq 'Json') {
    $stats | ConvertTo-Json -Depth 10
} else {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  IDEA DATABASE ANALYSIS" -ForegroundColor Cyan
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""

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

    Write-Host "BY TOP-LEVEL CATEGORY" -ForegroundColor Yellow
    $sortedTopLevel = $stats.ByTopLevel.GetEnumerator() | Sort-Object -Property Value -Descending
    foreach ($item in $sortedTopLevel) {
        $bar = "#" * [Math]::Min(50, [Math]::Floor($item.Value / $stats.TotalIdeas * 50))
        $line = '  {0,-30} {1,4} {2}' -f $item.Key, $item.Value, $bar
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    Write-Host "BY STATUS" -ForegroundColor Yellow
    $sortedStatus = $stats.ByStatus.GetEnumerator() | Sort-Object -Property Value -Descending
    foreach ($item in $sortedStatus) {
        $percentage = [Math]::Round($item.Value / $stats.TotalIdeas * 100, 1)
        $line = '  {0,-20} {1,4} ({2,5}%)' -f $item.Key, $item.Value, $percentage
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    Write-Host "BY PRIORITY" -ForegroundColor Yellow
    $priorityOrder = @('P0', 'P1', 'P2', 'P3')
    foreach ($p in $priorityOrder) {
        if ($stats.ByPriority.ContainsKey($p)) {
            $count = $stats.ByPriority[$p]
            $percentage = [Math]::Round($count / $stats.TotalIdeas * 100, 1)
            $line = '  {0,-20} {1,4} ({2,5}%)' -f $p, $count, $percentage
            Write-Host $line -ForegroundColor White
        }
    }
    Write-Host ""

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

    Write-Host "TOP $Top TAGS" -ForegroundColor Yellow
    $topTags = $stats.TagFrequency.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $Top
    foreach ($item in $topTags) {
        $percentage = [Math]::Round($item.Value / $stats.TotalIdeas * 100, 1)
        $line = '  {0,-30} {1,4} ({2,5}%)' -f $item.Key, $item.Value, $percentage
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    Write-Host "TOP SOURCE DOCUMENTS" -ForegroundColor Yellow
    $topSources = $stats.SourceDocuments.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $Top
    foreach ($item in $topSources) {
        $line = '  {0,-50} {1,4}' -f $item.Key, $item.Value
        Write-Host $line -ForegroundColor White
    }
    Write-Host ""

    Write-Host "ADDITIONAL METRICS" -ForegroundColor Yellow
    $line1 = '  Ideas with Dependencies: {0,4}' -f $stats.WithDependencies
    Write-Host $line1 -ForegroundColor White
    $line2 = '  Ideas without SuccessCriteria: {0,4}' -f $stats.WithoutSuccessCriteria
    Write-Host $line2 -ForegroundColor White
    Write-Host ""

    if ($stats.RecentIdeas.Count -gt 0) {
        Write-Host "RECENT IDEAS (Last 30 days)" -ForegroundColor Yellow
        foreach ($idea in $stats.RecentIdeas) {
            $color = if ($idea.DaysAgo -eq 0) { "Green" } elseif ($idea.DaysAgo -le 7) { "Cyan" } else { "White" }
            $line = '  {0,-45} {1,2} days ago  ({2} > {3})' -f $idea.Id, $idea.DaysAgo, $idea.TopLevel, $idea.SubLevel
            Write-Host $line -ForegroundColor $color
        }
        Write-Host ""
    }

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
