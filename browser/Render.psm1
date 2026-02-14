Set-StrictMode -Version Latest

$SCROLLBAR_THUMB_GLYPH = '░'
$SCROLLBAR_TRACK_GLYPH = '│'

function Get-PropertyValueOrDefault {
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()]$Default = ''
    )

    if ($null -eq $Object) {
        return $Default
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name) -and $null -ne $Object[$Name]) {
            return $Object[$Name]
        }
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    return $property.Value
}

function Get-IdeaById {
    param(
        [Parameter(Mandatory = $true)][object[]]$Ideas,
        [Parameter(Mandatory = $true)][string]$Id
    )

    return $Ideas | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

function Get-VisibleTagByIndex {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][int]$TagIndex
    )

    if ($TagIndex -lt 0 -or $TagIndex -ge $State.Derived.VisibleTags.Count) {
        return $null
    }

    return $State.Derived.VisibleTags[$TagIndex]
}

function Write-TruncatedLine {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][int]$Width
    )

    if ($Width -le 0) {
        return ''
    }

    if ($Text.Length -le $Width) {
        return $Text.PadRight($Width)
    }

    if ($Width -le 3) {
        return $Text.Substring(0, $Width)
    }

    return $Text.Substring(0, $Width - 3) + '...'
}

function Get-PriorityColor {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Priority)

    switch ($Priority) {
        'P0' { return 'Red' }
        'P1' { return 'Red' }
        'P2' { return 'Yellow' }
        'P3' { return 'DarkCyan' }
        default { return 'Gray' }
    }
}

function Get-RiskColor {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Risk)

    switch ($Risk) {
        'H' { return 'Red' }
        'M' { return 'Yellow' }
        'L' { return 'DarkGray' }
        default { return 'Gray' }
    }
}

function Get-MarkerColor {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Marker)

    switch ($Marker) {
        '>' { return 'Cyan' }
        $SCROLLBAR_THUMB_GLYPH { return 'Gray' }
        $SCROLLBAR_TRACK_GLYPH { return 'DarkGray' }
        default { return 'DarkGray' }
    }
}

function Write-ColorSegments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Segments,
        [Parameter(Mandatory = $true)][int]$Width,
        [switch]$NoNewline,
        [AllowEmptyString()][string]$BackgroundColor,
        [switch]$NoEmit
    )

    if ($Width -le 0) {
        if ($NoEmit) {
            Write-Output -NoEnumerate @()
        }
        return
    }

    $normalizedSegments = @()
    $remaining = $Width
    $segmentItems = @($Segments)

    foreach ($segment in $segmentItems) {
        if ($remaining -le 0) {
            break
        }

        $text = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Text' -Default '')
        if ($text.Length -eq 0) {
            continue
        }

        $color = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Color' -Default 'Gray')
        if ([string]::IsNullOrWhiteSpace($color)) {
            $color = 'Gray'
        }

        if ($text.Length -le $remaining) {
            $normalizedSegments += @{ Text = $text; Color = $color }
            $remaining -= $text.Length
            continue
        }

        $normalizedSegments += @{
            Text = (Write-TruncatedLine -Text $text -Width $remaining)
            Color = $color
        }
        $remaining = 0
    }

    if ($remaining -gt 0) {
        $normalizedSegments += @{ Text = (' ' * $remaining); Color = 'Gray' }
    }

    if ($NoEmit) {
        Write-Output -NoEnumerate $normalizedSegments
        return
    }

    foreach ($segment in $normalizedSegments) {
        $writeArgs = @{
            Object = $segment.Text
            ForegroundColor = $segment.Color
            NoNewline = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($BackgroundColor)) {
            $writeArgs['BackgroundColor'] = $BackgroundColor
        }
        Write-Host @writeArgs
    }

    if (-not $NoNewline) {
        Write-Host ''
    }
}

function Get-ScrollThumb {
    param(
        [Parameter(Mandatory = $true)][int]$TotalItems,
        [Parameter(Mandatory = $true)][int]$ViewRows,
        [Parameter(Mandatory = $true)][int]$ScrollTop
    )

    if ($ViewRows -le 0 -or $TotalItems -le $ViewRows) {
        return $null
    }

    $thumbSize = [Math]::Max(1, [Math]::Floor(($ViewRows * $ViewRows) / $TotalItems))
    if ($thumbSize -gt $ViewRows) {
        $thumbSize = $ViewRows
    }

    $maxScrollTop = [Math]::Max(0, $TotalItems - $ViewRows)
    $safeScrollTop = [Math]::Max(0, [Math]::Min($maxScrollTop, $ScrollTop))
    $trackSpace = [Math]::Max(0, $ViewRows - $thumbSize)

    $thumbStart = 0
    if ($trackSpace -gt 0 -and $maxScrollTop -gt 0) {
        $thumbStart = [Math]::Floor(($safeScrollTop * $trackSpace) / $maxScrollTop)
    }
    $thumbStart = [Math]::Max(0, [Math]::Min($trackSpace, $thumbStart))
    $thumbEnd = [Math]::Min($ViewRows - 1, $thumbStart + $thumbSize - 1)

    return [pscustomobject]@{
        Start = $thumbStart
        End = $thumbEnd
        Size = $thumbSize
    }
}

