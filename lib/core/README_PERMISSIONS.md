# Permissions in the app (dynamic RBAC)

The app **enforces** access; it never edits it. Roles, permission matrices and per-user
extra permissions are managed by the clinic owner in the **web app**
(Admin → Roles & Permissions, Admin → Users).

## Where permissions come from

`GET /auth/me` returns `permissions: string[]` — the user's role permissions plus any
extra permissions granted to them. The clinic owner (`super_admin`) receives every
permission, so there is no client-side role bypass.

`AuthSession.hasPermission(p)` is a pure lookup in that list. Use it (or
`context.hasPermission(...)` / `PermissionGuard`) for every menu item, route and action.

Helpers on `AuthSession` for permissions that replaced old role checks:

| Getter                    | Permission                       | Used for                                   |
|---------------------------|----------------------------------|--------------------------------------------|
| `canViewAllBranches`      | `reports.all_branches`           | All-branch dashboard/reports/purchases     |
| `canSwitchBranch`         | `branches.switch`                | Branch switcher                            |
| `canViewAdvancedReports`  | `reports.advanced`               | GST, summary, shift, stock-transfer, visit |
| `canAssignAnyDoctor`      | `emr.visits.assign_any_doctor`   | Doctor picker (else locked to self)        |
| `isClinicalFocus`         | `emr.visits.view` w/o `reports.view` | Doctor-style dashboard & bottom nav    |

`isSuperAdmin` / `isShopOwner` remain only for owner-only areas (subscription & plans).

## Staying in sync

Every authenticated API response carries `X-Perm-Version`. When it changes (a role or a
user's access was edited in the web app), `ApiClient` calls `AuthSession.refreshMe()`;
`AuthSession` notifies listeners and go_router re-runs its redirects, so menus and routes
update without a re-login.

## Platform rules (not permissions)

These stay hard-coded because they are about the device, not access:

- Cashier accounts sign in only on the Windows/Linux desktop app.
- Cashier desktops land on POS and use the desktop notification flow.

## Adding a new permission

1. Add it to `backend/config/rbac.php` (it then appears in the web role editor).
2. Check it in the backend controller (`$this->authorize('x.y')`).
3. Add a constant to `AppPermissions` in `core/services/permission_service.dart` and gate the
   menu item / route / action with `hasPermission`.
