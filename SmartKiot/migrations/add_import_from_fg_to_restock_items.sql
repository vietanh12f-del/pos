-- Add columns to restock_items to support importing from finished goods
ALTER TABLE restock_items ADD COLUMN IF NOT EXISTS import_from_finished_good BOOLEAN DEFAULT false;
ALTER TABLE restock_items ADD COLUMN IF NOT EXISTS source_finished_good_id UUID REFERENCES products(id);

COMMENT ON COLUMN restock_items.import_from_finished_good IS 'Flag to indicate if this item was restocked by deducting from a finished good';
COMMENT ON COLUMN restock_items.source_finished_good_id IS 'Reference to the source finished good product';
