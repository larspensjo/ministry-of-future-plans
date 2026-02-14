Describe 'Get-ScrollThumb' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\browser\Render.psm1'
        Import-Module $modulePath -Force
    }

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
