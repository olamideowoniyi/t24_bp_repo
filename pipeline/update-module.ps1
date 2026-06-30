param(
    [string]$ModuleXml,
    [string]$JarName
)

$entry = "  <resource-root path=`"./local/$JarName`" />"
$content = Get-Content $ModuleXml -Raw

if ($content -notmatch [regex]::Escape($JarName)) {
    $content = $content -replace '</resources>', "$entry`n  </resources>"
    Set-Content $ModuleXml $content -NoNewline
    Write-Host "   Registered $JarName in module.xml"
} else {
    Write-Host "   Already registered: $JarName"
}
