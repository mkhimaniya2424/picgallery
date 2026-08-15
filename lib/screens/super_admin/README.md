# Super Admin panel — how this fits into your app

## What this is
A brand-new, separate screen set for a **platform-wide Super Admin**
(you, overseeing every studio and client) — not the existing
`screens/admin/*` folder, which is the **Studio Owner's own**
dashboard for managing their own clients. Nothing in that existing
folder was touched.

## Files (drop into `lib/screens/super_admin/`)
- `super_admin_models.dart` — data shapes + mock data (studios,
  clients, website leads). Includes a deliberate example of the
  same-email-two-roles case (`riya@lumenstudio.in` as both a Studio
  and a Client row) so you can see the linking in action.
- `super_admin_login_screen.dart` — separate login, not the
  Client/Studio email+password flow.
- `super_admin_dashboard_screen.dart` — platform KPIs + quick nav.
- `super_admin_users_screen.dart` — tabbed Studio / Client / Website
  lists with search.
- `super_admin_subscriptions_screen.dart` — studios filtered by
  subscription status.
- `super_admin_user_detail_screen.dart` — profile + the "linked
  account" card for dual-role emails.

## To wire it up for real
1. **Backend**: none of these endpoints exist yet. You'll need new
   platform-admin-only routes, e.g. `POST /admin/login`,
   `GET /admin/studios`, `GET /admin/clients`, `GET /admin/leads`,
   `GET /admin/subscriptions` — all requiring a Super Admin account,
   which is a new concept (not a `role` on the existing `users`
   table).
2. **Entry point**: add a route (e.g. `/super-admin`) that only you
   would navigate to — don't add a button for it in the regular
   Client/Studio app UI.
3. **"Website user"**: I assumed this means a public-site visitor/
   lead who hasn't signed up. If you actually meant something else,
   tell me and I'll adjust `WebsiteLead` and the tab accordingly.
4. Replace `SuperAdminMockData` calls with real API/provider calls
   once the backend routes exist — the widgets are already built
   around simple lists, so the swap is mechanical.
