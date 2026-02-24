Set-StrictMode -Version Latest

$SCROLLBAR_THUMB_GLYPH = '░'
$SCROLLBAR_TRACK_GLYPH = '│'
$BOX_TOP_LEFT = '╭'
$BOX_TOP_RIGHT = '╮'
$BOX_BOTTOM_LEFT = '╰'
$BOX_BOTTOM_RIGHT = '╯'
$BOX_HORIZONTAL = '─'
$BOX_VERTICAL = '│'

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
    $segmentItems = @()
    foreach ($item in @($Segments)) {
        if ($null -eq $item) {
            continue
        }

        if (($item -is [System.Array]) -and -not ($item -is [string])) {
            foreach ($child in @($item)) {
                $segmentItems += $child
            }
            continue
        }

        $segmentItems += $item
    }

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

function Build-BoxTopSegments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Title,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$BorderColor,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$TitleColor
    )

    if ($Width -le 0) {
        Write-Output -NoEnumerate @()
        return
    }

    if ($Width -eq 1) {
        Write-Output -NoEnumerate @(
            @{ Text = $BOX_TOP_LEFT; Color = $BorderColor }
        )
        return
    }

    $innerWidth = $Width - 2
    $titleText = if ([string]::IsNullOrWhiteSpace($Title)) { '' } else { " $Title " }
    if ($titleText.Length -gt $innerWidth) {
        $titleText = $titleText.Substring(0, $innerWidth)
    }
    $leftFill = [Math]::Floor(($innerWidth - $titleText.Length) / 2)
    $rightFill = $innerWidth - $titleText.Length - $leftFill

    $segments = @(
        @{ Text = $BOX_TOP_LEFT; Color = $BorderColor }
    )
    if ($leftFill -gt 0) {
        $segments += @{ Text = ($BOX_HORIZONTAL * $leftFill); Color = $BorderColor }
    }
    if ($titleText.Length -gt 0) {
        $segments += @{ Text = $titleText; Color = $TitleColor }
    }
    if ($rightFill -gt 0) {
        $segments += @{ Text = ($BOX_HORIZONTAL * $rightFill); Color = $BorderColor }
    }
    $segments += @{ Text = $BOX_TOP_RIGHT; Color = $BorderColor }

    Write-Output -NoEnumerate $segments
}

function Build-BoxBottomSegments {
    param(
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$BorderColor
    )

    if ($Width -le 0) {
        Write-Output -NoEnumerate @()
        return
    }

    if ($Width -eq 1) {
        Write-Output -NoEnumerate @(
            @{ Text = $BOX_BOTTOM_LEFT; Color = $BorderColor }
        )
        return
    }

    $innerWidth = [Math]::Max(0, $Width - 2)
    $segments = @(
        @{ Text = $BOX_BOTTOM_LEFT; Color = $BorderColor }
    )
    if ($innerWidth -gt 0) {
        $segments += @{ Text = ($BOX_HORIZONTAL * $innerWidth); Color = $BorderColor }
    }
    $segments += @{ Text = $BOX_BOTTOM_RIGHT; Color = $BorderColor }

    Write-Output -NoEnumerate $segments
}

function Build-BorderedRowSegments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$InnerSegments,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$BorderColor
    )

    if ($Width -le 0) {
        Write-Output -NoEnumerate @()
        return
    }

    if ($Width -eq 1) {
        Write-Output -NoEnumerate @(
            @{ Text = $BOX_VERTICAL; Color = $BorderColor }
        )
        return
    }

    $innerWidth = $Width - 2
    $flatInnerSegments = @()
    foreach ($item in @($InnerSegments)) {
        if ($null -eq $item) {
            continue
        }
        if (($item -is [System.Array]) -and -not ($item -is [string])) {
            foreach ($child in @($item)) {
                $flatInnerSegments += $child
            }
            continue
        }
        $flatInnerSegments += $item
    }

    $normalizedInnerSegments = @(Write-ColorSegments -Segments $flatInnerSegments -Width $innerWidth -NoEmit)
    $segments = @(
        @{ Text = $BOX_VERTICAL; Color = $BorderColor }
    )
    if ($normalizedInnerSegments.Count -gt 0) {
        $segments += $normalizedInnerSegments
    }
    $segments += @{ Text = $BOX_VERTICAL; Color = $BorderColor }

    Write-Output -NoEnumerate $segments
}

