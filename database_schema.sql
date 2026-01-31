-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Products Table (combines Product catalog and Inventory)
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    price DOUBLE PRECISION NOT NULL DEFAULT 0,
    category TEXT NOT NULL DEFAULT 'Khác',
    image_name TEXT,
    color TEXT,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Orders (Bills) Table
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Items Table
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL, -- Link to product if it exists
    product_name TEXT NOT NULL, -- Snapshot of name
    quantity INTEGER NOT NULL,
    price DOUBLE PRECISION NOT NULL, -- Snapshot of price at sale
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Restock History Table
CREATE TABLE restock_bills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    total_cost DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Restock Items Table
CREATE TABLE restock_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bill_id UUID REFERENCES restock_bills(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_restock_items_bill_id ON restock_items(bill_id);
