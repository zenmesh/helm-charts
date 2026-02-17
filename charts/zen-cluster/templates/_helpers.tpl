{{/*
Expand the name of the chart.
*/}}
{{- define "zen-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "zen-cluster.fullname" -}}
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
{{- define "zen-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zen-cluster.labels" -}}
helm.sh/chart: {{ include "zen-cluster.chart" . }}
{{ include "zen-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zen-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zen-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "zen-cluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "zen-cluster.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
P134: Plane placement enforcement - Data or Edge Plane only
P132: Component-specific placement validation
*/}}
{{- define "zen-cluster.validatePlane" -}}
{{- $plane := .Values.global.plane | default "edge" }}
{{- $allowedPlanes := list "data" "edge" }}
{{- if not (has $plane $allowedPlanes) }}
{{- fail (printf "P134: zen-cluster chart MUST be deployed in data or edge plane only. Got plane=%s (allowed: data, edge)" $plane) }}
{{- end }}
{{- end }}

{{/*
P132: Validate component placement - zen-ingester and zen-egress can be in edge or data plane
zen-bridge can only be in data plane
*/}}
{{- define "zen-cluster.validateComponentPlacement" -}}
{{- $plane := .Values.global.plane | default "edge" }}
{{- $component := .componentName }}
{{- if eq $component "zen-bridge" }}
  {{- if eq $plane "edge" }}
{{- fail "P132: zen-bridge cannot be deployed in edge plane context. zen-bridge is data-plane only. Set global.plane=data" }}
  {{- end }}
{{- end }}
{{- if or (eq $component "zen-ingester") (eq $component "zen-egress") }}
  {{- if not (has $plane (list "data" "edge")) }}
{{- fail (printf "P132: %s can only be deployed in data or edge plane context. Got plane=%s" $component $plane) }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
P227: Image reference - prefer digest when set for immutable pinning
Usage: include "zen-cluster.image" (dict "registry" .Values.global.registry "repo" .Values.ingester.image.repository "tag" .Values.ingester.image.tag "digest" .Values.ingester.image.digest)
*/}}
{{- define "zen-cluster.image" -}}
{{- $reg := .registry | trimSuffix "/" -}}
{{- $base := printf "%s/%s" $reg .repo -}}
{{- if and .digest (ne (toString .digest) "") -}}
{{- printf "%s@%s" $base .digest -}}
{{- else -}}
{{- printf "%s:%s" $base .tag -}}
{{- end -}}
{{- end -}}

{{/*
Validate ingester leader election configuration (H074.2 safety rules)
*/}}
{{- define "zen-cluster.validateIngesterLeaderElection" -}}
{{- if and (gt (int .Values.ingester.replicaCount) 1) (eq .Values.ingester.leaderElection.mode "disabled") }}
{{- fail "Unsafe HA configuration: ingester.replicaCount > 1 but ingester.leaderElection.mode is disabled. Either set ingester.replicaCount=1 or enable leader election (mode: builtin or zenlead)" }}
{{- end }}
{{- if eq .Values.ingester.leaderElection.mode "zenlead" }}
{{- if not .Values.ingester.leaderElection.leaseName }}
{{- fail "ingester.leaderElection.leaseName is required when ingester.leaderElection.mode=zenlead" }}
{{- end }}
{{- end }}
{{- if not (has .Values.ingester.leaderElection.mode (list "builtin" "zenlead" "disabled")) }}
{{- fail (printf "Invalid ingester.leaderElection.mode: %q (must be builtin, zenlead, or disabled)" .Values.ingester.leaderElection.mode) }}
{{- end }}
{{- end }}

