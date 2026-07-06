{{/*
Cross-chart-safe naming helpers. These deliberately use .Release.Name plus a
literal string instead of .Chart.Name, because Helm compiles all templates
(parent + every subchart) into one shared template namespace - a helper
based on .Chart.Name gives a different, wrong answer depending on which
chart's context it's called from (e.g. called from the frontend subchart,
.Chart.Name is "frontend", not "backend"). Referenced both by this parent
chart's own templates (ingress, migration-job) and directly from inside the
backend/frontend subcharts' templates, wherever they need to name or address
each other's resources.
*/}}
{{- define "calendar.fullname" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "calendar.backend.fullname" -}}
{{ .Release.Name }}-backend
{{- end -}}

{{- define "calendar.frontend.fullname" -}}
{{ .Release.Name }}-frontend
{{- end -}}
