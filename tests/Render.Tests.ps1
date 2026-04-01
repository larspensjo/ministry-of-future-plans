$modulePath = Join-Path $PSScriptRoot '..\browser\Render.psm1'
Import-Module $modulePath -Force

function New-RenderTestState {
    param(
        [int]$Width = 80,
        [int]$Height = 20,
        [object[]]$VisibleIdeaIds = @('FI-1', 'FI-2'),
        [int]$IdeaIndex = 0,
        [int]$IdeaScrollTop = 0
    )

    $selectedTags = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    [void]$selectedTags.Add('alpha')

    $ideas = @(
        [pscustomobject]@{
            Id = 'FI-1'
            Title = 'First idea'
            Priority = 'P2'
            Effort = 'M'
            Risk = 'L'
            Tags = @('alpha')
            Summary = 'Summary one'
            Rationale = 'Rationale one'
        },
        [pscustomobject]@{
            Id = 'FI-2'
            Title = 'Second idea'
            Priority = 'P0'
            Effort = 'H'
            Risk = 'H'
            Tags = @('beta')
            Summary = 'Summary two'
            Rationale = 'Rationale two'
        },
        [pscustomobject]@{
            Id = 'FI-3'
            Title = 'Third idea'
            Priority = 'P3'
            Effort = 'L'
            Risk = 'M'
            Tags = @('gamma')
            Summary = 'Summary three'
            Rationale = 'Rationale three'
        }
    )

    $contentHeight = $Height - 1
    $listHeight = 9
    $detailHeight = $contentHeight - $listHeight - 1
    $layout = [pscustomobject]@{
        Mode = 'Normal'
        Width = $Width
        Height = $Height
        TagPane = [pscustomobject]@{ X = 0; Y = 0; W = 24; H = $contentHeight }
        ListPane = [pscustomobject]@{ X = 25; Y = 0; W = 55; H = $listHeight }
        DetailPane = [pscustomobject]@{ X = 25; Y = ($listHeight + 1); W = 55; H = $detailHeight }
        StatusPane = [pscustomobject]@{ X = 0; Y = $contentHeight; W = $Width; H = 1 }
    }

    return [pscustomobject]@{
        Data = [pscustomobject]@{
            AllIdeas = $ideas
            AllTags = @('alpha', 'beta', 'gamma')
        }
        Ui = [pscustomobject]@{
            ActivePane = 'Ideas'
            IsMaximized = $false
            HideUnavailableTags = $false
            Layout = $layout
        }
        Query = [pscustomobject]@{
            SelectedTags = $selectedTags
            SearchText = ''
            SearchMode = 'None'
            SortMode = 'Default'
        }
        Derived = [pscustomobject]@{
            VisibleIdeaIds = @($VisibleIdeaIds)
            VisibleTags = @(
                [pscustomobject]@{ Name = 'alpha'; MatchCount = 1; IsSelected = $true; IsSelectable = $true },
                [pscustomobject]@{ Name = 'beta'; MatchCount = 1; IsSelected = $false; IsSelectable = $true },
                [pscustomobject]@{ Name = 'gamma'; MatchCount = 1; IsSelected = $false; IsSelectable = $true }
            )
        }
        Cursor = [pscustomobject]@{
            TagIndex = 0
            TagScrollTop = 0
            IdeaIndex = $IdeaIndex
            IdeaScrollTop = $IdeaScrollTop
        }
        Runtime = [pscustomobject]@{
            IsRunning = $true
            LastError = $null
        }
    }
}

