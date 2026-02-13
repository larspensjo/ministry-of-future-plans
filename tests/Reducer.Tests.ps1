$modulePath = Join-Path $PSScriptRoot '..\browser\Reducer.psm1'
Import-Module $modulePath -Force

Describe 'Browser reducer' {
    BeforeEach {
        $ideas = @(
            [pscustomobject]@{ Id = 'FI-1'; Title = 'One'; Tags = @('a'); Priority = 'P1'; Risk = 'M'; Captured = [datetime]'2026-02-10'; Summary='S1'; Rationale='R1'; Effort='M' },
            [pscustomobject]@{ Id = 'FI-2'; Title = 'Two'; Tags = @('a', 'b'); Priority = 'P2'; Risk = 'L'; Captured = [datetime]'2026-02-09'; Summary='S2'; Rationale='R2'; Effort='S' },
            [pscustomobject]@{ Id = 'FI-3'; Title = 'Three'; Tags = @('b'); Priority = 'P3'; Risk = 'H'; Captured = [datetime]'2026-02-08'; Summary='S3'; Rationale='R3'; Effort='L' }
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

    It 'marks runtime as stopped on quit' {
        $next = Invoke-BrowserReducer -State $state -Action ([pscustomobject]@{ Type = 'Quit' })
        $next.Runtime.IsRunning | Should -BeFalse
    }
}
