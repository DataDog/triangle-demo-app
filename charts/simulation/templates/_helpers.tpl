{{- define "simulation.name" -}}
simulation
{{- end }}

{{- define "simulation.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{ .Values.fullnameOverride }}
{{- else -}}
{{ .Release.Name }}-{{ include "simulation.name" . }}
{{- end -}}
{{- end }}
