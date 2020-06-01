(docker login) -and (docker images --format '{{.Repository}}' |% { if ($_) { docker pull $_ }})

$dangling = $(docker images --filter "dangling=true" -q --no-trunc)
if ($dangling.Count -gt 0) { docker rmi $dangling }
