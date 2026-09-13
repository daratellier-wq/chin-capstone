# VMC Scheduler — Advanced Additions

- Preserved the existing interface and visual design.
- Added a visible Available Rooms section with schedule/capacity checking.
- Prevented exact duplicate requests, user schedule overlaps, and room schedule conflicts.
- Added Booking Conflicts notification category for both users and admins.
- Added structured notifications that render in English or Filipino based on the current language.
- Completed English/Filipino localization for the main workflow.
- Added booking search/status filters, details, cancellation, and admin decisions.
- Added upcoming bookings to Dashboard.
- Kept editable profiles, calendar publishing, facility management, school hours, and theme settings.

## Role permissions update
- Facility add/edit/delete is administrator-only, with UI restrictions and handler-level permission guards.
- Students and teachers can view facilities and book them, but cannot create, edit, or delete facility records.
- Administrator Settings now includes configurable Profile Edit Permissions for Student and Teacher roles.
- Admin can independently allow/lock Full Name, Email, ID Number, Phone, Department/Section, and Password editing.
- Locked fields are disabled in the user profile and the save handler preserves the administrator-controlled value.
- English and Filipino labels/messages were added for the new permissions workflow.

## Supabase / Cloudflare upgrade (2026-09)
- Replaced local-only data flow with Supabase Auth + database integration.
- Added customizable room code, location, description, amenities, active state, and photo attachment.
- Added Supabase Storage bucket/policies for room photos.
- Added database-side booking conflict validation and secure availability RPC.
- Added RLS policies and protected administrator-only room/status actions.
- Removed self-service admin signup; admins are promoted from the database.
- Added automatic booking/event notifications at the database layer.
- Added Cloudflare Pages build-time Supabase configuration.

## Production polish pass
- Fixed logout flow to use a local Supabase session sign-out and safe button state.
- Added working Light / Dark / Follow device theme modes.
- Added personal interface customization: font size, density, and design style.
- Added shared Admin-controlled branding, room, school-hour, role, permission, and notification synchronization.
- Added database-triggered notifications for shared settings, role, and room changes.
- Added stronger profile-update policy to avoid recursive permission evaluation.
- Improved responsive styling, dark-mode contrast, controls, disabled states, tables, cards, and forms.
