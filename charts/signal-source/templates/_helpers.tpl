{{- define "signal-source.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end }}

{{- define "signal-source.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride -}}
{{- end }}
