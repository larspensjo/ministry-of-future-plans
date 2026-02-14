$modulePath = Join-Path $PSScriptRoot '..\browser\Render.psm1'
Import-Module $modulePath -Force

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

Describe 'Color helpers' {
    InModuleScope 'Render' {
        It 'maps priority values to semantic colors' {
            Get-PriorityColor -Priority 'P0' | Should -Be 'Red'
            Get-PriorityColor -Priority 'P1' | Should -Be 'Red'
            Get-PriorityColor -Priority 'P2' | Should -Be 'Yellow'
            Get-PriorityColor -Priority 'P3' | Should -Be 'DarkCyan'
            Get-PriorityColor -Priority 'UNKNOWN' | Should -Be 'Gray'
        }

        It 'maps risk values to semantic colors' {
            Get-RiskColor -Risk 'H' | Should -Be 'Red'
            Get-RiskColor -Risk 'M' | Should -Be 'Yellow'
            Get-RiskColor -Risk 'L' | Should -Be 'DarkGray'
            Get-RiskColor -Risk 'UNKNOWN' | Should -Be 'Gray'
        }

        It 'maps marker glyphs with cursor precedence' {
            Get-MarkerColor -Marker '>' | Should -Be 'Cyan'
            Get-MarkerColor -Marker '░' | Should -Be 'Gray'
            Get-MarkerColor -Marker '│' | Should -Be 'DarkGray'
            Get-MarkerColor -Marker ' ' | Should -Be 'DarkGray'
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
            $result[0].Text | Should -Be 'ABCD...'
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
            $rows[0][0].Color | Should -Be 'DarkYellow'
            $rows[0][1].Color | Should -Be 'DarkGray'
            $rows[1][1].Color | Should -Be 'Yellow'
            $rows[1][5].Color | Should -Be 'Red'
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
            $text | Should -Be '╰────────╯'
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
