CREATE TABLE IF NOT EXISTS device_tokens (
  token TEXT PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  platform TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'device_tokens'
      AND policyname = 'Users manage own device tokens'
  ) THEN
    CREATE POLICY "Users manage own device tokens"
    ON device_tokens
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
