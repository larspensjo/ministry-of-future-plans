Set-StrictMode -Version Latest

function Get-IdeaById {
    param(
        [Parameter(Mandatory = $true)][object[]]$Ideas,
        [Parameter(Mandatory = $true)][string]$Id
    )

    return $Ideas | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
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
        $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
        if ($tagIndex -lt $State.Data.AllTags.Count) {
            $tag = $State.Data.AllTags[$tagIndex]
            $selected = $State.Query.SelectedTags.Contains($tag)
            $cursor = if ($State.Cursor.TagIndex -eq $tagIndex) { '>' } else { ' ' }
            $mark = if ($selected) { '[x]' } else { '[ ]' }
            $tagText = "$cursor $mark $tag"
        }

        $ideaText = ''
        $ideaIndex = $State.Cursor.IdeaScrollTop + $row
        if ($ideaIndex -lt $State.Derived.VisibleIdeaIds.Count) {
            $ideaId = $State.Derived.VisibleIdeaIds[$ideaIndex]
            $idea = Get-IdeaById -Ideas $State.Data.AllIdeas -Id $ideaId
            $cursor = if ($State.Cursor.IdeaIndex -eq $ideaIndex) { '>' } else { ' ' }
            if ($null -ne $idea) {
                $ideaText = "$cursor $($idea.Id) $($idea.Title)"
            }
        }

        Write-Host (Write-TruncatedLine -Text $tagText -Width $layout.TagPane.W) -NoNewline
        Write-Host ' ' -NoNewline
        Write-Host (Write-TruncatedLine -Text $ideaText -Width $layout.ListPane.W)
        $tagRowOffset++
    }

    $tagText = ''
    $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
    if ($tagIndex -lt $State.Data.AllTags.Count) {
        $tag = $State.Data.AllTags[$tagIndex]
        $selected = $State.Query.SelectedTags.Contains($tag)
        $cursor = if ($State.Cursor.TagIndex -eq $tagIndex) { '>' } else { ' ' }
        $mark = if ($selected) { '[x]' } else { '[ ]' }
        $tagText = "$cursor $mark $tag"
    }
    Write-Host (Write-TruncatedLine -Text $tagText -Width $layout.TagPane.W) -NoNewline
    Write-Host ' ' -NoNewline
    Write-Host (Write-TruncatedLine -Text '[Details]' -Width $layout.DetailPane.W) -ForegroundColor Cyan
    $tagRowOffset++

    for ($row = 0; $row -lt $detailRows; $row++) {
        $tagText = ''
        $tagIndex = $State.Cursor.TagScrollTop + $tagRowOffset
        if ($tagIndex -lt $State.Data.AllTags.Count) {
            $tag = $State.Data.AllTags[$tagIndex]
            $selected = $State.Query.SelectedTags.Contains($tag)
            $cursor = if ($State.Cursor.TagIndex -eq $tagIndex) { '>' } else { ' ' }
            $mark = if ($selected) { '[x]' } else { '[ ]' }
            $tagText = "$cursor $mark $tag"
        }

        $detailText = ''
        if ($row -lt $detailLines.Count) {
            $detailText = [string]$detailLines[$row]
        }

        Write-Host (Write-TruncatedLine -Text $tagText -Width $layout.TagPane.W) -NoNewline
        Write-Host ' ' -NoNewline
        Write-Host (Write-TruncatedLine -Text $detailText -Width $layout.DetailPane.W)
        $tagRowOffset++
    }

    $status = "Total: $($State.Data.AllIdeas.Count) | Filtered: $($State.Derived.VisibleIdeaIds.Count) | Selected Tags: $($State.Query.SelectedTags.Count) | [Tab] Switch [Space] Toggle [Q] Quit"
    Write-Host (Write-TruncatedLine -Text $status -Width $layout.StatusPane.W) -ForegroundColor DarkGray

    try { [Console]::CursorVisible = $false } catch {}
    try { [Console]::SetCursorPosition(0, 0) } catch {}
}

Export-ModuleMember -Function Render-BrowserState
