{{/*
Expand the name of the chart.
*/}}
{{- define "zen-gc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "zen-gc.fullname" -}}
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
{{- define "zen-gc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zen-gc.labels" -}}
helm.sh/chart: {{ include "zen-gc.chart" . }}
{{ include "zen-gc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zen-gc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zen-gc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "zen-gc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "zen-gc.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validate leader election configuration (H074.2 safety rules)
*/}}
{{- define "zen-gc.validateLeaderElection" -}}
{{- if and (gt .Values.replicaCount 1) (eq .Values.leaderElection.mode "disabled") }}
{{- fail "Unsafe HA configuration: replicaCount > 1 but leaderElection.mode is disabled. Either set replicaCount=1 or enable leader election (mode: builtin or zenlead)" }}
{{- end }}
{{- if eq .Values.leaderElection.mode "zenlead" }}
{{- if not .Values.leaderElection.leaseName }}
{{- fail "leaderElection.leaseName is required when leaderElection.mode=zenlead" }}
{{- end }}
{{- end }}
{{- if not (has .Values.leaderElection.mode (list "builtin" "zenlead" "disabled")) }}
{{- fail (printf "Invalid leaderElection.mode: %q (must be builtin, zenlead, or disabled)" .Values.leaderElection.mode) }}
{{- end }}
{{- end }}

{{/*
Legacy template aliases for backward compatibility (gc-controller.*)
*/}}
{{- define "gc-controller.name" -}}
{{- include "zen-gc.name" . }}
{{- end }}

{{- define "gc-controller.fullname" -}}
{{- include "zen-gc.fullname" . }}
{{- end }}

{{- define "gc-controller.chart" -}}
{{- include "zen-gc.chart" . }}
{{- end }}

{{- define "gc-controller.labels" -}}
{{- include "zen-gc.labels" . }}
{{- end }}

{{- define "gc-controller.selectorLabels" -}}
{{- include "zen-gc.selectorLabels" . }}
{{- end }}

{{- define "gc-controller.serviceAccountName" -}}
{{- include "zen-gc.serviceAccountName" . }}
{{- end }}
