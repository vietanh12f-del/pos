DO $$
BEGIN
  -- Relaxed INSERT policy: allow insert when editor_id matches auth.uid()
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'order_edits'
      AND policyname = 'Order edits insert by editor'
  ) THEN
    CREATE POLICY "Order edits insert by editor"
    ON order_edits FOR INSERT
    WITH CHECK (editor_id = auth.uid());
  END IF;
  
  -- Relaxed SELECT policy: allow read when editor_id matches auth.uid()
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'order_edits'
      AND policyname = 'Order edits select by editor'
  ) THEN
    CREATE POLICY "Order edits select by editor"
    ON order_edits FOR SELECT
    USING (editor_id = auth.uid());
  END IF;
END $$;
