CREATE TABLE IF NOT EXISTS auto_material_export_templates (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  store_id UUID REFERENCES stores(id)
);

CREATE INDEX IF NOT EXISTS idx_auto_material_export_templates_store_id ON auto_material_export_templates(store_id);
CREATE INDEX IF NOT EXISTS idx_auto_material_export_templates_updated_at ON auto_material_export_templates(updated_at DESC);

ALTER TABLE auto_material_export_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can read auto material export templates" ON auto_material_export_templates;
CREATE POLICY "Store members can read auto material export templates"
ON auto_material_export_templates FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = auto_material_export_templates.store_id
      AND m.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Store members can insert auto material export templates" ON auto_material_export_templates;
CREATE POLICY "Store members can insert auto material export templates"
ON auto_material_export_templates FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = auto_material_export_templates.store_id
      AND m.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Store members can update auto material export templates" ON auto_material_export_templates;
CREATE POLICY "Store members can update auto material export templates"
ON auto_material_export_templates FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = auto_material_export_templates.store_id
      AND m.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = auto_material_export_templates.store_id
      AND m.user_id = auth.uid()
  )
);

CREATE TABLE IF NOT EXISTS auto_material_export_logs (
  id UUID PRIMARY KEY,
  template_id UUID,
  template_name TEXT NOT NULL,
  production_transaction_id UUID NOT NULL REFERENCES production_transactions(id) ON DELETE CASCADE,
  data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  creator_id UUID,
  creator_name TEXT,
  store_id UUID REFERENCES stores(id)
);

ALTER TABLE auto_material_export_logs ADD COLUMN IF NOT EXISTS creator_id UUID;
ALTER TABLE auto_material_export_logs ADD COLUMN IF NOT EXISTS creator_name TEXT;

CREATE INDEX IF NOT EXISTS idx_auto_material_export_logs_store_id ON auto_material_export_logs(store_id);
CREATE INDEX IF NOT EXISTS idx_auto_material_export_logs_tx_id ON auto_material_export_logs(production_transaction_id);
CREATE INDEX IF NOT EXISTS idx_auto_material_export_logs_created_at ON auto_material_export_logs(created_at DESC);

ALTER TABLE auto_material_export_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can read auto material export logs" ON auto_material_export_logs;
CREATE POLICY "Store members can read auto material export logs"
ON auto_material_export_logs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = auto_material_export_logs.store_id
      AND m.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Store members can insert auto material export logs" ON auto_material_export_logs;
CREATE POLICY "Store members can insert auto material export logs"
ON auto_material_export_logs FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = auto_material_export_logs.store_id
      AND m.user_id = auth.uid()
  )
);
