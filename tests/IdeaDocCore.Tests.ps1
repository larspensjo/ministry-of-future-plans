$modulePath = Join-Path $PSScriptRoot '..\common\IdeaDocCore.psm1'
Import-Module $modulePath -Force

Describe 'ConvertFrom-TagString' {
    It 'parses standard bracketed list' {
        (ConvertFrom-TagString '[one, two]') | Should -Be @('one', 'two')
    }

    It 'parses without spaces' {
        (ConvertFrom-TagString '[one,two]') | Should -Be @('one', 'two')
    }

    It 'parses extra whitespace and trailing commas' {
        (ConvertFrom-TagString '[ one , two , ]') | Should -Be @('one', 'two')
    }

    It 'returns empty array for empty brackets' {
        (ConvertFrom-TagString '[]') | Should -Be @()
    }

    It 'accepts non-bracket fallback' {
        (ConvertFrom-TagString 'one, two') | Should -Be @('one', 'two')
    }
}

Describe 'ConvertFrom-IdeaDoc typed entries' {
    It 'parses typed fields and sections' {
        $lines = @(
            '# Future Ideas Backlog',
            '',
            '## Taxonomy',
            '',
            '## UX',
            '',
            '### PreviewRich',
            '',
            '#### [FI-UX-PreviewRich-0001] Rich preview mode',
            'Status: Candidate',
            'TopLevel: UX',
            'SubLevel: PreviewRich',
            'Priority: P2',
            'Effort: M',
            'Risk: L',
            'Origin:',
            '- SourceDoc: Plan.A.md',
            '- SourceSection: Future',
            '- Captured: 2026-02-13',
            'Tags: [ux, preview]',
            'Summary: Summary text',
            'Rationale: Rationale text',
            'SuccessCriteria:',
            '- First criterion',
            'Dependencies: [FI-UX-PreviewRich-0002]',
            'Related: [FI-UX-PreviewRich-0003]'
        )

        $doc = ConvertFrom-IdeaDoc -Lines $lines
        $doc.Entries.Count | Should -Be 1

        $entry = $doc.Entries[0]
        $entry.Id | Should -Be 'FI-UX-PreviewRich-0001'
        $entry.TopLevel | Should -Be 'UX'
        $entry.SubLevel | Should -Be 'PreviewRich'
        $entry.Tags | Should -Be @('ux', 'preview')
        $entry.OriginSourceDoc | Should -Be 'Plan.A.md'
        $entry.OriginSection | Should -Be 'Future'
        $entry.CapturedRaw | Should -Be '2026-02-13'
        ($entry.Captured -is [datetime]) | Should -BeTrue
        $entry.SuccessCriteria | Should -Be @('First criterion')
        $entry.Dependencies | Should -Be @('FI-UX-PreviewRich-0002')
        $entry.Related | Should -Be @('FI-UX-PreviewRich-0003')
        $entry.LineNumber | Should -BeGreaterThan 0
    }

    It 'parses multiple groups and entries in one document' {
        $lines = @(
            '# Future Ideas Backlog',
            '',
            '## UX',
            '',
            '### PreviewRich',
            '',
            '#### [FI-UX-PreviewRich-0001] Rich preview mode',
            'Status: Candidate',
            'Priority: P2',
            'Effort: M',
            'Risk: L',
            'Tags: [ux, preview]',
            'Summary: Summary one',
            'Rationale: Rationale one',
            '',
            '## Simulation',
            '',
            '### Logistics',
            '',
            '#### [FI-Sim-Logistics-0002] Reroute queues',
            'Status: Candidate',
            'Priority: P1',
            'Effort: S',
            'Risk: M',
            'Tags: [sim, logistics]',
            'Summary: Summary two',
            'Rationale: Rationale two'
        )

        $doc = ConvertFrom-IdeaDoc -Lines $lines
        $doc.Groups.Count | Should -Be 4
        $doc.Entries.Count | Should -Be 2
        $doc.Entries[0].TopLevel | Should -Be 'UX'
        $doc.Entries[0].SubLevel | Should -Be 'PreviewRich'
        $doc.Entries[1].TopLevel | Should -Be 'Simulation'
        $doc.Entries[1].SubLevel | Should -Be 'Logistics'
    }

    It 'uses empty defaults when optional sections are absent' {
        $lines = @(
            '# Future Ideas Backlog',
            '',
            '## UX',
            '',
            '### PreviewRich',
            '',
            '#### [FI-UX-PreviewRich-0005] Minimal entry',
            'Status: Candidate',
            'Priority: P3',
            'Effort: S',
            'Risk: M',
            'Tags: []',
            'Summary: Summary only',
            'Rationale: Rationale only'
        )

        $doc = ConvertFrom-IdeaDoc -Lines $lines
        $entry = $doc.Entries[0]

        $entry.SuccessCriteria | Should -Be @()
        $entry.Dependencies | Should -Be @()
        $entry.Related | Should -Be @()
        $entry.OriginSourceDoc | Should -BeNullOrEmpty
        $entry.OriginSection | Should -BeNullOrEmpty
        $entry.CapturedRaw | Should -BeNullOrEmpty
        $entry.Captured | Should -BeNullOrEmpty
    }

    It 'preserves malformed captured values without forcing a datetime' {
        $lines = @(
            '# Future Ideas Backlog',
            '',
            '## UX',
            '',
            '### PreviewRich',
            '',
            '#### [FI-UX-PreviewRich-0006] Invalid capture',
            'Status: Candidate',
            'Priority: P2',
            'Effort: M',
            'Risk: L',
            'Origin:',
            '- Captured: not-a-date',
            'Tags: [ux]',
            'Summary: Summary text',
            'Rationale: Rationale text'
        )

        $doc = ConvertFrom-IdeaDoc -Lines $lines
        $entry = $doc.Entries[0]

        $entry.CapturedRaw | Should -Be 'not-a-date'
        $entry.Captured | Should -BeNullOrEmpty
    }
}

Describe 'Get-SectionPresence API shape' {
    It 'returns indexes and legacy aliases' {
        $entryLines = @(
            'Header: value',
            'Origin:',
            '- SourceDoc: Plan.A.md',
            '- SourceSection: Future',
            'Tags: [a]'
        )

        $section = Get-SectionPresence -EntryLines $entryLines -Header 'Origin'
        $section.Found | Should -BeTrue
        $section.StartIndex | Should -Be 1
        $section.EndIndex | Should -Be 3
        $section.Start | Should -Be 1
        $section.End | Should -Be 3
        $section.Items.Count | Should -Be 2
    }

    It 'returns not found shape when the section is absent' {
        $entryLines = @(
            'Header: value',
            'Tags: [a]'
        )

        $section = Get-SectionPresence -EntryLines $entryLines -Header 'Origin'
        $section.Found | Should -BeFalse
        $section.StartIndex | Should -Be -1
        $section.EndIndex | Should -Be -1
        $section.Items | Should -Be @()
    }
}
