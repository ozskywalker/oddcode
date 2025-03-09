#!/bin/bash

# Check if container name/id is provided
if [ -z "$1" ]; then
    echo "Error: Container name or ID is required."
    echo "Usage: $0 CONTAINER_NAME_OR_ID"
    echo "Example: $0 my_container"
    exit 1
fi

CONTAINER="$1"

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$" && ! docker ps -a --format '{{.ID}}' | grep -q "^${CONTAINER}"; then
    echo "Error: Container '${CONTAINER}' not found."
    echo "Available containers:"
    docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
    exit 1
fi

# Generate docker run command from container inspection
docker inspect "$CONTAINER" --format 'docker run \
{{- range $e := .Config.Env }} -e {{$e}}{{end}} \
{{- range $v := .HostConfig.Binds }} -v {{$v}}{{end}} \
{{- range $p, $conf := .HostConfig.PortBindings }}{{ with $conf }}{{ range . }} -p {{.HostPort}}:{{index (split $p "/") 0}}{{end}}{{end}}{{end}} \
{{- with .HostConfig.RestartPolicy }} --restart={{.Name}}{{if .MaximumRetryCount}}:{{.MaximumRetryCount}}{{end}}{{end}} \
{{- if .HostConfig.NetworkMode }} --network={{.HostConfig.NetworkMode}}{{end}} \
{{- if .HostConfig.Privileged }} --privileged{{end}} \
{{- if .Config.User }} -u {{.Config.User}}{{end}} \
{{- if .Config.WorkingDir }} -w {{.Config.WorkingDir}}{{end}} \
{{- if .HostConfig.Memory }} --memory={{.HostConfig.Memory}}b{{end}} \
{{- if .HostConfig.MemoryReservation }} --memory-reservation={{.HostConfig.MemoryReservation}}b{{end}} \
{{- if .HostConfig.CPUShares }} --cpu-shares={{.HostConfig.CPUShares}}{{end}} \
{{- if ne .Config.Hostname (slice .Id 0 12) }} -h {{.Config.Hostname}}{{end}} \
{{- range .HostConfig.ExtraHosts }} --add-host={{.}}{{end}} \
{{- if .Name }} --name={{slice .Name 1}}{{end}} \
{{- range .HostConfig.Devices }} --device={{.PathOnHost}}:{{.PathInContainer}}{{if .CgroupPermissions}}:{{.CgroupPermissions}}{{end}}{{end}} \
{{- if .HostConfig.LogConfig.Type }} --log-driver={{.HostConfig.LogConfig.Type}}{{end}} \
{{- range $key, $value := .HostConfig.LogConfig.Config }} --log-opt {{$key}}={{$value}}{{end}} \
{{- range $key, $value := .Config.Labels }} -l {{$key}}={{$value}}{{end}} \
{{.Config.Image}} \
{{- if .Config.Entrypoint }} \
{{- range .Config.Entrypoint }} {{.}}{{end}} \
{{- end}} \
{{- if .Config.Cmd }} \
{{- range .Config.Cmd }} {{.}}{{end}} \
{{- end}}'

exit 0