function Get-TagRowModel {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][int]$TagIndex,
        [Parameter(Mandatory = $true)][int]$TagRowOffset,
        [AllowNull()]$TagThumb
    )

    $tagText = ''
    $tagColor = 'Gray'
    $tagMarker = ' '
    $tagItem = Get-VisibleTagByIndex -State $State -TagIndex $TagIndex

    if ($null -ne $tagItem) {
        if ($State.Cursor.TagIndex -eq $TagIndex) {
            $tagMarker = '>'
        } elseif ($null -ne $TagThumb) {
            if ($TagRowOffset -ge $TagThumb.Start -and $TagRowOffset -le $TagThumb.End) {
                $tagMarker = $SCROLLBAR_THUMB_GLYPH
            } else {
                $tagMarker = $SCROLLBAR_TRACK_GLYPH
            }
        }

        $isSelected = [bool](Get-PropertyValueOrDefault -Object $tagItem -Name 'IsSelected' -Default $false)
        $isSelectable = [bool](Get-PropertyValueOrDefault -Object $tagItem -Name 'IsSelectable' -Default $true)
        $tagName = [string](Get-PropertyValueOrDefault -Object $tagItem -Name 'Name' -Default '')
        $tagMatchCount = [string](Get-PropertyValueOrDefault -Object $tagItem -Name 'MatchCount' -Default '')
        $mark = if ($isSelected) { '[x]' } else { '[ ]' }
        $tagText = "$tagMarker $mark $tagName ($tagMatchCount)"

        if (-not $isSelectable -and -not $isSelected) {
            $tagColor = 'DarkGray'
        } elseif ($isSelected) {
            $tagColor = 'Green'
        }
    } elseif ($null -ne $TagThumb) {
        if ($TagRowOffset -ge $TagThumb.Start -and $TagRowOffset -le $TagThumb.End) {
            $tagMarker = $SCROLLBAR_THUMB_GLYPH
        } else {
            $tagMarker = $SCROLLBAR_TRACK_GLYPH
        }
        $tagText = $tagMarker
        $tagColor = 'DarkGray'
    }

    return [pscustomobject]@{
        Text = $tagText
        Color = $tagColor
        Marker = $tagMarker
    }
}

function Build-TagSegments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$TagText,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$TagMarker,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$TagColor
    )

    if ($TagText.Length -eq 0) {
        Write-Output -NoEnumerate @()
        return
    }

    $markerLength = [Math]::Max(0, [Math]::Min($TagText.Length, $TagMarker.Length))
    if ($markerLength -le 0) {
        Write-Output -NoEnumerate @(
            @{ Text = $TagText; Color = $TagColor }
        )
        return
    }

    $restText = $TagText.Substring($markerLength)
    $segments = @(
        @{ Text = $TagText.Substring(0, $markerLength); Color = (Get-MarkerColor -Marker $TagMarker) }
    )

    if ($restText.Length -gt 0) {
        $segments += @{ Text = $restText; Color = $TagColor }
    }

    Write-Output -NoEnumerate $segments
}

function Build-IdeaSegments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Marker,
        [AllowNull()]$Idea,
        [Parameter(Mandatory = $true)][bool]$IsSelected
    )

    if ($null -eq $Idea) {
        if ([string]::IsNullOrEmpty($Marker) -or $Marker -eq ' ') {
            Write-Output -NoEnumerate @()
            return
        }
        Write-Output -NoEnumerate @(
            @{ Text = $Marker; Color = (Get-MarkerColor -Marker $Marker) }
        )
        return
    }

    $ideaId = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Id' -Default '')
    $ideaTitle = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Title' -Default '')

    $markerColor = if ($IsSelected) { 'Cyan' } else { Get-MarkerColor -Marker $Marker }
    $titleColor = if ($IsSelected) { 'White' } else { 'Gray' }

    $segments = @(
        @{ Text = $Marker; Color = $markerColor },
        @{ Text = " $ideaId"; Color = 'DarkGray' }
    )

    if ($ideaTitle.Length -gt 0) {
        $segments += @{ Text = " $ideaTitle"; Color = $titleColor }
    }

    Write-Output -NoEnumerate $segments
}

