{{/*
Labels used only within this subchart's own templates (pod labels/selectors).
Deliberately hardcodes "frontend" rather than using .Chart.Name - see
backend/templates/_helpers.tpl for why.
*/}}
{{- define "frontend.labels" -}}
app.kubernetes.io/name: frontend
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end -}}
