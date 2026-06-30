param(
    [string]$ModuleXml,
    [string]$JarName
)

$localEntry  = "    <resource-root path=`"./local/$JarName`" />"
$t24libEntry = "    <resource-root path=`"./t24lib/$JarName`" />"

$content = Get-Content $ModuleXml -Raw

# Already registered in local - nothing to do
if ($content -match [regex]::Escape("./local/$JarName")) {
    Write-Host "   Already registered: $JarName"
    exit 0
}

# Insert ./local/ entry before the matching ./t24lib/ entry if one exists.
# This ensures our custom JAR is loaded before the standard one so it wins.
if ($content -match [regex]::Escape($t24libEntry)) {
    $content = $content -replace [regex]::Escape($t24libEntry), "$localEntry`n$t24libEntry"
    Write-Host "   Registered (override): $JarName"
} else {
    $content = $content -replace '</resources>', "$localEntry`n  </resources>"
    Write-Host "   Registered: $JarName"
}

Set-Content $ModuleXml $content -NoNewline
exit 0
