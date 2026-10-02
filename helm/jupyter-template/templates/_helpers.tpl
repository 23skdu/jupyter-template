{{/*
Expand the name of the chart.
*/}}
{{- define "jupyter-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jupyter-template.fullname" -}}
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
{{- define "jupyter-template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "jupyter-template.labels" -}}
helm.sh/chart: {{ include "jupyter-template.chart" . }}
{{ include "jupyter-template.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Chart.Name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "jupyter-template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jupyter-template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "jupyter-template.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "jupyter-template.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The container image reference, resolved from image.repository and either
image.tag or .Chart.AppVersion.
*/}}
{{- define "jupyter-template.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Fully qualified name of the PVC backing the working directory. Empty when
persistence is disabled, so callers can guard with `if`.
*/}}
{{- define "jupyter-template.pvcName" -}}
{{- if .Values.persistence.enabled }}
{{- default (include "jupyter-template.fullname" .) .Values.persistence.existingClaim }}
{{- end }}
{{- end }}

{{/*
Stable digest input for the pod's checksum/token-secret annotation. The token is
injected via secretKeyRef, so the pod has to be restarted for a changed token to
take effect. When no token exists yet (first install, auto-generated) this
returns a constant, otherwise an upgrade would look like a change every time.
*/}}
{{- define "jupyter-template.tokenChecksum" -}}
{{- if .Values.token.value -}}
{{- .Values.token.value -}}
{{- else if .Values.token.existingSecret -}}
{{- printf "existingSecret/%s/%s" .Values.token.existingSecret .Values.token.existingSecretKey -}}
{{- else if lookup "v1" "Secret" .Release.Namespace (include "jupyter-template.fullname" .) -}}
{{- (index (lookup "v1" "Secret" .Release.Namespace (include "jupyter-template.fullname" .)).data "token") | toString -}}
{{- else -}}
{{- "generated-on-first-install" -}}
{{- end -}}
{{- end }}