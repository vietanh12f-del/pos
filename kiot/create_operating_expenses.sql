-- Operating Expenses Table
CREATE TABLE operating_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for sorting by date
CREATE INDEX idx_operating_expenses_created_at ON operating_expenses(created_at);
