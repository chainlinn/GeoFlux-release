#!/usr/bin/env bash
# Cloudflare Tunnel route management (source-able library)
# Reads: CF_API_TOKEN CF_ACCOUNT_ID CF_TUNNEL_ID CF_ZONE_ID (via FORGE_ENV)

_cf_check() {
    for v in CF_API_TOKEN CF_ACCOUNT_ID CF_TUNNEL_ID CF_ZONE_ID; do
        if [[ -z "${!v:-}" ]]; then
            echo "Cloudflare: $v not set — add to ~/.forge/config/.forge" >&2
            return 1
        fi
    done
}

cf_route_add() {
    _cf_check || return 1
    local hostname="${1:?usage: cf_route_add <hostname> <service>}"
    local service="${2:?usage: cf_route_add <hostname> <service>}"

    echo "Cloudflare: $hostname → $service"

    local updated
    updated=$(curl -s \
        "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations" \
        -H "Authorization: Bearer $CF_API_TOKEN" | \
        jq --arg h "$hostname" --arg s "$service" '
            .result.config.ingress
            | map(select(.hostname))
            + [{"hostname": $h, "service": $s}]
            + [{"service": "http_status:404"}]
            | {"config": {"ingress": .}}
        ')

    curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$updated" | jq -r 'if .success then "  Tunnel route: OK" else "  Tunnel route: FAILED" end'

    curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"CNAME\",\"name\":\"$hostname\",\"content\":\"$CF_TUNNEL_ID.cfargotunnel.com\",\"proxied\":true,\"ttl\":1}" | \
        jq -r 'if .success then "  DNS record: OK" else "  DNS: FAILED" end'
}

cf_route_del() {
    _cf_check || return 1
    local hostname="${1:?usage: cf_route_del <hostname>}"

    echo "Cloudflare: removing $hostname"

    local updated
    updated=$(curl -s \
        "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations" \
        -H "Authorization: Bearer $CF_API_TOKEN" | \
        jq --arg h "$hostname" '.result.config.ingress | map(select(.hostname != $h)) | {"config": {"ingress": .}}')

    curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$updated" | jq -r 'if .success then "  Tunnel route: removed" else "  Tunnel: FAILED" end'

    local rec_id
    rec_id=$(curl -s \
        "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$hostname" \
        -H "Authorization: Bearer $CF_API_TOKEN" | jq -r '.result[0].id // empty')

    if [ -n "$rec_id" ]; then
        curl -s -X DELETE \
            "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$rec_id" \
            -H "Authorization: Bearer $CF_API_TOKEN" | \
            jq -r 'if .success then "  DNS record: removed" else "  DNS: FAILED" end'
    fi
}
