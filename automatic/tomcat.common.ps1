# Shared update logic for the Apache Tomcat packages.
# Each package update.ps1 dot-sources this file and provides its major version.
# Functions are global because AU calls the au_* hooks from its own module scope.

function global:Get-TomcatLatest {
    param(
        [Parameter(Mandatory)] [int] $MajorVersion,
        [switch] $NoX86
    )

    $releaseTagsUrl = 'https://api.github.com/repos/apache/tomcat/git/refs/tags'
    $baseUrl = 'https://archive.apache.org/dist/tomcat'
    $preReleaseSuffix = '-M\d+$'
    $urlFormat = '{0}/tomcat-{1}/v{2}/bin/apache-tomcat-{2}-windows-{3}.zip{4}'

    # Authenticate when a token is available to avoid GitHub API rate limits on CI runners
    $headers = @{}
    if ($env:github_api_key) { $headers.Authorization = "Bearer $env:github_api_key" }

    $tags = Invoke-RestMethod -Uri $releaseTagsUrl -Headers $headers
    # Skip pre-release versions and sort by version number
    $tags = $tags.Where{ $_.ref -NotMatch $preReleaseSuffix } |
        Sort-Object {
            try { [version]($_.ref.Substring(10)) }
            catch { [version]'0.0.0' }
        } -Descending

    foreach ($tag in $tags) {
        $version = $tag.ref.Substring(10) # remove the "refs/tags/" prefix
        if (($version.Split('.') | Select-Object -First 1) -ne "$MajorVersion") { continue }

        # A version is only usable once its Windows binaries are published
        $checksum64Url = $urlFormat -f $baseUrl, $MajorVersion, $version, 'x64', '.sha512'
        if (-not (Test-TomcatUrl $checksum64Url)) { continue }

        $versionInfo = @{
            Version        = $version
            URL64          = $urlFormat -f $baseUrl, $MajorVersion, $version, 'x64', ''
            Checksum64Url  = $checksum64Url
            ChecksumType64 = 'sha512'
        }

        if (-not $NoX86) {
            $checksum32Url = $urlFormat -f $baseUrl, $MajorVersion, $version, 'x86', '.sha512'
            if (-not (Test-TomcatUrl $checksum32Url)) { continue }
            $versionInfo.URL32 = $urlFormat -f $baseUrl, $MajorVersion, $version, 'x86', ''
            $versionInfo.Checksum32Url = $checksum32Url
            $versionInfo.ChecksumType32 = 'sha512'
        }

        return $versionInfo
    }

    throw "No published release found for Tomcat $MajorVersion"
}

function global:Test-TomcatUrl([string] $Url) {
    try {
        $null = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing
        return $true
    } catch {
        return $false
    }
}

function global:Test-TomcatChecksums {
    # Compare the downloaded file hashes with the checksums published by Apache
    foreach ($bitness in 32, 64) {
        $checksumUrl = $Latest."Checksum${bitness}Url"
        if (-not $checksumUrl) { continue }
        $expected = ((Invoke-RestMethod -Uri $checksumUrl) -split '\s+')[0]
        $actual = $Latest."Checksum${bitness}"
        if ($expected -ne $actual) {
            throw "Checksum mismatch for $($Latest."URL${bitness}"): expected $expected, got $actual"
        }
    }
}

function global:Get-TomcatSearchReplace {
    $folderName = 'apache-tomcat-{0}' -f $Latest.Version
    $result = @{
        'tools\VERIFICATION.txt' = @{
            '^SHA-512 of 64-bit:.*' = 'SHA-512 of 64-bit: {0}' -f $Latest.Checksum64
            '^64-bit:.*' = '64-bit: {0}' -f $Latest.Checksum64Url
        }
        'tools\chocolateyInstall.ps1' = @{
            '[$]filename64 =.*' = '$filename64 = "{0}"' -f (Split-Path -Path $Latest.URL64 -Leaf)
            '[$]zipContentFolderName =.*' = '$zipContentFolderName = "{0}"' -f $folderName
        }
        'tools\chocolateyUninstall.ps1' = @{
            '[$]zipContentFolderName =.*' = '$zipContentFolderName = "{0}"' -f $folderName
        }
    }

    if ($Latest.URL32) {
        $result['tools\VERIFICATION.txt']['^SHA-512 of 32-bit:.*'] = 'SHA-512 of 32-bit: {0}' -f $Latest.Checksum32
        $result['tools\VERIFICATION.txt']['^32-bit:.*'] = '32-bit: {0}' -f $Latest.Checksum32Url
        $result['tools\chocolateyInstall.ps1']['[$]filename32 =.*'] = '$filename32 = "{0}"' -f (Split-Path -Path $Latest.URL32 -Leaf)
    }

    return $result
}