function Build-DetailSegments {
    param([AllowNull()]$Idea)

    if ($null -eq $Idea) {
        Write-Output -NoEnumerate @(
            @(
                @{ Text = 'No matching ideas'; Color = 'DarkGray' }
            )
        )
        return
    }

    $ideaId = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Id' -Default '')
    $priority = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Priority' -Default '')
    $effort = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Effort' -Default '')
    $risk = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Risk' -Default '')
    $summary = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Summary' -Default '')
    $rationale = [string](Get-PropertyValueOrDefault -Object $Idea -Name 'Rationale' -Default '')
    $tagsRaw = Get-PropertyValueOrDefault -Object $Idea -Name 'Tags' -Default @()
    $tags = @($tagsRaw | ForEach-Object { [string]$_ })
    $tagsText = $tags -join ', '

    Write-Output -NoEnumerate @(
        @(
            @{ Text = 'ID: '; Color = 'DarkYellow' },
            @{ Text = $ideaId; Color = 'DarkGray' }
        ),
        @(
            @{ Text = 'Priority: '; Color = 'DarkYellow' },
            @{ Text = $priority; Color = (Get-PriorityColor -Priority $priority) },
            @{ Text = '  Effort: '; Color = 'DarkYellow' },
            @{ Text = $effort; Color = 'Gray' },
            @{ Text = '  Risk: '; Color = 'DarkYellow' },
            @{ Text = $risk; Color = (Get-RiskColor -Risk $risk) }
        ),
        @(
            @{ Text = 'Tags: '; Color = 'DarkYellow' },
            @{ Text = $tagsText; Color = 'Gray' }
        ),
        @(
            @{ Text = ''; Color = 'Gray' }
        ),
        @(
            @{ Text = 'Summary: '; Color = 'DarkYellow' },
            @{ Text = $summary; Color = 'Gray' }
        ),
        @(
            @{ Text = 'Rationale: '; Color = 'DarkYellow' },
            @{ Text = $rationale; Color = 'Gray' }
        )
    )
}

