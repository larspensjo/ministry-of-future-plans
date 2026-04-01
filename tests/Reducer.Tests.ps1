$modulePath = Join-Path $PSScriptRoot '..\browser\Reducer.psm1'
Import-Module $modulePath -Force

Describe 'Browser reducer' {
    BeforeEach {
        $ideas = @(
            [pscustomobject]@{ Id = 'FI-1'; Title = 'One'; Tags = @('a'); Priority = 'P1'; Risk = 'M'; Captured = [datetime]'2026-02-10'; Summary='S1'; Rationale='R1'; Effort='M' },
            [pscustomobject]@{ Id = 'FI-2'; Title = 'Two'; Tags = @('a', 'b'); Priority = 'P2'; Risk = 'L'; Captured = [datetime]'2026-02-09'; Summary='S2'; Rationale='R2'; Effort='S' },
            [pscustomobject]@{ Id = 'FI-3'; Title = 'Three'; Tags = @('b', 'c'); Priority = 'P3'; Risk = 'H'; Captured = [datetime]'2026-02-08'; Summary='S3'; Rationale='R3'; Effort='L' }
        )
        $state = New-BrowserState -Ideas $ideas -InitialWidth 120 -InitialHeight 40
    }

    It 'toggles active pane with SwitchPane' {
        $next = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $next.Ui.ActivePane | Should -Be 'Ideas'
    }

    It 'clamps idea index at max when moving down' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })

        $state.Cursor.IdeaIndex | Should -Be 2
    }

    It 'moves up without going below zero in both panes' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })
        $state.Cursor.TagIndex | Should -Be 1

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveUp' })
        $state.Cursor.TagIndex | Should -Be 0

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })
        $state.Cursor.IdeaIndex | Should -Be 1

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveUp' })
        $state.Cursor.IdeaIndex | Should -Be 0

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveUp' })
        $state.Cursor.IdeaIndex | Should -Be 0
    }

    It 'supports PageDown/PageUp in ideas pane' {
        $state = New-BrowserState -Ideas $ideas -InitialWidth 120 -InitialHeight 16
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'PageDown' })
        $state.Cursor.IdeaIndex | Should -BeGreaterThan 0

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'PageUp' })
        $state.Cursor.IdeaIndex | Should -Be 0
    }

    It 'supports Home/End in ideas pane' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveEnd' })
        $state.Cursor.IdeaIndex | Should -Be 2

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveHome' })
        $state.Cursor.IdeaIndex | Should -Be 0
    }

    It 'supports Home/End in tags pane' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveEnd' })
        $state.Cursor.TagIndex | Should -Be 2

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveHome' })
        $state.Cursor.TagIndex | Should -Be 0
    }

    It 'scrolls tags as soon as cursor moves past last visible tag row' {
        $manyIdeas = @()
        for ($i = 0; $i -lt 20; $i++) {
            $manyIdeas += [pscustomobject]@{
                Id = "FI-T-$i"
                Title = "Tag $i"
                Tags = @("t$i")
                Priority = 'P2'
                Risk = 'M'
                Captured = [datetime]'2026-02-10'
                Summary = 'S'
                Rationale = 'R'
                Effort = 'M'
            }
        }

        $state = New-BrowserState -Ideas $manyIdeas -InitialWidth 120 -InitialHeight 16
        for ($n = 0; $n -lt 13; $n++) {
            $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })
        }

        $state.Cursor.TagIndex | Should -Be 13
        $state.Cursor.TagScrollTop | Should -Be 1
    }

    It 'resets idea index after filter change' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })
        $state.Cursor.IdeaIndex | Should -Be 1

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag'; Tag = 'b' })
        $state.Cursor.IdeaIndex | Should -Be 0
        $state.Derived.VisibleIdeaIds | Should -Be @('FI-2', 'FI-3')
    }

    It 'supports multi-action sequence with consistent state' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag'; Tag = 'a' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'MoveDown' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag'; Tag = 'b' })

        $state.Derived.VisibleIdeaIds | Should -Be @('FI-2')
        $state.Cursor.IdeaIndex | Should -Be 0
        $state.Query.SelectedTags.Contains('a') | Should -BeTrue
        $state.Query.SelectedTags.Contains('b') | Should -BeTrue
    }

    It 'toggles current tag when action has no Tag property' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag' })
        $state.Query.SelectedTags.Contains('a') | Should -BeTrue
    }

    It 'derives unavailable tags from selected filters' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag'; Tag = 'a' })
        $tagC = $state.Derived.VisibleTags | Where-Object Name -eq 'c' | Select-Object -First 1
        $tagC.IsSelectable | Should -BeFalse
        $tagC.MatchCount | Should -Be 0
    }

    It 'can hide unavailable tags with toggle action' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag'; Tag = 'a' })
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleHideUnavailableTags' })

        $names = @($state.Derived.VisibleTags | ForEach-Object Name)
        $names -contains 'c' | Should -BeFalse
        $state.Ui.HideUnavailableTags | Should -BeTrue
    }

    It 'keeps cursor on same tag identity in hide mode when toggling twice' {
        $ideas = @(
            [pscustomobject]@{ Id = 'FI-1'; Title = 'One'; Tags = @('a', 'd'); Priority = 'P1'; Risk = 'M'; Captured = [datetime]'2026-02-10'; Summary='S1'; Rationale='R1'; Effort='M' },
            [pscustomobject]@{ Id = 'FI-2'; Title = 'Two'; Tags = @('b', 'd'); Priority = 'P2'; Risk = 'L'; Captured = [datetime]'2026-02-09'; Summary='S2'; Rationale='R2'; Effort='S' },
            [pscustomobject]@{ Id = 'FI-3'; Title = 'Three'; Tags = @('e', 'd'); Priority = 'P3'; Risk = 'H'; Captured = [datetime]'2026-02-08'; Summary='S3'; Rationale='R3'; Effort='L' },
            [pscustomobject]@{ Id = 'FI-4'; Title = 'Four'; Tags = @('c'); Priority = 'P3'; Risk = 'H'; Captured = [datetime]'2026-02-07'; Summary='S4'; Rationale='R4'; Effort='L' }
        )
        $state = New-BrowserState -Ideas $ideas -InitialWidth 120 -InitialHeight 40
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleHideUnavailableTags' })

        $indexOfD = -1
        for ($i = 0; $i -lt $state.Derived.VisibleTags.Count; $i++) {
            if ($state.Derived.VisibleTags[$i].Name -eq 'd') { $indexOfD = $i; break }
        }
        $state.Cursor.TagIndex = $indexOfD

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag' })
        $state.Query.SelectedTags.Contains('d') | Should -BeTrue

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'ToggleTag' })
        $state.Query.SelectedTags.Contains('d') | Should -BeFalse
    }

    It 'marks runtime as stopped on quit' {
        $next = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'Quit' })
        $next.Runtime.IsRunning | Should -BeFalse
    }

    It 'updates layout on resize, including TooSmall mode' {
        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'Resize'; Width = 59; Height = 15 })
        $state.Ui.Layout.Mode | Should -Be 'TooSmall'

        $state = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'Resize'; Width = 120; Height = 40 })
        $state.Ui.Layout.Mode | Should -Be 'Normal'
        $state.Ui.Layout.Width | Should -Be 120
        $state.Ui.Layout.Height | Should -Be 40
    }

    It 'recomputes derived state for unknown actions without mutating runtime' {
        $state.Query.SearchText = 'Three'
        $state.Query.SearchMode = 'Text'
        $state.Derived.VisibleIdeaIds = @('stale')

        $next = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'UnknownAction' })

        $next.Derived.VisibleIdeaIds | Should -Be @('FI-3')
        $next.Runtime.IsRunning | Should -BeTrue
    }

    It 'ignores ToggleTag without a tag when no visible tags exist' {
        $emptyState = New-BrowserState -Ideas @(
            [pscustomobject]@{
                Id = 'FI-empty'
                Title = 'Empty tags'
                Tags = @()
                Priority = 'P2'
                Risk = 'M'
                Captured = [datetime]'2026-02-10'
                Summary = 'S'
                Rationale = 'R'
                Effort = 'M'
            }
        ) -InitialWidth 120 -InitialHeight 40

        $next = Invoke-BrowserReducer -State $emptyState -Action ([pscustomobject]@{ Type = 'ToggleTag' })

        $next.Derived.VisibleTags.Count | Should -Be 0
        $next.Query.SelectedTags.Count | Should -Be 0
        $next.Cursor.TagIndex | Should -Be 0
    }

    It 'uses a single-row viewport behavior when layout is TooSmall' {
        $smallState = New-BrowserState -Ideas $ideas -InitialWidth 59 -InitialHeight 15
        $smallState.Ui.Layout.Mode | Should -Be 'TooSmall'

        $smallState = Invoke-BrowserReducer -State $smallState -Action ([pscustomobject]@{ Type = 'SwitchPane' })
        $smallState = Invoke-BrowserReducer -State $smallState -Action ([pscustomobject]@{ Type = 'PageDown' })

        $smallState.Cursor.IdeaIndex | Should -Be 1
        $smallState.Cursor.IdeaScrollTop | Should -Be 1
    }
}
