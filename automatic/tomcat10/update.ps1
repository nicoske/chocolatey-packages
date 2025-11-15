$ErrorActionPreference = 'Stop'

$releaseTagsUrl = 'https://api.github.com/repos/apache/tomcat/git/refs/tags'
$baseUrl = 'https://archive.apache.org/dist/tomcat'
$preReleaseSuffix = '-M\d+$'
$UrlFormat = "{0}/tomcat-{1}/v{2}/bin/apache-tomcat-{2}-windows-{3}.zip{4}"

function global:au_GetLatest {
    $tags = Invoke-RestMethod -Uri $releaseTagsUrl
    # Strip out any pre-release versions and sort by version number
    $tags = $tags.where{$_.ref -NotMatch $preReleaseSuffix} |
        Sort-Object {
            try { [version]($_.ref.Substring(10)) }
            catch { [version]"0.0.0" }
        } -Descending
    $i = 0
    $versionValid = $false
    $versionInfo = @{}

    # Find the most up to date version that is not a pre-release version
    do {
        $version = $tags[$i].ref.Substring(10) # remove prefix "refs/tags/"
        $majorVersion = $version.Split(".") | Select-Object -First 1

        $checksum32Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x86', '.sha512'
        $checksum64Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x64', '.sha512'
        $zip32Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x86', ''
        $zip64Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x64', ''

        If ($majorVersion -eq 10) {
            # Ensure that the version has binaries
            $versionValid = au_TestVersionExists -checksumUrl $checksum32Url

            If ($versionValid) {
                $versionInfo = @{
                    Version = $version
                    MajorVersion = $majorVersion
                    URL32 = $zip32Url
                    Checksum32Url = $checksum32Url
                    ChecksumType32 = 'sha512'
                    URL64 = $zip64Url
                    Checksum64Url = $checksum64Url
                    ChecksumType64 = 'sha512'
                }
            }
        }
        $i++
    } while (-Not $versionValid -and $i -lt $tags.Count)

    return $versionInfo
}

function au_TestVersionExists($checksumUrl) {
    $validVersion = $false

    try {
        # First we create the request.
        $HTTP_Request = [System.Net.WebRequest]::Create($checksumUrl)

        # We then get a response from the site.
        $HTTP_Response = $HTTP_Request.GetResponse()

        # We then get the HTTP code as an integer.
        $HTTP_Status = [int]$HTTP_Response.StatusCode

        If ($HTTP_Status -eq 200) {
            $validVersion = $true
        }

        # Finally, we clean up the http request by closing it.
        If ($null -eq $HTTP_Response) { }
        Else { $HTTP_Response.Close() }
    } catch {
        $validVersion = $false
    }

    return $validVersion
}

function global:au_BeforeUpdate { Get-RemoteFiles -Purge -NoSuffix -Algorithm sha512 }

function global:au_SearchReplace {
    $filename32 = Split-Path -Path $Latest.URL32 -Leaf
    $filename64 = Split-Path -Path $Latest.URL64 -Leaf
    $folderName = "apache-tomcat-{0}" -f $Latest.Version
    @{
        'tools\VERIFICATION.txt' = @{
            '^SHA-512 of 32-bit:.*' = 'SHA-512 of 32-bit: {0}' -f $Latest.Checksum32
            '^SHA-512 of 64-bit:.*' = 'SHA-512 of 64-bit: {0}' -f $Latest.Checksum64
            '^32-bit:.*' = '32-bit: {0}' -f $Latest.Checksum32Url
            '^64-bit:.*' = '64-bit: {0}' -f $Latest.Checksum64Url
        }
        'tools\chocolateyInstall.ps1' = @{
            '[$]filename32 =.*' = '$filename32 = "{0}"' -f $filename32
            '[$]filename64 =.*' = '$filename64 = "{0}"' -f $filename64
            '[$]zipContentFolderName =.*'= '$zipContentFolderName = "{0}"' -f $folderName
        }
        'tools\chocolateyUninstall.ps1' = @{
            '[$]zipContentFolderName =.*'= '$zipContentFolderName = "{0}"' -f $folderName
        }
    }
}

Update-Package -ChecksumFor none