function Merge-AdjacentSegments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Segments
    )

    $flatSegments = @()
    foreach ($item in @($Segments)) {
        if ($null -eq $item) {
            continue
        }

        if (($item -is [System.Array]) -and -not ($item -is [string])) {
            foreach ($child in @($item)) {
                $flatSegments += $child
            }
            continue
        }

        $flatSegments += $item
    }

    if ($flatSegments.Count -le 1) {
        Write-Output -NoEnumerate $flatSegments
        return
    }

    $merged = [System.Collections.Generic.List[object]]::new()
    $current = @{
        Text = [string](Get-PropertyValueOrDefault -Object $flatSegments[0] -Name 'Text' -Default '')
        Color = [string](Get-PropertyValueOrDefault -Object $flatSegments[0] -Name 'Color' -Default 'Gray')
        BackgroundColor = [string](Get-PropertyValueOrDefault -Object $flatSegments[0] -Name 'BackgroundColor' -Default '')
    }

    for ($i = 1; $i -lt $flatSegments.Count; $i++) {
        $next = $flatSegments[$i]
        $nextText = [string](Get-PropertyValueOrDefault -Object $next -Name 'Text' -Default '')
        $nextColor = [string](Get-PropertyValueOrDefault -Object $next -Name 'Color' -Default 'Gray')
        $nextBackground = [string](Get-PropertyValueOrDefault -Object $next -Name 'BackgroundColor' -Default '')

        if ($current.Color -eq $nextColor -and $current.BackgroundColor -eq $nextBackground) {
            $current.Text += $nextText
            continue
        }

        $merged.Add($current)
        $current = @{
            Text = $nextText
            Color = $nextColor
            BackgroundColor = $nextBackground
        }
    }

    $merged.Add($current)
    Write-Output -NoEnumerate $merged.ToArray()
}

function Normalize-FrameSegments {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Segments,
        [Parameter(Mandatory = $true)][int]$Width
    )

    if ($Width -le 0) {
        Write-Output -NoEnumerate @()
        return
    }

    $normalizedSegments = @()
    $remaining = $Width
    $segmentItems = @()
    foreach ($item in @($Segments)) {
        if ($null -eq $item) {
            continue
        }

        if (($item -is [System.Array]) -and -not ($item -is [string])) {
            foreach ($child in @($item)) {
                $segmentItems += $child
            }
            continue
        }

        $segmentItems += $item
    }

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
        $backgroundColor = [string](Get-PropertyValueOrDefault -Object $segment -Name 'BackgroundColor' -Default '')

        if ($text.Length -le $remaining) {
            $normalizedSegments += @{
                Text = $text
                Color = $color
                BackgroundColor = $backgroundColor
            }
            $remaining -= $text.Length
            continue
        }

        $normalizedSegments += @{
            Text = (Write-TruncatedLine -Text $text -Width $remaining)
            Color = $color
            BackgroundColor = $backgroundColor
        }
        $remaining = 0
    }

    if ($remaining -gt 0) {
        $normalizedSegments += @{
            Text = (' ' * $remaining)
            Color = 'Gray'
            BackgroundColor = ''
        }
    }

    Write-Output -NoEnumerate $normalizedSegments
}

function Get-FrameRowSignature {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Segments
    )

    $parts = foreach ($segment in $Segments) {
        $color = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Color' -Default 'Gray')
        $background = [string](Get-PropertyValueOrDefault -Object $segment -Name 'BackgroundColor' -Default '')
        $text = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Text' -Default '')
        "$color|$background|$text"
    }

    return ($parts -join "`0")
}

