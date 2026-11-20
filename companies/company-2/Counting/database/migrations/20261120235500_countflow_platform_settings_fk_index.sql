-- CountFlow: cover the settings.updated_by foreign key.
CREATE INDEX IF NOT EXISTS count_platform_settings_updated_by_idx
  ON public.count_platform_settings(updated_by)
  WHERE updated_by IS NOT NULL;