{{/*
Labels used only within this subchart's own templates (pod labels/selectors).
Deliberately hardcodes "backend" rather than using .Chart.Name - this file is
never called cross-chart, but staying consistent with the parent's
cross-chart-safe helpers avoids having two different naming conventions.
*/}}
{{- define "backend.labels" -}}
app.kubernetes.io/name: backend
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end -}}
