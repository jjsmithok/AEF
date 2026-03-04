# Member Agent Layer

> **Week 6** | **Purpose:** Autonomous identity and self-service for developers and end users

---

## Overview

The Member Agent handles identity management through Keycloak and provides self-service capabilities via Backstage. Users can request access, namespaces, and resources without human intervention.

## Key Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| **IAM** | Keycloak 25+ | Identity provider |
| **Developer Portal** | Backstage 1.3 | Self-service UI |
| **Ticketing** | Jira integration | Request workflow |

## Data Flow

```
User Request → Backstage UI → Member Agent → 
Jira Ticket (optional) → Change Board Approval → 
Provision → Keycloak Group + Namespace + RBAC
```

## Keycloak Configuration

### Realm Setup
```yaml
apiVersion: keycloak.org/v1alpha1
kind: KeycloakRealm
metadata:
  name: control-tower
spec:
  realm:
    id: control-tower
    realm: control-tower
    enabled: true
    displayName: Control Tower
    accessTokenLifespan: 300
```

### Group Mapping
```yaml
apiVersion: keycloak.org/v1alpha1
kind: KeycloakGroup
metadata:
  name: team-alpha
realm: control-tower
```

## Backstage Integration

### Catalog Entity
```yaml
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: john.doe
spec:
  memberOf:
    - team-alpha
```

### Component Registration
```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  annotations:
    kubernetes.io/cluster: sandbox
    kubernetes.io/namespace: team-alpha
spec:
  type: service
  lifecycle: production
  owner: team-alpha
```

## Next Steps

- [Environments](/environments) — Create isolated accounts
- [Governance](/governance) — Configure HITL
