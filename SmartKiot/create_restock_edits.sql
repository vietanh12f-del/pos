CREATE TABLE IF NOT EXISTS restock_edits (
  id UUID PRIMARY KEY,
  restock_bill_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  old_total DOUBLE PRECISION NOT NULL,
  new_total DOUBLE PRECISION NOT NULL,
  editor_id UUID REFERENCES profiles(id),
  editor_name TEXT,
  note TEXT,
  details JSONB,
  store_id UUID REFERENCES stores(id)
);

CREATE INDEX IF NOT EXISTS idx_restock_edits_bill_id ON restock_edits(restock_bill_id);
CREATE INDEX IF NOT EXISTS idx_restock_edits_created_at ON restock_edits(created_at DESC);

ALTER TABLE restock_edits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can read restock edits" ON restock_edits;
CREATE POLICY "Store members can read restock edits"
ON restock_edits FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = restock_edits.store_id
      AND m.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Store members can insert restock edits" ON restock_edits;
CREATE POLICY "Store members can insert restock edits"
ON restock_edits FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = restock_edits.store_id
      AND m.user_id = auth.uid()
  )
);
