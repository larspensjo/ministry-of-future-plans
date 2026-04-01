Describe 'Get-VisibleIdeaIds' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\browser\Filtering.psm1'
        Import-Module $modulePath -Force

        $ideas = @(
            [pscustomobject]@{ Id = 'FI-A-0001'; Title = 'Alpha'; Tags = @('ux', 'preview'); Priority = 'P2'; Risk = 'M'; Captured = [datetime]'2026-02-10' },
            [pscustomobject]@{ Id = 'FI-A-0002'; Title = 'Beta'; Tags = @('ux'); Priority = 'P1'; Risk = 'H'; Captured = [datetime]'2026-02-12' },
            [pscustomobject]@{ Id = 'FI-A-0003'; Title = 'Gamma'; Tags = @('security'); Priority = 'P1'; Risk = 'L'; Captured = [datetime]'2026-02-11' }
        )
    }

    It 'returns all ids when selected tags is null' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags $null
        $ids | Should -Be @('FI-A-0001', 'FI-A-0002', 'FI-A-0003')
    }

    It 'uses AND semantics for tags' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags @('ux', 'preview')
        $ids | Should -Be @('FI-A-0001')
    }

    It 'returns empty result when no idea matches' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags @('does-not-exist')
        $ids.Count | Should -Be 0
    }

    It 'has stable tie-breaker by id for same priority' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags @() -SortMode Priority
        $ids | Should -Be @('FI-A-0002', 'FI-A-0003', 'FI-A-0001')
    }

    It 'accepts scalar selected tag input' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags 'ux'
        $ids | Should -Be @('FI-A-0001', 'FI-A-0002')
    }

    It 'ignores whitespace-only selected tag input' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags '   '
        $ids | Should -Be @('FI-A-0001', 'FI-A-0002', 'FI-A-0003')
    }

    It 'filters titles in text search mode case-insensitively' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags @() -SearchText 'alp' -SearchMode Text
        $ids | Should -Be @('FI-A-0001')
    }

    It 'filters titles in regex search mode' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags @() -SearchText '^(Alpha|Gamma)$' -SearchMode Regex
        $ids | Should -Be @('FI-A-0001', 'FI-A-0003')
    }

    It 'falls back to tag-only filtering when regex search text is invalid' {
        $ids = Get-VisibleIdeaIds -AllIdeas $ideas -SelectedTags 'ux' -SearchText '[' -SearchMode Regex
        $ids | Should -Be @('FI-A-0001', 'FI-A-0002')
    }

    It 'sorts by risk severity with stable id tie-breaker' {
        $riskIdeas = @(
            [pscustomobject]@{ Id = 'FI-A-0004'; Title = 'Delta'; Tags = @('ops'); Priority = 'P3'; Risk = 'H'; Captured = [datetime]'2026-02-07' },
            [pscustomobject]@{ Id = 'FI-A-0002'; Title = 'Beta'; Tags = @('ux'); Priority = 'P1'; Risk = 'H'; Captured = [datetime]'2026-02-12' },
            [pscustomobject]@{ Id = 'FI-A-0001'; Title = 'Alpha'; Tags = @('ux', 'preview'); Priority = 'P2'; Risk = 'M'; Captured = [datetime]'2026-02-10' },
            [pscustomobject]@{ Id = 'FI-A-0003'; Title = 'Gamma'; Tags = @('security'); Priority = 'P1'; Risk = 'L'; Captured = [datetime]'2026-02-11' }
        )

        $ids = Get-VisibleIdeaIds -AllIdeas $riskIdeas -SelectedTags @() -SortMode Risk
        $ids | Should -Be @('FI-A-0002', 'FI-A-0004', 'FI-A-0001', 'FI-A-0003')
    }

    It 'sorts by captured date descending with stable id tie-breaker' {
        $capturedIdeas = @(
            [pscustomobject]@{ Id = 'FI-A-0003'; Title = 'Gamma'; Tags = @('security'); Priority = 'P1'; Risk = 'L'; Captured = [datetime]'2026-02-11' },
            [pscustomobject]@{ Id = 'FI-A-0004'; Title = 'Delta'; Tags = @('ops'); Priority = 'P3'; Risk = 'H'; Captured = [datetime]'2026-02-12' },
            [pscustomobject]@{ Id = 'FI-A-0002'; Title = 'Beta'; Tags = @('ux'); Priority = 'P1'; Risk = 'H'; Captured = [datetime]'2026-02-12' },
            [pscustomobject]@{ Id = 'FI-A-0001'; Title = 'Alpha'; Tags = @('ux', 'preview'); Priority = 'P2'; Risk = 'M'; Captured = [datetime]'2026-02-10' }
        )

        $ids = Get-VisibleIdeaIds -AllIdeas $capturedIdeas -SelectedTags @() -SortMode CapturedDesc
        $ids | Should -Be @('FI-A-0002', 'FI-A-0004', 'FI-A-0003', 'FI-A-0001')
    }
}
