Set-StrictMode -Version Latest

$SCROLLBAR_THUMB_GLYPH = '░'
$SCROLLBAR_TRACK_GLYPH = '│'

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

    $detailLines = @()
    if ($State.Derived.VisibleIdeaIds.Count -eq 0) {
        $detailLines = @('No matching ideas')
    } else {
        $selectedId = $State.Derived.VisibleIdeaIds[[Math]::Min($State.Cursor.IdeaIndex, $State.Derived.VisibleIdeaIds.Count - 1)]
        $selectedIdea = Get-IdeaById -Ideas $State.Data.AllIdeas -Id $selectedId
        if ($null -ne $selectedIdea) {
            $detailLines = @(
                "ID: $($selectedIdea.Id)",
                "Priority: $($selectedIdea.Priority)  Effort: $($selectedIdea.Effort)  Risk: $($selectedIdea.Risk)",
                "Tags: $(@($selectedIdea.Tags) -join ', ')",
                '',
                "Summary: $($selectedIdea.Summary)",
                "Rationale: $($selectedIdea.Rationale)"
            )
        }
    }

    Write-Host (Write-TruncatedLine -Text '[Tags]' -Width $layout.TagPane.W) -ForegroundColor Cyan -NoNewline
    Write-Host ' ' -NoNewline
    Write-Host (Write-TruncatedLine -Text '[Ideas]' -Width $layout.ListPane.W) -ForegroundColor Cyan

    for ($row = 0; $row -lt $topRows; $row++) {
        $tagText = ''
        $tagColor = 'Gray'
        $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
        $tagMarker = ' '
        $tagItem = Get-VisibleTagByIndex -State $State -TagIndex $tagIndex
        if ($null -ne $tagItem) {
            if ($State.Cursor.TagIndex -eq $tagIndex) {
                $tagMarker = '>'
            } elseif ($null -ne $tagThumb) {
                if ($tagRowOffset -ge $tagThumb.Start -and $tagRowOffset -le $tagThumb.End) {
                    $tagMarker = $SCROLLBAR_THUMB_GLYPH
                } else {
                    $tagMarker = $SCROLLBAR_TRACK_GLYPH
                }
            }
            $mark = if ($tagItem.IsSelected) { '[x]' } else { '[ ]' }
            $tagText = "$tagMarker $mark $($tagItem.Name) ($($tagItem.MatchCount))"
            if (-not $tagItem.IsSelectable -and -not $tagItem.IsSelected) {
                $tagColor = 'DarkGray'
            } elseif ($tagItem.IsSelected) {
                $tagColor = 'Green'
            }
        } elseif ($null -ne $tagThumb) {
            if ($tagRowOffset -ge $tagThumb.Start -and $tagRowOffset -le $tagThumb.End) {
                $tagText = $SCROLLBAR_THUMB_GLYPH
            } else {
                $tagText = $SCROLLBAR_TRACK_GLYPH
            }
            $tagColor = 'DarkGray'
        }

        $ideaText = ''
        $ideaMarker = ' '
        $ideaIndex = $State.Cursor.IdeaScrollTop + $row
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
            if ($null -ne $idea) {
                $ideaText = "$ideaMarker $($idea.Id) $($idea.Title)"
            }
        } elseif ($null -ne $ideaThumb) {
            if ($row -ge $ideaThumb.Start -and $row -le $ideaThumb.End) {
                $ideaText = $SCROLLBAR_THUMB_GLYPH
            } else {
                $ideaText = $SCROLLBAR_TRACK_GLYPH
            }
        }

        Write-Host (Write-TruncatedLine -Text $tagText -Width $layout.TagPane.W) -ForegroundColor $tagColor -NoNewline
        Write-Host ' ' -NoNewline
        Write-Host (Write-TruncatedLine -Text $ideaText -Width $layout.ListPane.W)
        $tagRowOffset++
    }

    $tagText = ''
    $tagColor = 'Gray'
    $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
    $tagMarker = ' '
    $tagItem = Get-VisibleTagByIndex -State $State -TagIndex $tagIndex
    if ($null -ne $tagItem) {
        if ($State.Cursor.TagIndex -eq $tagIndex) {
            $tagMarker = '>'
        } elseif ($null -ne $tagThumb) {
            if ($tagRowOffset -ge $tagThumb.Start -and $tagRowOffset -le $tagThumb.End) {
                $tagMarker = $SCROLLBAR_THUMB_GLYPH
            } else {
                $tagMarker = $SCROLLBAR_TRACK_GLYPH
            }
        }
        $mark = if ($tagItem.IsSelected) { '[x]' } else { '[ ]' }
        $tagText = "$tagMarker $mark $($tagItem.Name) ($($tagItem.MatchCount))"
        if (-not $tagItem.IsSelectable -and -not $tagItem.IsSelected) {
            $tagColor = 'DarkGray'
        } elseif ($tagItem.IsSelected) {
            $tagColor = 'Green'
        }
    } elseif ($null -ne $tagThumb) {
        if ($tagRowOffset -ge $tagThumb.Start -and $tagRowOffset -le $tagThumb.End) {
            $tagText = $SCROLLBAR_THUMB_GLYPH
        } else {
            $tagText = $SCROLLBAR_TRACK_GLYPH
        }
        $tagColor = 'DarkGray'
    }
    Write-Host (Write-TruncatedLine -Text $tagText -Width $layout.TagPane.W) -ForegroundColor $tagColor -NoNewline
    Write-Host ' ' -NoNewline
    Write-Host (Write-TruncatedLine -Text '[Details]' -Width $layout.DetailPane.W) -ForegroundColor Cyan
    $tagRowOffset++

    for ($row = 0; $row -lt $detailRows; $row++) {
        $tagText = ''
        $tagColor = 'Gray'
        $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
        $tagMarker = ' '
        $tagItem = Get-VisibleTagByIndex -State $State -TagIndex $tagIndex
        if ($null -ne $tagItem) {
            if ($State.Cursor.TagIndex -eq $tagIndex) {
                $tagMarker = '>'
            } elseif ($null -ne $tagThumb) {
                if ($tagRowOffset -ge $tagThumb.Start -and $tagRowOffset -le $tagThumb.End) {
                    $tagMarker = $SCROLLBAR_THUMB_GLYPH
                } else {
                    $tagMarker = $SCROLLBAR_TRACK_GLYPH
                }
            }
            $mark = if ($tagItem.IsSelected) { '[x]' } else { '[ ]' }
            $tagText = "$tagMarker $mark $($tagItem.Name) ($($tagItem.MatchCount))"
            if (-not $tagItem.IsSelectable -and -not $tagItem.IsSelected) {
                $tagColor = 'DarkGray'
            } elseif ($tagItem.IsSelected) {
                $tagColor = 'Green'
            }
        } elseif ($null -ne $tagThumb) {
            if ($tagRowOffset -ge $tagThumb.Start -and $tagRowOffset -le $tagThumb.End) {
                $tagText = $SCROLLBAR_THUMB_GLYPH
            } else {
                $tagText = $SCROLLBAR_TRACK_GLYPH
            }
            $tagColor = 'DarkGray'
        }

        $detailText = ''
        if ($row -lt $detailLines.Count) {
            $detailText = [string]$detailLines[$row]
        }

        Write-Host (Write-TruncatedLine -Text $tagText -Width $layout.TagPane.W) -ForegroundColor $tagColor -NoNewline
        Write-Host ' ' -NoNewline
        Write-Host (Write-TruncatedLine -Text $detailText -Width $layout.DetailPane.W)
        $tagRowOffset++
    }

    $hideMode = if ($State.Ui.HideUnavailableTags) { 'On' } else { 'Off' }
    $status = "Total: $($State.Data.AllIdeas.Count) | Filtered: $($State.Derived.VisibleIdeaIds.Count) | Selected Tags: $($State.Query.SelectedTags.Count) | HideUnavailable: $hideMode | [Tab] Switch [Space] Toggle [PgUp/PgDn] Page [Home/End] Jump [H] Hide [Q] Quit"
    Write-Host (Write-TruncatedLine -Text $status -Width $layout.StatusPane.W) -ForegroundColor DarkGray

    try { [Console]::CursorVisible = $false } catch {}
    try { [Console]::SetCursorPosition(0, 0) } catch {}
}

Export-ModuleMember -Function Get-ScrollThumb, Render-BrowserState

