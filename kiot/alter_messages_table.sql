-- Migration to add support for Order Messages
-- Run this in Supabase SQL Editor

ALTER TABLE messages 
ADD COLUMN message_type TEXT DEFAULT 'text',
ADD COLUMN order_id UUID REFERENCES orders(id);

-- Optional: Index for performance
CREATE INDEX idx_messages_order_id ON messages(order_id);
