﻿param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = 'ZPOOL'
$WalletMode = 'WALLET'
$ApiUrl = 'http://www.zpool.ca/api'
$MineUrl = 'mine.zpool.ca'
$Location = 'US'
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to @@currency coin specified in config.ini, no registration required"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $True
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if ($Querymode -eq "speed") {
    $Request = Invoke-APIRequest -Url $($ApiUrl + "/walletEx?address=" + $Info.user) -Retry 1

    if ($Request) {
        $Result = $Request.Miners | ForEach-Object {
            [PSCustomObject]@{
                PoolName   = $Name
                Version    = $_.version
                Algorithm  = Get-AlgoUnifiedName $_.Algo
                WorkerName = (($_.password -split 'ID=')[1] -split ',')[0]
                Diff       = $_.difficulty
                Rejected   = $_.rejected
                HashRate   = $_.accepted
            }
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "wallet") {
    $Request = Invoke-APIRequest -Url $($ApiUrl + "/wallet?address=" + $Info.user) -Retry 3

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $Name
            Currency = $Request.currency
            Balance  = $Request.balance
        }
        Remove-Variable Request
    }
}

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Request = Invoke-APIRequest -Url $($ApiUrl + "/status") -Retry 3
    $RequestCurrencies = Invoke-APIRequest -Url $($ApiUrl + "/currencies") -Retry 3
    if (!$Request -or !$RequestCurrencies) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Currency = if ([string]::IsNullOrEmpty($(Get-ConfigVariable "CURRENCY_$Name"))) { Get-ConfigVariable "CURRENCY" } else { Get-ConfigVariable "CURRENCY_$Name" }

    if (
        $Currency -notin @('BTC') -and
        !($RequestCurrencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { $_ -eq $Currency })
    ) {
        Write-Host "$Name $Currency may not be supported for payment" -ForegroundColor Yellow
    }

    if (!$CoinsWallets.$Currency) {
        Write-Host "$Name $Currency wallet not defined in config.ini"
        Exit
    }

    $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $Request.$_.actual_last24h -gt 0 -and
        $Request.$_.HashRate -gt 0 -and
        $Request.$_.workers -gt 0
    } | ForEach-Object {

        $Algo = $Request.$_
        $Pool_Algo = Get-AlgoUnifiedName $Algo.name

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "Blake2s" {$Divisor *= 1000}
            "Blakecoin" {$Divisor *= 1000}
            "Decred" {$Divisor *= 1000}
            "Equihash" {$Divisor /= 1000}
            "Keccak" {$Divisor *= 1000}
            "KeccakC" {$Divisor *= 1000}
            "Quark" {$Divisor *= 1000}
            "Qubit" {$Divisor *= 1000}
            "Scrypt" {$Divisor *= 1000}
            "SHA256" {$Divisor *= 1000000000}
            "SHA256t" {$Divisor *= 1000}
            "X11" {$Divisor *= 1000}
            "X13" {$Divisor *= 1000}
            "Yescrypt" {$Divisor /= 1000}
            "YescryptR16" {$Divisor /= 1000}
        }

        $Result += [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_Algo
            Price                 = [decimal]$Algo.estimate_current / $Divisor
            Price24h              = [decimal]$Algo.estimate_last24h / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $Algo.name + "." + $MineUrl
            Port                  = $Algo.port
            User                  = $CoinsWallets.$Currency
            Pass                  = "c=$Currency,ID=#WorkerName#"
            Location              = $Location
            SSL                   = $false
            Symbol                = Get-CoinSymbol -Coin $Pool_Algo
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = $Algo.workers
            PoolHashRate          = $Algo.HashRate
            WalletMode            = $WalletMode
            WalletSymbol          = $Currency
            PoolName              = $Name
            Fee                   = $Algo.fees / 100
            RewardType            = $RewardType
        }
    }
    Remove-Variable Request
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
