{{/*
Expand the name of the chart.
*/}}
{{- define "zen-watcher.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "zen-watcher.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "zen-watcher.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zen-watcher.labels" -}}
helm.sh/chart: {{ include "zen-watcher.chart" . }}
{{ include "zen-watcher.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zen-watcher.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zen-watcher.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "zen-watcher.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "zen-watcher.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the namespace
*/}}
{{- define "zen-watcher.namespace" -}}
{{- .Release.Namespace }}
{{- end }}

{{/*
Validate leader election configuration (H074.2 safety rules)
*/}}
{{- define "zen-watcher.validateLeaderElection" -}}
{{- if and (gt (int .Values.replicaCount) 1) (eq .Values.leaderElection.mode "disabled") }}
{{- fail "Unsafe HA configuration: replicaCount > 1 but leaderElection.mode is disabled. Either set replicaCount=1 or enable leader election (mode: builtin)" }}
{{- end }}
{{- if not (has .Values.leaderElection.mode (list "builtin" "disabled")) }}
{{- fail (printf "Invalid leaderElection.mode: %q (must be builtin or disabled)" .Values.leaderElection.mode) }}
{{- end }}
{{- end }}