function Compose-FrameRow {
    param(
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$LeftSegments,
        [Parameter(Mandatory = $true)][int]$LeftWidth,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$RightSegments,
        [Parameter(Mandatory = $true)][int]$RightWidth,
        [AllowEmptyString()][string]$RightBackgroundColor = '',
        [Parameter(Mandatory = $true)][int]$TotalWidth,
        [Parameter(Mandatory = $true)][bool]$IsLastRow
    )

    $normalizedLeft = Write-ColorSegments -Segments $LeftSegments -Width $LeftWidth -NoEmit
    $normalizedRight = Write-ColorSegments -Segments $RightSegments -Width $RightWidth -NoEmit

    $leftWithBackground = @(foreach ($segment in $normalizedLeft) {
        @{
            Text = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Text' -Default '')
            Color = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Color' -Default 'Gray')
            BackgroundColor = ''
        }
    })

    $rightWithBackground = @(foreach ($segment in $normalizedRight) {
        @{
            Text = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Text' -Default '')
            Color = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Color' -Default 'Gray')
            BackgroundColor = $RightBackgroundColor
        }
    })

    $gapSegment = @{
        Text = ' '
        Color = 'Gray'
        BackgroundColor = ''
    }

    $effectiveWidth = if ($IsLastRow) { [Math]::Max(0, $TotalWidth - 1) } else { [Math]::Max(0, $TotalWidth) }
    $fullSegments = @()
    $fullSegments += $leftWithBackground
    $fullSegments += @($gapSegment)
    $fullSegments += $rightWithBackground
    $normalizedFull = Normalize-FrameSegments -Segments $fullSegments -Width $effectiveWidth
    $mergedSegments = Merge-AdjacentSegments -Segments $normalizedFull
    $signature = Get-FrameRowSignature -Segments $mergedSegments

    return [pscustomobject]@{
        Y = $Y
        Segments = $mergedSegments
        Signature = $signature
    }
}

function Get-FrameDiff {
    param(
        [AllowNull()]$PreviousFrame,
        [Parameter(Mandatory = $true)]$NextFrame
    )

    if ($null -eq $PreviousFrame) {
        Write-Output -NoEnumerate $NextFrame.Rows
        return
    }

    if ($PreviousFrame.Width -ne $NextFrame.Width -or $PreviousFrame.Height -ne $NextFrame.Height) {
        Write-Output -NoEnumerate $NextFrame.Rows
        return
    }

    $changed = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $NextFrame.Height; $i++) {
        if ($NextFrame.Rows[$i].Signature -ne $PreviousFrame.Rows[$i].Signature) {
            $changed.Add($NextFrame.Rows[$i])
        }
    }

    Write-Output -NoEnumerate $changed.ToArray()
}

function Flush-FrameDiff {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$ChangedRows,
        [Parameter(Mandatory = $true)]$Frame
    )

    if ($ChangedRows.Count -eq 0) {
        return $true
    }

    try {
        [Console]::CursorVisible = $false

        foreach ($row in $ChangedRows) {
            if ($row.Y -lt 0 -or $row.Y -ge $Frame.Height) {
                continue
            }

            try { [Console]::SetCursorPosition(0, $row.Y) } catch { }
            foreach ($segment in $row.Segments) {
                $text = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Text' -Default '')
                $color = [string](Get-PropertyValueOrDefault -Object $segment -Name 'Color' -Default 'Gray')
                $backgroundColor = [string](Get-PropertyValueOrDefault -Object $segment -Name 'BackgroundColor' -Default '')

                try {
                    if (-not [string]::IsNullOrWhiteSpace($color)) {
                        [Console]::ForegroundColor = $color
                    }
                    if (-not [string]::IsNullOrWhiteSpace($backgroundColor)) {
                        [Console]::BackgroundColor = $backgroundColor
                    } else {
                        [Console]::BackgroundColor = 'Black'
                    }
                    [Console]::Write($text)
                } catch { }
            }
        }

        try { [Console]::SetCursorPosition(0, 0) } catch { }
        try { [Console]::ResetColor() } catch { }
        return $true
    }
    catch {
        return $false
    }
}

Export-ModuleMember -Variable SCROLLBAR_THUMB_GLYPH, SCROLLBAR_TRACK_GLYPH, BOX_TOP_LEFT, BOX_TOP_RIGHT, BOX_BOTTOM_LEFT, BOX_BOTTOM_RIGHT, BOX_HORIZONTAL, BOX_VERTICAL -Function Get-PropertyValueOrDefault, Write-TruncatedLine, Write-ColorSegments, Get-ScrollThumb, Build-BoxTopSegments, Build-BoxBottomSegments, Build-BorderedRowSegments, Merge-AdjacentSegments, Normalize-FrameSegments, Get-FrameRowSignature, Compose-FrameRow, Get-FrameDiff, Flush-FrameDiff
