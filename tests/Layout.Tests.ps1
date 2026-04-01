Describe 'Get-BrowserLayout' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\browser\Layout.psm1'
        Import-Module $modulePath -Force
    }

    It 'returns TooSmall mode for small dimensions' {
        $layout = Get-BrowserLayout -Width 10 -Height 10
        $layout.Mode | Should -Be 'TooSmall'
    }

    It 'returns valid panes for normal dimensions' {
        $layout = Get-BrowserLayout -Width 120 -Height 40
        $layout.Mode | Should -Be 'Normal'
        $layout.TagPane.W | Should -BeGreaterThan 0
        $layout.ListPane.H | Should -BeGreaterThan 0
        $layout.DetailPane.H | Should -BeGreaterThan 0
    }

    It 'switches to normal mode exactly at the minimum supported size' {
        $layout = Get-BrowserLayout -Width 60 -Height 16
        $layout.Mode | Should -Be 'Normal'
        $layout.Width | Should -Be 60
        $layout.Height | Should -Be 16
    }

    It 'stays in TooSmall mode when either dimension is below the minimum' {
        (Get-BrowserLayout -Width 59 -Height 16).Mode | Should -Be 'TooSmall'
        (Get-BrowserLayout -Width 60 -Height 15).Mode | Should -Be 'TooSmall'
    }

    It 'keeps pane bounds non-overlapping and fully accounted for near the minimum size' {
        $layout = Get-BrowserLayout -Width 61 -Height 16

        $layout.TagPane.X | Should -Be 0
        $layout.TagPane.Y | Should -Be 0
        ($layout.TagPane.W + 1 + $layout.ListPane.W) | Should -Be $layout.Width
        $layout.ListPane.X | Should -Be ($layout.TagPane.W + 1)
        $layout.DetailPane.X | Should -Be $layout.ListPane.X
        $layout.DetailPane.W | Should -Be $layout.ListPane.W
        ($layout.ListPane.Y + $layout.ListPane.H) | Should -BeLessThan $layout.DetailPane.Y
        ($layout.DetailPane.Y + $layout.DetailPane.H) | Should -Be ($layout.StatusPane.Y)
        $layout.TagPane.H | Should -Be $layout.StatusPane.Y
        $layout.StatusPane.W | Should -Be $layout.Width
        $layout.StatusPane.H | Should -Be 1
    }
}
