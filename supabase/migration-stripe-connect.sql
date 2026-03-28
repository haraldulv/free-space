-- =============================================
-- SpotShare: Stripe Connect + Check-in/out times
-- Run manually in Supabase SQL Editor
-- =============================================

-- Stripe Connect fields on profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS stripe_account_id text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS stripe_onboarding_complete boolean DEFAULT false;

-- Check-in/out times on listings
ALTER TABLE listings ADD COLUMN IF NOT EXISTS check_in_time text DEFAULT '15:00';
ALTER TABLE listings ADD COLUMN IF NOT EXISTS check_out_time text DEFAULT '11:00';

-- Transfer tracking on bookings
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS transfer_status text DEFAULT 'pending';
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS stripe_transfer_id text;

-- Allow payout_sent notification type
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('booking_received', 'booking_confirmed', 'booking_cancelled', 'new_message', 'new_review', 'payout_sent'));
