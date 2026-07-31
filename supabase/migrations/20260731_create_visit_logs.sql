-- ============================================================
-- Phase 3 Migration: visit_logs 拜訪歷史日誌表
-- 建立日期: 2026-07-31
-- 說明: 記錄每次客戶拜訪的類型、結果與備註，
--       並設定 Trigger 當行程完成時自動寫入日誌
-- ============================================================

-- 1. 建立 visit_logs 資料表
CREATE TABLE IF NOT EXISTS public.visit_logs (
  id           UUID         DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_id  UUID         REFERENCES public.customers(id) ON DELETE SET NULL,
  reminder_id  UUID         REFERENCES public.reminders(id) ON DELETE SET NULL,
  visit_type   TEXT         CHECK (visit_type IN ('首談', '跟進', '送件', '售後服務', '其他'))
                            DEFAULT '跟進',
  outcome      TEXT         CHECK (outcome IN ('成功', '拒絕', '待跟進', '未接觸', '其他'))
                            DEFAULT '成功',
  notes        TEXT,
  created_at   TIMESTAMPTZ  DEFAULT NOW() NOT NULL
);

-- 2. 建立索引加速查詢
CREATE INDEX IF NOT EXISTS idx_visit_logs_user_id
  ON public.visit_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_visit_logs_customer_id
  ON public.visit_logs(customer_id);

CREATE INDEX IF NOT EXISTS idx_visit_logs_created_at
  ON public.visit_logs(created_at DESC);

-- 3. 啟用 Row Level Security
ALTER TABLE public.visit_logs ENABLE ROW LEVEL SECURITY;

-- 4. RLS 政策：每個使用者只能存取自己的日誌
CREATE POLICY "Users can manage their own visit logs"
  ON public.visit_logs
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- Auto-log Trigger
-- 當 reminders.is_completed 被設為 true 時，
-- 自動在 visit_logs 建立一筆拜訪歷史紀錄
-- ============================================================

-- 5. 建立 Trigger 函數
CREATE OR REPLACE FUNCTION public.fn_auto_create_visit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 只有當 is_completed 從 false/null 切換為 true 時才觸發
  IF NEW.is_completed = TRUE AND (OLD.is_completed IS DISTINCT FROM TRUE) THEN
    INSERT INTO public.visit_logs (
      user_id,
      customer_id,
      reminder_id,
      visit_type,
      outcome,
      notes
    )
    VALUES (
      NEW.user_id,
      NEW.customer_id,
      NEW.id,
      '跟進',
      '成功',
      NEW.notes
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 6. 將 Trigger 綁定到 reminders 資料表
DROP TRIGGER IF EXISTS trg_auto_visit_log ON public.reminders;

CREATE TRIGGER trg_auto_visit_log
  AFTER UPDATE ON public.reminders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_auto_create_visit_log();

-- ============================================================
-- 完成提示
-- ============================================================
-- 執行完畢後，可用以下語句驗證資料表是否建立成功：
-- SELECT table_name FROM information_schema.tables
--   WHERE table_schema = 'public' AND table_name = 'visit_logs';
