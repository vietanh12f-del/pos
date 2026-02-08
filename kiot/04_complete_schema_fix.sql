-- Complete Schema Fix for Missing Columns
-- Run this in Supabase SQL Editor to fix "Cost Price" 0 issue and enable other features.

-- 1. Fix Products Table (Cost Price & Barcode)
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS cost_price DOUBLE PRECISION DEFAULT 0;

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS barcode TEXT;

-- 2. Fix Order Items Table (Cost Price & Discount)
ALTER TABLE public.order_items 
ADD COLUMN IF NOT EXISTS cost_price DOUBLE PRECISION DEFAULT 0;

ALTER TABLE public.order_items 
ADD COLUMN IF NOT EXISTS discount DOUBLE PRECISION DEFAULT 0;

-- 3. Fix Orders Table (Payment Status)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT TRUE;

-- 4. Fix Messages Table (Chat Orders)
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';

ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS order_id UUID;

-- 5. Fix Stores Table (Bank Info)
ALTER TABLE public.stores 
ADD COLUMN IF NOT EXISTS bank_name TEXT;

ALTER TABLE public.stores 
ADD COLUMN IF NOT EXISTS bank_account_number TEXT;

ALTER TABLE public.stores 
ADD COLUMN IF NOT EXISTS bank_account_holder TEXT;

ALTER TABLE public.stores 
ADD COLUMN IF NOT EXISTS qr_template TEXT DEFAULT 'compact';
