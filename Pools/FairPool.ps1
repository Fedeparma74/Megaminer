param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$AbbName = 'FAIR'
$WalletMode = "WALLET"
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer            = "Must set wallet for each coin on web, set login on config.ini file"
        ActiveOnManualMode    = $ActiveOnManualMode
        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
        ApiData               = $true
        AbbName               = $AbbName
        WalletMode            = $WalletMode
        RewardType            = $RewardType
    }
}

if ($Querymode -eq "speed") {
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".fairpool.cloud/api/stats?login=" + ($Info.user -split "\+")[0]) -Retry 1

    if ($Request) {
        $Request.Workers | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                WorkerName = $_[0]
                HashRate   = $_[1]
            }
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "wallet") {
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".fairpool.cloud/api/stats?login=" + ($Info.User -split "\+")[0]) -Retry 3
    if ($Request) {
        switch ($Info.Symbol) {
            'pasl' { $Divisor = 10000 }
            'sumo' { $Divisor = 1000000000}
            'loki' { $Divisor = 1000000000}
            'xhv' { $Divisor = 1000000000000}
            'xrn' { $Divisor = 1000000000}
            Default { $Divisor = 1000000000 }
        }
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Info.Symbol
            balance  = ($Request.balance + $Request.unconfirmed ) / $Divisor
        }
        Remove-Variable Request
    }
}

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Pools = @()

    $Pools += [PSCustomObject]@{coin = "Akroma"; algo = "Ethash"; symbol = "AKA"; port = 2222; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "Dogethereum"; algo = "Ethash"; symbol = "DOGX"; port = 7788; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "Electroneum"; algo = "CryptoNight"; symbol = "ETN"; port = 8888; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "EthereumClassic"; algo = "Ethash"; symbol = "ETC"; port = 4444; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "Haven"; algo = "CryptoNightHeavy"; symbol = "XHV"; port = 5566; fee = 0.00}
    $Pools += [PSCustomObject]@{coin = "Loki"; algo = "CryptoNightHeavy"; symbol = "LOKI"; port = 5577; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "Metaverse"; algo = "Ethash"; symbol = "ETP"; port = 6666; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "Nekonium"; algo = "Ethash"; symbol = "NUKO"; port = 7777; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "PascalLite"; algo = "Pascal"; symbol = "PASL"; port = 4009; fee = 0.02}
    $Pools += [PSCustomObject]@{coin = "Pegascoin"; algo = "Ethash"; symbol = "PGC"; port = 1111; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "PURK"; algo = "Keccak"; symbol = "PURK"; port = 2244; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "Saronite"; algo = "CryptoNightHeavy"; symbol = "XRN"; port = 5599; fee = 0.01}
    $Pools += [PSCustomObject]@{coin = "Sumokoin"; algo = "CryptoNightHeavy"; symbol = "SUMO"; port = 5555; fee = 0.01}

    $Pools | ForEach-Object {
        if ($CoinsWallets.($_.symbol)) {
            $Result += [PSCustomObject]@{
                Algorithm             = $_.Algo
                Info                  = $_.Coin
                Protocol              = "stratum+tcp"
                Host                  = "mine." + $_.symbol + ".fairpool.cloud"
                Port                  = $_.Port
                User                  = $CoinsWallets.($_.symbol) + "+#WorkerName#"
                Pass                  = "x"
                Location              = "US"
                SSL                   = $false
                Symbol                = $_.symbol
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = $_.Symbol
                Fee                   = $_.Fee
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result
