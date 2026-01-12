-- Add city and country columns to reports table
ALTER TABLE reports
ADD COLUMN IF NOT EXISTS city text,
ADD COLUMN IF NOT EXISTS country text;