Describe 'Get-ScrollThumb' {

    It 'returns null when content fits viewport' {
        $thumb = Get-ScrollThumb -TotalItems 10 -ViewRows 10 -ScrollTop 0
        $thumb | Should -BeNullOrEmpty
    }

    It 'returns thumb with min size and bounded range' {
        $thumb = Get-ScrollThumb -TotalItems 100 -ViewRows 10 -ScrollTop 0
        $thumb.Size | Should -BeGreaterThan 0
        $thumb.Start | Should -BeGreaterOrEqual 0
        $thumb.End | Should -BeLessThan 10
    }

    It 'moves thumb downward when scroll top increases' {
        $topThumb = Get-ScrollThumb -TotalItems 100 -ViewRows 10 -ScrollTop 0
        $midThumb = Get-ScrollThumb -TotalItems 100 -ViewRows 10 -ScrollTop 45
        $midThumb.Start | Should -BeGreaterThan $topThumb.Start
    }

    It 'clamps thumb at bottom when scroll top exceeds max' {
        $thumb = Get-ScrollThumb -TotalItems 40 -ViewRows 10 -ScrollTop 999
        $thumb.End | Should -Be 9
    }
}

Describe 'Frame helpers' {
    InModuleScope 'Render' {
        BeforeAll {
            function New-RenderStateFixture {
                param(
                    [int]$Width = 80,
                    [int]$Height = 20,
                    [object[]]$VisibleIdeaIds = @('FI-1', 'FI-2'),
                    [int]$IdeaIndex = 0,
                    [int]$IdeaScrollTop = 0
                )

                $selectedTags = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                [void]$selectedTags.Add('alpha')

                $ideas = @(
                    [pscustomobject]@{
                        Id = 'FI-1'
                        Title = 'First idea'
                        Priority = 'P2'
                        Effort = 'M'
                        Risk = 'L'
                        Tags = @('alpha')
                        Summary = 'Summary one'
                        Rationale = 'Rationale one'
                    },
                    [pscustomobject]@{
                        Id = 'FI-2'
                        Title = 'Second idea'
                        Priority = 'P0'
                        Effort = 'H'
                        Risk = 'H'
                        Tags = @('beta')
                        Summary = 'Summary two'
                        Rationale = 'Rationale two'
                    },
                    [pscustomobject]@{
                        Id = 'FI-3'
                        Title = 'Third idea'
                        Priority = 'P3'
                        Effort = 'L'
                        Risk = 'M'
                        Tags = @('gamma')
                        Summary = 'Summary three'
                        Rationale = 'Rationale three'
                    }
                )

                $contentHeight = $Height - 1
                $listHeight = 9
                $detailHeight = $contentHeight - $listHeight - 1
                $layout = [pscustomobject]@{
                    Mode = 'Normal'
                    Width = $Width
                    Height = $Height
                    TagPane = [pscustomobject]@{ X = 0; Y = 0; W = 24; H = $contentHeight }
                    ListPane = [pscustomobject]@{ X = 25; Y = 0; W = 55; H = $listHeight }
                    DetailPane = [pscustomobject]@{ X = 25; Y = ($listHeight + 1); W = 55; H = $detailHeight }
                    StatusPane = [pscustomobject]@{ X = 0; Y = $contentHeight; W = $Width; H = 1 }
                }

                return [pscustomobject]@{
                    Data = [pscustomobject]@{
                        AllIdeas = $ideas
                        AllTags = @('alpha', 'beta', 'gamma')
                    }
                    Ui = [pscustomobject]@{
                        ActivePane = 'Ideas'
                        IsMaximized = $false
                        HideUnavailableTags = $false
                        Layout = $layout
                    }
                    Query = [pscustomobject]@{
                        SelectedTags = $selectedTags
                        SearchText = ''
                        SearchMode = 'None'
                        SortMode = 'Default'
                    }
                    Derived = [pscustomobject]@{
                        VisibleIdeaIds = @($VisibleIdeaIds)
                        VisibleTags = @(
                            [pscustomobject]@{ Name = 'alpha'; MatchCount = 1; IsSelected = $true; IsSelectable = $true },
                            [pscustomobject]@{ Name = 'beta'; MatchCount = 1; IsSelected = $false; IsSelectable = $true },
                            [pscustomobject]@{ Name = 'gamma'; MatchCount = 1; IsSelected = $false; IsSelectable = $true }
                        )
                    }
                    Cursor = [pscustomobject]@{
                        TagIndex = 0
                        TagScrollTop = 0
                        IdeaIndex = $IdeaIndex
                        IdeaScrollTop = $IdeaScrollTop
                    }
                    Runtime = [pscustomobject]@{
                        IsRunning = $true
                        LastError = $null
                    }
                }
            }
        }


        Context 'Merge-AdjacentSegments' {
            It 'merges neighbors with matching foreground and background' {
                $segments = @(
                    @{ Text = 'A'; Color = 'Gray'; BackgroundColor = '' },
                    @{ Text = 'B'; Color = 'Gray'; BackgroundColor = '' },
                    @{ Text = 'C'; Color = 'Red'; BackgroundColor = '' }
                )
                $merged = Merge-AdjacentSegments -Segments $segments
                $merged.Count | Should -Be 2
                $merged[0].Text | Should -Be 'AB'
                $merged[1].Text | Should -Be 'C'
            }

            It 'does not merge when foreground differs' {
                $segments = @(
                    @{ Text = 'A'; Color = 'Gray'; BackgroundColor = '' },
                    @{ Text = 'B'; Color = 'White'; BackgroundColor = '' }
                )
                (Merge-AdjacentSegments -Segments $segments).Count | Should -Be 2
            }

            It 'does not merge when background differs' {
                $segments = @(
                    @{ Text = 'A'; Color = 'Gray'; BackgroundColor = '' },
                    @{ Text = 'B'; Color = 'Gray'; BackgroundColor = 'DarkCyan' }
                )
                (Merge-AdjacentSegments -Segments $segments).Count | Should -Be 2
            }

            It 'returns single segment unchanged' {
                $single = @(@{ Text = 'Only'; Color = 'Gray'; BackgroundColor = '' })
                $merged = Merge-AdjacentSegments -Segments $single
                $merged.Count | Should -Be 1
                $merged[0].Text | Should -Be 'Only'
            }

            It 'returns empty output for empty input' {
                (Merge-AdjacentSegments -Segments @()).Count | Should -Be 0
            }
        }

        Context 'Get-FrameRowSignature' {
            It 'returns identical signatures for identical rows' {
                $segments = @(
                    @{ Text = 'A'; Color = 'Gray'; BackgroundColor = '' },
                    @{ Text = 'B'; Color = 'Red'; BackgroundColor = 'DarkCyan' }
                )
                (Get-FrameRowSignature -Segments $segments) | Should -Be (Get-FrameRowSignature -Segments $segments)
            }

            It 'changes when text changes' {
                $a = @(@{ Text = 'One'; Color = 'Gray'; BackgroundColor = '' })
                $b = @(@{ Text = 'Two'; Color = 'Gray'; BackgroundColor = '' })
                (Get-FrameRowSignature -Segments $a) | Should -Not -Be (Get-FrameRowSignature -Segments $b)
            }

            It 'changes when color changes' {
                $a = @(@{ Text = 'One'; Color = 'Gray'; BackgroundColor = '' })
                $b = @(@{ Text = 'One'; Color = 'White'; BackgroundColor = '' })
                (Get-FrameRowSignature -Segments $a) | Should -Not -Be (Get-FrameRowSignature -Segments $b)
            }

            It 'changes when background changes' {
                $a = @(@{ Text = 'One'; Color = 'Gray'; BackgroundColor = '' })
                $b = @(@{ Text = 'One'; Color = 'Gray'; BackgroundColor = 'DarkCyan' })
                (Get-FrameRowSignature -Segments $a) | Should -Not -Be (Get-FrameRowSignature -Segments $b)
            }
        }

        Context 'Get-FrameDiff' {
            It 'returns all rows when previous frame is null' {
                $next = [pscustomobject]@{
                    Width = 10
                    Height = 2
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() }
                    )
                }
                (Get-FrameDiff -PreviousFrame $null -NextFrame $next).Count | Should -Be 2
            }

            It 'returns all rows when width differs' {
                $previous = [pscustomobject]@{
                    Width = 9
                    Height = 2
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() }
                    )
                }
                $next = [pscustomobject]@{
                    Width = 10
                    Height = 2
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() }
                    )
                }
                (Get-FrameDiff -PreviousFrame $previous -NextFrame $next).Count | Should -Be 2
            }

            It 'returns all rows when height differs' {
                $previous = [pscustomobject]@{
                    Width = 10
                    Height = 1
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() }
                    )
                }
                $next = [pscustomobject]@{
                    Width = 10
                    Height = 2
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() }
                    )
                }
                (Get-FrameDiff -PreviousFrame $previous -NextFrame $next).Count | Should -Be 2
            }

            It 'returns zero rows for identical frames' {
                $rows = @(
                    [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                    [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() }
                )
                $previous = [pscustomobject]@{ Width = 10; Height = 2; Rows = $rows }
                $next = [pscustomobject]@{ Width = 10; Height = 2; Rows = $rows }
                (Get-FrameDiff -PreviousFrame $previous -NextFrame $next).Count | Should -Be 0
            }

            It 'returns only the changed row when one row differs' {
                $previous = [pscustomobject]@{
                    Width = 10
                    Height = 2
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() }
                    )
                }
                $next = [pscustomobject]@{
                    Width = 10
                    Height = 2
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'changed'; Segments = @() }
                    )
                }
                $changed = Get-FrameDiff -PreviousFrame $previous -NextFrame $next
                $changed.Count | Should -Be 1
                $changed[0].Y | Should -Be 1
            }

            It 'returns multiple non-adjacent changed rows' {
                $previous = [pscustomobject]@{
                    Width = 10
                    Height = 4
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'a'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() },
                        [pscustomobject]@{ Y = 2; Signature = 'c'; Segments = @() },
                        [pscustomobject]@{ Y = 3; Signature = 'd'; Segments = @() }
                    )
                }
                $next = [pscustomobject]@{
                    Width = 10
                    Height = 4
                    Rows = @(
                        [pscustomobject]@{ Y = 0; Signature = 'x'; Segments = @() },
                        [pscustomobject]@{ Y = 1; Signature = 'b'; Segments = @() },
                        [pscustomobject]@{ Y = 2; Signature = 'y'; Segments = @() },
                        [pscustomobject]@{ Y = 3; Signature = 'd'; Segments = @() }
                    )
                }
                $changed = Get-FrameDiff -PreviousFrame $previous -NextFrame $next
                @($changed | ForEach-Object { $_.Y }) | Should -Be @(0, 2)
            }
        }

        Context 'Compose-FrameRow' {
            It 'uses full width for non-last rows' {
                $row = Compose-FrameRow -Y 0 -LeftSegments @(@{ Text = 'L'; Color = 'Gray' }) -LeftWidth 4 -RightSegments @(@{ Text = 'R'; Color = 'White' }) -RightWidth 5 -TotalWidth 10 -IsLastRow $false
                (($row.Segments | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum) | Should -Be 10
            }

            It 'reserves bottom-right dead zone on last row' {
                $row = Compose-FrameRow -Y 1 -LeftSegments @(@{ Text = 'L'; Color = 'Gray' }) -LeftWidth 4 -RightSegments @(@{ Text = 'R'; Color = 'White' }) -RightWidth 5 -TotalWidth 10 -IsLastRow $true
                (($row.Segments | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum) | Should -Be 9
            }

            It 'contains the gap character between panes' {
                $row = Compose-FrameRow -Y 0 -LeftSegments @(@{ Text = 'AB'; Color = 'Gray' }) -LeftWidth 4 -RightSegments @(@{ Text = 'CD'; Color = 'White' }) -RightWidth 5 -TotalWidth 10 -IsLastRow $false
                (($row.Segments | ForEach-Object { $_.Text }) -join '') | Should -Match '^AB\s'
            }

            It 'applies right pane background color when provided' {
                $row = Compose-FrameRow -Y 0 -LeftSegments @(@{ Text = 'AB'; Color = 'Red' }) -LeftWidth 4 -RightSegments @(@{ Text = 'CD'; Color = 'White' }) -RightWidth 5 -RightBackgroundColor 'DarkCyan' -TotalWidth 10 -IsLastRow $false
                ($row.Segments | Where-Object { $_.BackgroundColor -eq 'DarkCyan' }).Count | Should -BeGreaterThan 0
            }

            It 'keeps empty background on left and gap segments' {
                $row = Compose-FrameRow -Y 0 -LeftSegments @(@{ Text = 'AB'; Color = 'Red' }) -LeftWidth 4 -RightSegments @(@{ Text = 'CD'; Color = 'White' }) -RightWidth 5 -RightBackgroundColor 'DarkCyan' -TotalWidth 10 -IsLastRow $false
                $row.Segments[0].BackgroundColor | Should -Be ''
                ($row.Segments | Where-Object { $_.Text -match '\s' -and $_.BackgroundColor -eq '' }).Count | Should -BeGreaterThan 0
            }
        }

        Context 'Build-FrameFromState' {
            It 'produces a full frame with sequential row indices' {
                $state = New-RenderStateFixture
                $frame = Build-FrameFromState -State $state
                $frame.Rows.Count | Should -Be $state.Ui.Layout.Height
                @($frame.Rows | ForEach-Object { $_.Y }) | Should -Be @(0..($state.Ui.Layout.Height - 1))
            }

            It 'uses width for content rows and width-minus-one for status row' {
                $state = New-RenderStateFixture
                $frame = Build-FrameFromState -State $state
                foreach ($row in $frame.Rows | Where-Object { $_.Y -lt ($state.Ui.Layout.Height - 1) }) {
                    (($row.Segments | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum) | Should -Be $state.Ui.Layout.Width
                }
                $statusRow = $frame.Rows[$frame.Rows.Count - 1]
                (($statusRow.Segments | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum) | Should -Be ($state.Ui.Layout.Width - 1)
            }

            It 'places status bar on the last row' {
                $state = New-RenderStateFixture
                $frame = Build-FrameFromState -State $state
                $frame.Rows[$frame.Rows.Count - 1].Y | Should -Be ($state.Ui.Layout.Height - 1)
            }

            It 'renders no matching ideas message when there are zero visible ideas' {
                $state = New-RenderStateFixture -VisibleIdeaIds @() -IdeaIndex 0
                $frame = Build-FrameFromState -State $state
                (($frame.Rows | ForEach-Object { ($_.Segments | ForEach-Object { $_.Text }) -join '' }) -join "`n") | Should -Match 'No matching ideas'
            }

            It 'applies selected row background in ideas pane' {
                $state = New-RenderStateFixture -IdeaIndex 1
                $frame = Build-FrameFromState -State $state
                @($frame.Rows | Where-Object { @($_.Segments | Where-Object { $_.BackgroundColor -eq 'DarkCyan' }).Count -gt 0 }).Count | Should -BeGreaterThan 0
            }
        }

        Context 'Frame integration intent' {
            It 'returns only changed rows between two identical frames with cursor move' {
                $stateA = New-RenderStateFixture -IdeaIndex 0
                $stateB = New-RenderStateFixture -IdeaIndex 1
                $frameA = Build-FrameFromState -State $stateA
                $frameB = Build-FrameFromState -State $stateB
                $changed = Get-FrameDiff -PreviousFrame $frameA -NextFrame $frameB
                $changed.Count | Should -BeGreaterThan 0
                $changed.Count | Should -BeLessOrEqual 12
            }

            It 'returns zero rows for identical rebuilt frames' {
                $state = New-RenderStateFixture -IdeaIndex 1
                $frameA = Build-FrameFromState -State $state
                $frameB = Build-FrameFromState -State $state
                (Get-FrameDiff -PreviousFrame $frameA -NextFrame $frameB).Count | Should -Be 0
            }
        }
    }
}

Describe 'Color helpers' {
    InModuleScope 'Render' {
        It 'keeps high priorities visually grouped and distinguishable from lower priorities' {
            $p0 = Get-PriorityColor -Priority 'P0'
            $p1 = Get-PriorityColor -Priority 'P1'
            $p2 = Get-PriorityColor -Priority 'P2'
            $p3 = Get-PriorityColor -Priority 'P3'
            $unknown = Get-PriorityColor -Priority 'UNKNOWN'

            $p0 | Should -Be $p1
            $p0 | Should -Not -Be $p2
            $p2 | Should -Not -Be $p3
            $p3 | Should -Not -Be $unknown
        }

        It 'keeps risk severities visually distinct from each other and the fallback' {
            $high = Get-RiskColor -Risk 'H'
            $medium = Get-RiskColor -Risk 'M'
            $low = Get-RiskColor -Risk 'L'
            $unknown = Get-RiskColor -Risk 'UNKNOWN'

            $high | Should -Not -Be $medium
            $medium | Should -Not -Be $low
            $low | Should -Not -Be $unknown
        }

        It 'gives cursor markers stronger emphasis than scrollbar glyphs and blanks' {
            $cursor = Get-MarkerColor -Marker '>'
            $thumb = Get-MarkerColor -Marker '░'
            $track = Get-MarkerColor -Marker '│'
            $blank = Get-MarkerColor -Marker ' '

            $cursor | Should -Not -Be $thumb
            $thumb | Should -Not -Be $track
            $track | Should -Be $blank
        }
    }
}

Describe 'Tag render helpers' {
    InModuleScope 'Render' {
        It 'builds selected tag row models with cursor marker, selection mark, and count' {
            $state = New-RenderStateFixture
            $row = Get-TagRowModel -State $state -TagIndex 0 -TagRowOffset 0 -TagThumb $null

            $row.Marker | Should -Be '>'
            $row.Text | Should -Match '^\> \[x\] alpha \(1\)$'
            $row.Color | Should -Be 'Green'
        }

        It 'renders scrollbar-only tag rows when the thumb extends past visible tags' {
            $state = New-RenderStateFixture
            $thumb = [pscustomobject]@{ Start = 0; End = 1; Size = 2 }

            $row = Get-TagRowModel -State $state -TagIndex 99 -TagRowOffset 1 -TagThumb $thumb

            $row.Text | Should -Be '░'
            $row.Marker | Should -Be '░'
        }

        It 'splits the marker from the tag text so semantic colors can differ' {
            $segments = Build-TagSegments -TagText '> [x] alpha (1)' -TagMarker '>' -TagColor 'Green'

            $segments.Count | Should -Be 2
            $segments[0].Text | Should -Be '>'
            $segments[1].Text | Should -Be ' [x] alpha (1)'
            $segments[0].Color | Should -Not -Be $segments[1].Color
        }

        It 'uses a stronger border color for the active pane than inactive panes' {
            $state = New-RenderStateFixture
            $ideasBorder = Get-PaneBorderColor -PaneName 'Ideas' -State $state
            $tagsBorder = Get-PaneBorderColor -PaneName 'Tags' -State $state

            $ideasBorder | Should -Not -Be $tagsBorder
        }

        It 'builds a status bar row with counts and expected row width' {
            $state = New-RenderStateFixture
            $row = Build-StatusBarRow -State $state -Layout $state.Ui.Layout
            $text = ($row.Segments | ForEach-Object { $_.Text }) -join ''

            $row.Y | Should -Be $state.Ui.Layout.StatusPane.Y
            $text | Should -Match 'Total: 3'
            $text | Should -Match 'Filtered: 2'
            $text | Should -Match 'HideUnavailable: Off'
            (($row.Segments | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum) | Should -Be ($state.Ui.Layout.StatusPane.W - 1)
        }
    }
}

Describe 'Write-ColorSegments' {
    InModuleScope 'Render' {
        It 'pads content to requested width' {
            $result = Write-ColorSegments -Segments @(
                @{ Text = 'Hi'; Color = 'Red' }
            ) -Width 5 -NoEmit
            ($result | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum | Should -Be 5
        }

        It 'truncates content using ellipsis policy' {
            $result = Write-ColorSegments -Segments @(
                @{ Text = 'ABCDEFGHIJ'; Color = 'Red' }
            ) -Width 7 -NoEmit
            $result.Count | Should -Be 1
            $result[0].Text.Length | Should -Be 7
            $result[0].Text | Should -Match '\.\.\.$'
            $result[0].Text | Should -Not -Be 'ABCDEFGHIJ'
            ($result | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum | Should -Be 7
        }

        It 'returns blank segment when no content exists' {
            $result = Write-ColorSegments -Segments @() -Width 4 -NoEmit
            $result.Count | Should -Be 1
            $result[0].Text | Should -Be '    '
            $result[0].Color | Should -Be 'Gray'
        }

        It 'returns empty output when width is non-positive' {
            (Write-ColorSegments -Segments @(@{ Text = 'a'; Color = 'Red' }) -Width 0 -NoEmit).Count | Should -Be 0
        }

        It 'flattens nested segment arrays' {
            $segments = @(
                @(
                    @{ Text = 'A'; Color = 'Gray' },
                    @{ Text = 'B'; Color = 'Gray' }
                )
            )
            $result = Write-ColorSegments -Segments $segments -Width 4 -NoEmit
            (($result | ForEach-Object { $_.Text }) -join '') | Should -Be 'AB  '
        }
    }
}

Describe 'Segment builders' {
    InModuleScope 'Render' {
        It 'builds unselected idea segments with semantic colors' {
            $idea = [pscustomobject]@{ Id = 'FI-1'; Title = 'Title' }
            $segments = Build-IdeaSegments -Marker '│' -Idea $idea -IsSelected $false
            $segments.Count | Should -Be 3
            $segments[0].Color | Should -Be 'DarkGray'
            $segments[1].Color | Should -Be 'DarkGray'
            $segments[2].Color | Should -Be 'Gray'
        }

        It 'builds selected idea segments with focus colors' {
            $idea = [pscustomobject]@{ Id = 'FI-2'; Title = 'Chosen' }
            $segments = Build-IdeaSegments -Marker '>' -Idea $idea -IsSelected $true
            $segments[0].Color | Should -Be 'Cyan'
            $segments[1].Color | Should -Be 'DarkGray'
            $segments[2].Color | Should -Be 'White'
        }

        It 'builds scrollbar-only row as marker segment' {
            $segments = Build-IdeaSegments -Marker '░' -Idea $null -IsSelected $false
            $segments.Count | Should -Be 1
            $segments[0].Color | Should -Be 'Gray'
        }

        It 'builds detail rows with semantic label and value colors' {
            $idea = [pscustomobject]@{
                Id = 'FI-9'
                Priority = 'P2'
                Effort = 'M'
                Risk = 'H'
                Tags = @('alpha', 'beta')
                Summary = 'Summary text'
                Rationale = 'Rationale text'
            }

            $rows = Build-DetailSegments -Idea $idea
            $rows.Count | Should -Be 6

            $idRowText = ($rows[0] | ForEach-Object { $_.Text }) -join ''
            $metaRowText = ($rows[1] | ForEach-Object { $_.Text }) -join ''
            $summaryRowText = ($rows[4] | ForEach-Object { $_.Text }) -join ''
            $rationaleRowText = ($rows[5] | ForEach-Object { $_.Text }) -join ''

            $idRowText | Should -Match '^ID: FI-9$'
            $metaRowText | Should -Match 'Priority: P2'
            $metaRowText | Should -Match 'Effort: M'
            $metaRowText | Should -Match 'Risk: H'
            $summaryRowText | Should -Match '^Summary: Summary text$'
            $rationaleRowText | Should -Match '^Rationale: Rationale text$'

            $priorityLabelColor = ($rows[1] | Where-Object { $_.Text -eq 'Priority: ' } | Select-Object -First 1).Color
            $priorityValueColor = ($rows[1] | Where-Object { $_.Text -eq 'P2' } | Select-Object -First 1).Color
            $riskLabelColor = ($rows[1] | Where-Object { $_.Text -eq '  Risk: ' } | Select-Object -First 1).Color
            $riskValueColor = ($rows[1] | Where-Object { $_.Text -eq 'H' } | Select-Object -First 1).Color

            $priorityLabelColor | Should -Not -Be $priorityValueColor
            $riskLabelColor | Should -Not -Be $riskValueColor
        }

        It 'handles missing detail fields safely' {
            $idea = [pscustomobject]@{ Id = 'FI-empty' }
            $rows = Build-DetailSegments -Idea $idea
            $rows.Count | Should -Be 6
            $rows[2][1].Text | Should -Be ''
            $rows[4][1].Text | Should -Be ''
            $rows[5][1].Text | Should -Be ''
        }
    }
}

Describe 'Box helpers' {
    InModuleScope 'Render' {
        It 'builds a top border with rounded corners and centered title' {
            $segments = Build-BoxTopSegments -Title '[Tags]' -Width 12 -BorderColor 'DarkGray' -TitleColor 'Cyan'
            $text = ($segments | ForEach-Object { $_.Text }) -join ''
            $text.Length | Should -Be 12
            $text[0] | Should -Be '╭'
            $text[11] | Should -Be '╮'
            $text | Should -Match '\[Tags\]'
        }

        It 'builds a bottom border with rounded corners' {
            $segments = Build-BoxBottomSegments -Width 10 -BorderColor 'DarkGray'
            $text = ($segments | ForEach-Object { $_.Text }) -join ''
            $text.Length | Should -Be 10
            $text[0] | Should -Be '╰'
            $text[9] | Should -Be '╯'
        }

        It 'builds bordered rows with vertical side rails' {
            $segments = Build-BorderedRowSegments -InnerSegments @(@{ Text = 'abc'; Color = 'Gray' }) -Width 8 -BorderColor 'DarkGray'
            $text = ($segments | ForEach-Object { $_.Text }) -join ''
            $text.Length | Should -Be 8
            $text[0] | Should -Be '│'
            $text[7] | Should -Be '│'
        }
    }
}

Describe 'Render-BrowserState' {
    InModuleScope 'Render' {
        BeforeEach {
            $script:PreviousFrame = $null
        }

        It 'clears the host, prints resize guidance, and drops the cached frame in TooSmall mode' {
            Mock -CommandName Clear-Host -ModuleName Render {}
            Mock -CommandName Write-Host -ModuleName Render {}

            $state = New-RenderStateFixture -Width 50 -Height 10
            $state.Ui.Layout = [pscustomobject]@{
                Mode = 'TooSmall'
                MinWidth = 60
                MinHeight = 16
                Width = 50
                Height = 10
                StatusPane = [pscustomobject]@{ X = 0; Y = 9; W = 50; H = 1 }
            }
            $script:PreviousFrame = [pscustomobject]@{ Width = 1; Height = 1; Rows = @() }

            Render-BrowserState -State $state

            Assert-MockCalled -CommandName Clear-Host -ModuleName Render -Times 1 -Exactly
            Assert-MockCalled -CommandName Write-Host -ModuleName Render -Times 2 -Exactly
            $script:PreviousFrame | Should -BeNullOrEmpty
        }

        It 'builds, diffs, and caches the frame after a successful flush' {
            $state = New-RenderStateFixture
            $frame = [pscustomobject]@{
                Width = $state.Ui.Layout.Width
                Height = $state.Ui.Layout.Height
                Rows = @([pscustomobject]@{ Y = 0; Signature = 'row-0'; Segments = @() })
            }

            Mock -CommandName Build-FrameFromState -ModuleName Render { return $frame }
            Mock -CommandName Get-FrameDiff -ModuleName Render { return @($frame.Rows[0]) }
            Mock -CommandName Flush-FrameDiff -ModuleName Render { return $true }

            Render-BrowserState -State $state

            Assert-MockCalled -CommandName Build-FrameFromState -ModuleName Render -Times 1 -Exactly
            Assert-MockCalled -CommandName Get-FrameDiff -ModuleName Render -Times 1 -Exactly
            Assert-MockCalled -CommandName Flush-FrameDiff -ModuleName Render -Times 1 -Exactly
            $script:PreviousFrame | Should -Be $frame
        }
    }
}
