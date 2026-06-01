# Account Avatar Permissions Design

## Goal

Extend the account avatar feature so avatar updates are controlled by the existing role permission system.

## Permission Model

Add two button permissions:

1. `account:set-avatar`
   - Controls whether a user can modify avatars for their own mailbox addresses.
   - Belongs under the existing `邮箱侧栏` permission group.
   - Users without this permission can still view avatars but cannot open the avatar settings action.

2. `user:set-account-avatar`
   - Controls whether an administrator or privileged user can modify avatars for another user's mailbox addresses from the user management screen.
   - Belongs under the existing `用户信息` permission group.
   - The configured `env.admin` account continues to bypass permission checks, matching the current security middleware behavior.

## Backend Changes

The existing `PUT /account/setAvatar` endpoint becomes a self-service endpoint and requires `account:set-avatar`.

Add a management endpoint:

```http
PUT /user/setAccountAvatar
```

Request body:

```json
{
  "accountId": 1,
  "avatarType": "custom",
  "avatar": "https://example.com/avatar.png"
}
```

The management endpoint requires `user:set-account-avatar` and can update any normal account row. It reuses the same avatar normalization/upload helper used by the self-service endpoint.

`accountService.setAvatar` remains owner-scoped. A new service method handles admin-scoped updates so the ownership rules are explicit and testable.

## Database Migration

Add both permission rows during the next DB init migration:

- `account:set-avatar` under `邮箱侧栏`
- `user:set-account-avatar` under `用户信息`

Existing roles do not automatically receive these permissions. Admin keeps access through the existing admin bypass. Site owners can explicitly grant either permission to roles from the role editor.

## Frontend Changes

Mailbox sidebar:

- Show the avatar settings menu item only when `hasPerm('account:set-avatar')` is true.
- Continue showing avatars for everyone.

User management account dialog:

- Reuse the account avatar resolver for account rows.
- Add a `设置头像` action for each address when `hasPerm('user:set-account-avatar')` is true.
- Reuse the same avatar dialog behavior as the mailbox sidebar where practical.
- Call `PUT /user/setAccountAvatar` for admin-managed updates.

Role editor:

- The role permission tree will show the two new permissions after DB init runs.
- Add i18n labels for the new permission names.

## Error Handling

Backend permission middleware rejects missing permissions with the existing `unauthorized` response. The management service rejects missing account rows with `noUserAccount`. Avatar validation errors continue to use the existing avatar messages.

## Testing

Backend tests cover:

- Self-service avatar update requires account ownership.
- Management avatar update can modify another user's account.
- Management avatar update rejects missing accounts.
- Permission mapping includes `/account/setAvatar` under `account:set-avatar`.
- Permission mapping includes `/user/setAccountAvatar` under `user:set-account-avatar`.

Frontend verification covers:

- `pnpm --prefix mail-vue run build` or direct local Vite build.
- The role tree and account/user management components compile with the new permission keys.

