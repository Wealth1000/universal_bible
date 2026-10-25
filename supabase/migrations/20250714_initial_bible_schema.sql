-- ============================================================
-- Bible Project – Initial Schema
-- ============================================================
-- This migration is safe to run on a shared Supabase instance.
-- It will not drop or rename any existing tables or columns.
-- ============================================================

-- Enable UUID extension if not already enabled.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------
-- 1. bible_translations – metadata for installed translations
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bible_translations (
    id TEXT PRIMARY KEY,                -- e.g. 'KJV', 'ESV'
    name TEXT NOT NULL,
    language_code TEXT NOT NULL,
    version INTEGER NOT NULL,
    description TEXT,
    file_path TEXT,                     -- optional: path in Storage bucket
    installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Index for user lookups.
CREATE INDEX IF NOT EXISTS idx_bible_translations_user_id ON bible_translations(user_id);

-- ------------------------------------------------------------
-- 2. bible_notes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bible_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    translation_id TEXT NOT NULL REFERENCES bible_translations(id) ON DELETE CASCADE,
    book_number INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bible_notes_user_translation ON bible_notes(user_id, translation_id);
CREATE INDEX IF NOT EXISTS idx_bible_notes_verse ON bible_notes(book_number, chapter, verse);

-- ------------------------------------------------------------
-- 3. bible_highlights
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bible_highlights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    translation_id TEXT NOT NULL REFERENCES bible_translations(id) ON DELETE CASCADE,
    book_number INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    color TEXT,                         -- e.g. 'yellow', 'green'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bible_highlights_user_translation ON bible_highlights(user_id, translation_id);

-- ------------------------------------------------------------
-- 4. bible_bookmarks
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bible_bookmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    translation_id TEXT NOT NULL REFERENCES bible_translations(id) ON DELETE CASCADE,
    book_number INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    label TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bible_bookmarks_user_translation ON bible_bookmarks(user_id, translation_id);

-- ------------------------------------------------------------
-- 5. bible_reading_positions
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bible_reading_positions (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    translation_id TEXT NOT NULL REFERENCES bible_translations(id) ON DELETE CASCADE,
    book_number INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    scroll_offset REAL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, translation_id)
);

-- ------------------------------------------------------------
-- Row Level Security (RLS)
-- ------------------------------------------------------------
-- Enable RLS on all tables.
ALTER TABLE bible_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE bible_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bible_highlights ENABLE ROW LEVEL SECURITY;
ALTER TABLE bible_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE bible_reading_positions ENABLE ROW LEVEL SECURITY;

-- Policy: users can only see their own data.
CREATE POLICY bible_translations_policy ON bible_translations
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY bible_notes_policy ON bible_notes
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY bible_highlights_policy ON bible_highlights
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY bible_bookmarks_policy ON bible_bookmarks
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY bible_reading_positions_policy ON bible_reading_positions
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------
-- Triggers for updated_at
-- ------------------------------------------------------------
-- Automatically update `updated_at` on row changes.
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_bible_notes_updated_at
    BEFORE UPDATE ON bible_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bible_reading_positions_updated_at
    BEFORE UPDATE ON bible_reading_positions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();