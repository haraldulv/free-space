-- Add vehicle_type column to listings
ALTER TABLE listings ADD COLUMN IF NOT EXISTS vehicle_type text DEFAULT 'motorhome';

-- Set all existing listings to 'motorhome' (Bobil)
UPDATE listings SET vehicle_type = 'motorhome' WHERE vehicle_type IS NULL;
