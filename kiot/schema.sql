-- Supabase (PostgreSQL) Schema for Kiot App

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Products Table
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    category TEXT NOT NULL,
    image_name TEXT,
    color TEXT,
    stock_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Orders Table
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    total_amount NUMERIC NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Order Items Table
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    price NUMERIC NOT NULL
);

-- 4. Restock Bills Table
CREATE TABLE restock_bills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    total_cost NUMERIC NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Restock Items Table
CREATE TABLE restock_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bill_id UUID REFERENCES restock_bills(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC NOT NULL
);

-- 6. Price History Table (for ad-hoc items auto-complete)
CREATE TABLE price_history (
    product_name TEXT PRIMARY KEY,
    price NUMERIC NOT NULL
);
