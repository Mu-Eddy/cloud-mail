# Account Avatar Design

## Goal

Allow each mailbox address to choose an avatar. The avatar is shown in the account sidebar and can be configured from the existing account settings menu.

## User Options

Each address supports one of three avatar modes:

1. `initial`: show the first letter of the address display name, falling back to the email prefix.
2. `logo`: show the site logo from `/mail.png` or `/mail-pwa.png`.
3. `custom`: show a user-provided image.

Custom images support both local upload and image URL. Local uploads are stored in R2. URLs are saved directly after validation.

## Data Model

The `account` table gains two fields:

- `avatar_type TEXT NOT NULL DEFAULT 'initial'`
- `avatar TEXT NOT NULL DEFAULT ''`

`avatar_type` stores the selected mode. `avatar` stores either an R2 object key or an external image URL, and is only used when `avatar_type` is `custom`.

Existing accounts default to `initial`, so the migration is backward compatible.

## Backend API

Add `PUT /account/setAvatar`.

Request body:

```json
{
  "accountId": 1,
  "avatarType": "custom",
  "avatar": "data:image/png;base64,..."
}
```

Rules:

- Only the owner of the account can update the avatar.
- `avatarType` must be `initial`, `logo`, or `custom`.
- `initial` and `logo` clear the stored `avatar` field.
- `custom` requires `avatar`.
- External custom avatars must start with `http://` or `https://`.
- Base64 custom avatars must be valid image data and are stored under `static/avatar/`.

The endpoint returns the updated avatar fields so the frontend can update the account list immediately.

## Frontend

In `mail-vue/src/layout/account/index.vue`:

- Add an avatar preview to each account card.
- Add a settings dropdown item for avatar configuration.
- Add a dialog with radio-style mode selection for the three avatar modes.
- For custom mode, provide tabs or segmented controls for local upload and image link.
- Reuse existing `fileToBase64` and `cvtR2Url` helpers where practical.

Add a small shared helper module for resolving account avatar display state so the sidebar and future email UI can use the same logic.

## Error Handling

The frontend blocks empty custom avatars and invalid image URLs before submitting. The backend validates again and returns existing `BizError` responses for invalid input or unauthorized account access.

Uploaded images are not deleted when switching away from custom mode in this iteration. This avoids accidental removal if the same object is cached or reused, and matches a conservative first implementation.

## Testing

Backend unit tests cover:

- Saving `initial` clears custom avatar data.
- Saving `logo` clears custom avatar data.
- Saving custom URL persists the URL.
- Saving custom base64 image stores an R2 key.
- Invalid avatar type is rejected.
- A user cannot update another user's account.

Frontend verification covers:

- `pnpm --prefix mail-vue run build`
- The account sidebar renders avatar previews and the avatar dialog compiles.