function Render-BrowserState {
    param(
        [Parameter(Mandatory = $true)]$State
    )

    $layout = $State.Ui.Layout

    try { [Console]::CursorVisible = $false } catch {}
    try { [Console]::SetCursorPosition(0, 0) } catch {}
    Clear-Host

    if ($layout.Mode -eq 'TooSmall') {
        Write-Host ("Window too small. Need at least {0}x{1}." -f $layout.MinWidth, $layout.MinHeight) -ForegroundColor Yellow
        Write-Host "Resize window. Press Q to quit." -ForegroundColor Yellow
        return
    }

    $topRows = [Math]::Max(0, $layout.ListPane.H - 1)
    $detailRows = [Math]::Max(0, $layout.DetailPane.H - 1)
    $tagRowOffset = 0
    $tagViewRows = [Math]::Max(1, $layout.TagPane.H - 2)
    $ideaViewRows = [Math]::Max(1, $layout.ListPane.H - 1)
    $tagThumb = Get-ScrollThumb -TotalItems $State.Derived.VisibleTags.Count -ViewRows $tagViewRows -ScrollTop $State.Cursor.TagScrollTop
    $ideaThumb = Get-ScrollThumb -TotalItems $State.Derived.VisibleIdeaIds.Count -ViewRows $ideaViewRows -ScrollTop $State.Cursor.IdeaScrollTop

    $detailSegments = @()
    if ($State.Derived.VisibleIdeaIds.Count -eq 0) {
        $detailSegments = Build-DetailSegments -Idea $null
    } else {
        $selectedId = $State.Derived.VisibleIdeaIds[[Math]::Min($State.Cursor.IdeaIndex, $State.Derived.VisibleIdeaIds.Count - 1)]
        $selectedIdea = Get-IdeaById -Ideas $State.Data.AllIdeas -Id $selectedId
        $detailSegments = Build-DetailSegments -Idea $selectedIdea
    }

    $tagHeaderColor = if ($State.Ui.ActivePane -eq 'Tags') { 'Cyan' } else { 'DarkGray' }
    $ideaHeaderColor = if ($State.Ui.ActivePane -eq 'Ideas') { 'Cyan' } else { 'DarkGray' }
    Write-Host (Write-TruncatedLine -Text '[Tags]' -Width $layout.TagPane.W) -ForegroundColor $tagHeaderColor -NoNewline
    Write-Host ' ' -NoNewline
    Write-Host (Write-TruncatedLine -Text '[Ideas]' -Width $layout.ListPane.W) -ForegroundColor $ideaHeaderColor

    for ($row = 0; $row -lt $topRows; $row++) {
        $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
        $tagRow = Get-TagRowModel -State $State -TagIndex $tagIndex -TagRowOffset $tagRowOffset -TagThumb $tagThumb
        $tagSegments = Build-TagSegments -TagText $tagRow.Text -TagMarker $tagRow.Marker -TagColor $tagRow.Color

        $ideaMarker = ' '
        $ideaIndex = $State.Cursor.IdeaScrollTop + $row
        $idea = $null
        if ($ideaIndex -lt $State.Derived.VisibleIdeaIds.Count) {
            $ideaId = $State.Derived.VisibleIdeaIds[$ideaIndex]
            $idea = Get-IdeaById -Ideas $State.Data.AllIdeas -Id $ideaId
            if ($State.Cursor.IdeaIndex -eq $ideaIndex) {
                $ideaMarker = '>'
            } elseif ($null -ne $ideaThumb) {
                if ($row -ge $ideaThumb.Start -and $row -le $ideaThumb.End) {
                    $ideaMarker = $SCROLLBAR_THUMB_GLYPH
                } else {
                    $ideaMarker = $SCROLLBAR_TRACK_GLYPH
                }
            }
        } elseif ($null -ne $ideaThumb) {
            if ($row -ge $ideaThumb.Start -and $row -le $ideaThumb.End) {
                $ideaMarker = $SCROLLBAR_THUMB_GLYPH
            } else {
                $ideaMarker = $SCROLLBAR_TRACK_GLYPH
            }
        }

        $isSelectedIdea = ($ideaIndex -lt $State.Derived.VisibleIdeaIds.Count -and $State.Cursor.IdeaIndex -eq $ideaIndex -and $null -ne $idea)
        $ideaSegments = Build-IdeaSegments -Marker $ideaMarker -Idea $idea -IsSelected $isSelectedIdea

        Write-ColorSegments -Segments $tagSegments -Width $layout.TagPane.W -NoNewline
        Write-Host ' ' -NoNewline
        if ($isSelectedIdea) {
            Write-ColorSegments -Segments $ideaSegments -Width $layout.ListPane.W -BackgroundColor 'DarkCyan'
        } else {
            Write-ColorSegments -Segments $ideaSegments -Width $layout.ListPane.W
        }
        $tagRowOffset++
    }

    $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
    $tagRow = Get-TagRowModel -State $State -TagIndex $tagIndex -TagRowOffset $tagRowOffset -TagThumb $tagThumb
    $tagSegments = Build-TagSegments -TagText $tagRow.Text -TagMarker $tagRow.Marker -TagColor $tagRow.Color
    Write-ColorSegments -Segments $tagSegments -Width $layout.TagPane.W -NoNewline
    Write-Host ' ' -NoNewline
    Write-Host (Write-TruncatedLine -Text '[Details]' -Width $layout.DetailPane.W) -ForegroundColor DarkGray
    $tagRowOffset++

    for ($row = 0; $row -lt $detailRows; $row++) {
        $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
        $tagRow = Get-TagRowModel -State $State -TagIndex $tagIndex -TagRowOffset $tagRowOffset -TagThumb $tagThumb
        $tagSegments = Build-TagSegments -TagText $tagRow.Text -TagMarker $tagRow.Marker -TagColor $tagRow.Color
        $detailRowSegments = @()
        if ($row -lt $detailSegments.Count) {
            $detailRowSegments = @($detailSegments[$row])
        }

        Write-ColorSegments -Segments $tagSegments -Width $layout.TagPane.W -NoNewline
        Write-Host ' ' -NoNewline
        Write-ColorSegments -Segments $detailRowSegments -Width $layout.DetailPane.W
        $tagRowOffset++
    }

    $hideMode = if ($State.Ui.HideUnavailableTags) { 'On' } else { 'Off' }
    $status = "Total: $($State.Data.AllIdeas.Count) | Filtered: $($State.Derived.VisibleIdeaIds.Count) | Selected Tags: $($State.Query.SelectedTags.Count) | HideUnavailable: $hideMode | [Tab] Switch [Space] Toggle [PgUp/PgDn] Page [Home/End] Jump [H] Hide [Q] Quit"
    Write-Host (Write-TruncatedLine -Text $status -Width $layout.StatusPane.W) -ForegroundColor DarkGray

    try { [Console]::CursorVisible = $false } catch {}
    try { [Console]::SetCursorPosition(0, 0) } catch {}
}

Export-ModuleMember -Function Get-ScrollThumb, Render-BrowserState

