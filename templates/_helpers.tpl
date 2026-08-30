{{- define "nalej-fixture.entryName" -}}
{{- $releaseName := .Release.Name -}}
{{- if not (hasPrefix "service-registry-" $releaseName) -}}
{{- fail "the Helm release name must start with service-registry-" -}}
{{- end -}}
{{- $entryName := trimPrefix "service-registry-" $releaseName -}}
{{- if not $entryName -}}
{{- fail "the Helm release name must include the Service Registry entry name" -}}
{{- end -}}
{{- $releaseName -}}
{{- end -}}
