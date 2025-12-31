# Copyright 2025 Kube-ZEN Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

{{/*
Expand the name of the chart.
*/}}
{{- define "zen-lock.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "zen-lock.fullname" -}}
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
{{- define "zen-lock.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zen-lock.labels" -}}
helm.sh/chart: {{ include "zen-lock.chart" . }}
{{ include "zen-lock.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zen-lock.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zen-lock.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the controller service account to use
*/}}
{{- define "zen-lock.controllerServiceAccountName" -}}
{{- if and .Values.controller.serviceAccount .Values.controller.serviceAccount.name }}
{{- .Values.controller.serviceAccount.name }}
{{- else }}
{{- printf "%s-controller" (include "zen-lock.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the name of the webhook service account to use
*/}}
{{- define "zen-lock.webhookServiceAccountName" -}}
{{- if and .Values.webhook.serviceAccount .Values.webhook.serviceAccount.name }}
{{- .Values.webhook.serviceAccount.name }}
{{- else }}
{{- printf "%s-webhook" (include "zen-lock.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Namespace to use
*/}}
{{- define "zen-lock.namespace" -}}
{{- default .Values.namespace.name .Release.Namespace }}
{{- end }}

{{/*
Leader election namespace
*/}}
{{- define "zen-lock.leaderElectionNamespace" -}}
{{- if .Values.leaderElection.namespace }}
{{- .Values.leaderElection.namespace }}
{{- else }}
{{- include "zen-lock.namespace" . }}
{{- end }}
{{- end }}

{{/*
Validate controller leader election configuration (H074.2 safety rules)
*/}}
{{- define "zen-lock.validateControllerLeaderElection" -}}
{{- if and .Values.controller.enabled (gt (int (.Values.controller.replicaCount | default .Values.replicaCount)) 1) (eq .Values.controller.leaderElection.mode "disabled") }}
{{- fail "Unsafe HA configuration: controller.replicaCount > 1 but controller.leaderElection.mode is disabled. Either set controller.replicaCount=1 or enable leader election (mode: builtin or zenlead)" }}
{{- end }}
{{- if and .Values.controller.enabled (eq .Values.controller.leaderElection.mode "zenlead") }}
{{- if not .Values.controller.leaderElection.leaseName }}
{{- fail "controller.leaderElection.leaseName is required when controller.leaderElection.mode=zenlead" }}
{{- end }}
{{- end }}
{{- if and .Values.controller.enabled (not (has .Values.controller.leaderElection.mode (list "builtin" "zenlead" "disabled"))) }}
{{- fail (printf "Invalid controller.leaderElection.mode: %q (must be builtin, zenlead, or disabled)" .Values.controller.leaderElection.mode) }}
{{- end }}
{{- end }}

