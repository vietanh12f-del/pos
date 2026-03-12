CREATE TABLE IF NOT EXISTS order_edits (
  id UUID PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  old_total DOUBLE PRECISION NOT NULL,
  new_total DOUBLE PRECISION NOT NULL,
  editor_id UUID REFERENCES profiles(id),
  editor_name TEXT,
  store_id UUID REFERENCES stores(id)
);

CREATE INDEX IF NOT EXISTS idx_order_edits_order_id ON order_edits(order_id);
CREATE INDEX IF NOT EXISTS idx_order_edits_created_at ON order_edits(created_at DESC);

ALTER TABLE order_edits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Store members can read order edits"
ON order_edits FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = order_edits.store_id
      AND m.user_id = auth.uid()
  )
);

CREATE POLICY "Store members can insert order edits"
ON order_edits FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = order_edits.store_id
      AND m.user_id = auth.uid()
  )
);
