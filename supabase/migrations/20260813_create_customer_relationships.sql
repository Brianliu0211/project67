-- 1. 建立客戶社交角色關係表 (customer_relationships)
CREATE TABLE IF NOT EXISTS public.customer_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    source_customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    target_customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    relationship_type VARCHAR(50) NOT NULL, -- 'family' 親眷, 'workplace' 職場/同事, 'social' 社團/朋友, 'other' 其他
    relationship_detail VARCHAR(100),       -- '夫妻', '父子', '獅子會社友', '公司合夥人' 等
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT chk_no_self_relationship CHECK (source_customer_id <> target_customer_id)
);

-- 2. 設定 Row Level Security (RLS) 權限
ALTER TABLE public.customer_relationships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own customer relationships"
ON public.customer_relationships FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);
