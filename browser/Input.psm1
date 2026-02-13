Set-StrictMode -Version Latest

function ConvertFrom-KeyInfoToAction {
    param(
        [Parameter(Mandatory = $true)][System.ConsoleKeyInfo]$KeyInfo
    )

    switch ($KeyInfo.Key) {
        'Q' { return [pscustomobject]@{ Type = 'Quit' } }
        'Tab' { return [pscustomobject]@{ Type = 'SwitchPane' } }
        'UpArrow' { return [pscustomobject]@{ Type = 'MoveUp' } }
        'DownArrow' { return [pscustomobject]@{ Type = 'MoveDown' } }
        'Spacebar' { return [pscustomobject]@{ Type = 'ToggleTag' } }
        default { return $null }
    }
}

Export-ModuleMember -Function ConvertFrom-KeyInfoToAction
