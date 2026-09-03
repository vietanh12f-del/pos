-- Create daily_bill_usage table for tracking bill numbers per day per store
-- This table ensures bill numbers are unique per day and can be reset daily

CREATE TABLE IF NOT EXISTS daily_bill_usage (
    id SERIAL PRIMARY KEY,
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    bill_number INTEGER NOT NULL CHECK (bill_number > 0 AND bill_number <= 999),
    usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Ensure unique bill number per store per day
    UNIQUE(store_id, bill_number, usage_date)
);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_daily_bill_usage_store_date ON daily_bill_usage(store_id, usage_date);
CREATE INDEX IF NOT EXISTS idx_daily_bill_usage_order ON daily_bill_usage(order_id);

-- Enable RLS for multi-tenant security
ALTER TABLE daily_bill_usage ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view daily_bill_usage for their stores" ON daily_bill_usage
    FOR SELECT USING (
        store_id IN (
            SELECT id FROM stores 
            WHERE owner_id = auth.uid() 
            OR id IN (
                SELECT store_id FROM store_members 
                WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can insert daily_bill_usage for their stores" ON daily_bill_usage
    FOR INSERT WITH CHECK (
        store_id IN (
            SELECT id FROM stores 
            WHERE owner_id = auth.uid() 
            OR id IN (
                SELECT store_id FROM store_members 
                WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Users can update daily_bill_usage for their stores" ON daily_bill_usage
    FOR UPDATE USING (
        store_id IN (
            SELECT id FROM stores 
            WHERE owner_id = auth.uid() 
            OR id IN (
                SELECT store_id FROM store_members 
                WHERE user_id = auth.uid()
            )
        )
    );

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_daily_bill_usage_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE TRIGGER daily_bill_usage_updated_at_trigger
    BEFORE UPDATE ON daily_bill_usage
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_bill_usage_updated_at();

-- Function to get next available bill number for a store on a specific date
CREATE OR REPLACE FUNCTION get_next_bill_number(store_uuid UUID, target_date DATE DEFAULT CURRENT_DATE)
RETURNS INTEGER AS $$
DECLARE
    next_bill INTEGER;
BEGIN
    -- Find the smallest available bill number starting from 1
    SELECT COALESCE(MIN(t1.bill_number + 1), 1) INTO next_bill
    FROM daily_bill_usage t1
    LEFT JOIN daily_bill_usage t2 ON t1.store_id = t2.store_id 
        AND t1.usage_date = t2.usage_date 
        AND t1.bill_number + 1 = t2.bill_number
    WHERE t1.store_id = store_uuid 
        AND t1.usage_date = target_date 
        AND t1.is_used = true
        AND t2.bill_number IS NULL;
    
    -- If no gaps found, get max + 1
    IF next_bill IS NULL THEN
        SELECT COALESCE(MAX(bill_number), 0) + 1 INTO next_bill
        FROM daily_bill_usage
        WHERE store_id = store_uuid 
            AND usage_date = target_date 
            AND is_used = true;
    END IF;
    
    -- Ensure we don't exceed 999
    IF next_bill > 999 THEN
        RETURN NULL; -- No available bill numbers
    END IF;
    
    RETURN next_bill;
END;
$$ LANGUAGE plpgsql;

-- Function to reserve a bill number
CREATE OR REPLACE FUNCTION reserve_bill_number(
    store_uuid UUID, 
    bill_num INTEGER, 
    target_date DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if bill number is already used
    IF EXISTS (
        SELECT 1 FROM daily_bill_usage 
        WHERE store_id = store_uuid 
            AND bill_number = bill_num 
            AND usage_date = target_date 
            AND is_used = true
    ) THEN
        RETURN FALSE; -- Bill number already used
    END IF;
    
    -- Insert or update the record
    INSERT INTO daily_bill_usage (store_id, bill_number, usage_date, is_used, used_at)
    VALUES (store_uuid, bill_num, target_date, true, NOW())
    ON CONFLICT (store_id, bill_number, usage_date)
    DO UPDATE SET 
        is_used = true,
        used_at = NOW(),
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to get used bill numbers for a store on a specific date
CREATE OR REPLACE FUNCTION get_used_bill_numbers(store_uuid UUID, target_date DATE DEFAULT CURRENT_DATE)
RETURNS INTEGER[] AS $$
BEGIN
    RETURN ARRAY(
        SELECT bill_number 
        FROM daily_bill_usage 
        WHERE store_id = store_uuid 
            AND usage_date = target_date 
            AND is_used = true
        ORDER BY bill_number
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE daily_bill_usage IS 'Tracks daily bill number usage per store to prevent duplicates and enable daily reset';
COMMENT ON FUNCTION get_next_bill_number IS 'Returns the next available bill number for a store on a given date';
COMMENT ON FUNCTION reserve_bill_number IS 'Reserves a specific bill number for a store on a given date';
COMMENT ON FUNCTION get_used_bill_numbers IS 'Returns array of used bill numbers for a store on a given date';