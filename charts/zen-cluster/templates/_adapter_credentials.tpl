{{/*
H603: Standardized adapter credential consumption
This template provides consistent credential environment variables for all adapters.
Secret format: zen-adapter-cred-<adapterID>
Secret keys: secret, key_id, key_version, server_salt
*/}}
{{- define "zen-cluster.adapterCredentials" -}}
{{- if .adapterID }}
- name: HMAC_KEY_ID
  valueFrom:
    secretKeyRef:
      name: zen-adapter-cred-{{ .adapterID }}
      key: key_id
- name: HMAC_KEY_VERSION
  valueFrom:
    secretKeyRef:
      name: zen-adapter-cred-{{ .adapterID }}
      key: key_version
- name: HMAC_SECRET
  valueFrom:
    secretKeyRef:
      name: zen-adapter-cred-{{ .adapterID }}
      key: secret
- name: HMAC_SERVER_SALT
  valueFrom:
    secretKeyRef:
      name: zen-adapter-cred-{{ .adapterID }}
      key: server_salt
{{- end }}
{{- end }}
