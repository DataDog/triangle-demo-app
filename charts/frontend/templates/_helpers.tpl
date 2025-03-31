{{- define "frontend.name" -}}
frontend
{{- end }}

{{- define "frontend.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{ .Values.fullnameOverride }}
{{- else -}}
{{ .Release.Name }}-{{ include "frontend.name" . }}
{{- end -}}
{{- end }}
