{{- define "calendar.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "calendar.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end -}}

{{- define "calendar.labels" -}}
app.kubernetes.io/name: {{ include "calendar.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "calendar.backend.fullname" -}}
{{ include "calendar.fullname" . }}-backend
{{- end -}}

{{- define "calendar.frontend.fullname" -}}
{{ include "calendar.fullname" . }}-frontend
{{- end -}}
