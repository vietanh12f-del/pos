-- Update unique constraint for products to allow same name for different types (Good vs Finished Good)
-- First, drop the old constraint if it exists. 
-- Note: The constraint name might vary, but 'products_name_key' is the standard PostgreSQL name for UNIQUE(name)

DO $$ 
BEGIN
    -- Try to find and drop any unique constraint on (name) or (store_id, name)
    -- and replace it with (store_id, name, is_finished_good)
    
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'products_name_key') THEN
        ALTER TABLE products DROP CONSTRAINT products_name_key;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'products_store_id_name_key') THEN
        ALTER TABLE products DROP CONSTRAINT products_store_id_name_key;
    END IF;

    -- Add the new multi-column unique constraint
    -- This allows "Product A" to exist once as a Normal Good (is_finished_good=false)
    -- and once as a Finished Good (is_finished_good=true) for each store.
    ALTER TABLE products ADD CONSTRAINT products_store_id_name_type_unique UNIQUE (store_id, name, is_finished_good);

END $$;

NOTIFY pgrst, 'reload schema';
