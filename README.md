# VMC Scheduler — Supabase + Cloudflare Ready

This build keeps the original VMC Scheduler visual system and adds a real cloud backend.

## What changed
- Supabase Auth replaces browser-stored plaintext passwords.
- Rooms, bookings, profiles, events, notifications, and settings are stored in Supabase.
- Room records are customizable: name, code, capacity, location, description, amenities, active/bookable state, and image attachment.
- Room images upload to Supabase Storage (`room-images`, max 5 MB, JPG/PNG/WebP).
- Booking cards/modal now show room information and photos.
- Row Level Security limits room management and approval/rejection to admins.
- Users cannot self-register as admin. Admin role is promoted from Supabase after account creation.
- Build script supports Cloudflare Pages environment variables.

## 1. Create Supabase backend
1. Create a Supabase project.
2. Open **SQL Editor** and run the entire `supabase.sql` file once.
3. In **Project Settings > API**, copy the Project URL and public/anon key.
4. For local testing, edit `supabase-config.js` and replace the two placeholders.
5. Start locally with `npm run dev`, then open `http://localhost:5173`.

## 2. Create the first admin
1. Register normally using the app.
2. In Supabase **Table Editor > profiles**, change that user's `role` from `student`/`teacher` to `admin`.
3. Log out and log back in. The account will now have room CRUD and approval controls.

Do not put the Supabase service-role key in this frontend. Only use the public anon/publishable key.

## 3. Deploy to Cloudflare Pages
Recommended settings:
- Framework preset: **None**
- Build command: `npm run build`
- Build output directory: `dist`
- Root directory: `/` (or the project folder if uploading through Git)

In Cloudflare Pages > Settings > Environment variables, add:
- `SUPABASE_URL` = your Supabase Project URL
- `SUPABASE_ANON_KEY` = your Supabase public anon/publishable key

Redeploy after adding the variables.

## 4. Supabase URL configuration
In Supabase > Authentication > URL Configuration:
- Set **Site URL** to your final Cloudflare Pages URL/custom domain.
- Add your local URL `http://localhost:5173` and Cloudflare preview/production URLs to Redirect URLs if email confirmation is enabled.

## Cloudflare note
This project is a static SPA, so Cloudflare Pages is the appropriate product. `server.js` is only for local development and is not needed in production.

## Cloudflare Workers deployment

This project includes `wrangler.jsonc` for Cloudflare Workers Static Assets. Set the Cloudflare build command to `npm run build`, keep the root directory as `/`, and use `npx wrangler deploy` as the deploy command. The build creates `dist/`, which Wrangler serves as the site's static assets. SPA navigation falls back to `index.html`.

## Admin controls and production polish
The Admin account is intentionally not available in public signup. Create the Admin in Supabase Authentication, then promote its `profiles.role` to `admin` using the protected database workflow described in `supabase.sql`.

Admins can manage shared branding, rooms, maintenance status, school hours, users/roles, and Teacher/Student permissions. Shared changes are synchronized through Supabase Realtime and database notifications. Individual users can customize their own theme, font size, density, and design style from Settings without changing other users' personal preferences.

Before production, verify the Supabase email confirmation redirect URL is `https://chin-capstone.rilakk.workers.dev` and test Student, Teacher, and Admin accounts separately.
