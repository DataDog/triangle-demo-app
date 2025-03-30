{{- define "locator.name" -}}
locator
{{- end }}

{{- define "locator.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{ .Values.fullnameOverride }}
{{- else -}}
{{ .Release.Name }}-{{ include "locator.name" . }}
{{- end -}}
{{- end }}
