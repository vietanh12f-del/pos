DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'order_edits'
      AND column_name = 'note'
  ) THEN
    ALTER TABLE public.order_edits ADD COLUMN note TEXT;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'order_edits'
      AND column_name = 'details'
  ) THEN
    ALTER TABLE public.order_edits ADD COLUMN details JSONB;
  END IF;
END $$;
