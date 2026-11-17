BEGIN;

CREATE OR REPLACE FUNCTION public.set_skillsbridge_account_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  account_role text;
BEGIN
  account_role := CASE
    WHEN NEW.raw_app_meta_data ->> 'role' IN ('student', 'guardian')
      THEN NEW.raw_app_meta_data ->> 'role'
    WHEN NEW.raw_user_meta_data ->> 'role' = 'guardian'
      THEN 'guardian'
    ELSE 'student'
  END;

  NEW.raw_app_meta_data := jsonb_set(
    COALESCE(NEW.raw_app_meta_data, '{}'::jsonb),
    '{role}',
    to_jsonb(account_role),
    true
  );
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.set_skillsbridge_account_role() FROM PUBLIC;

DROP TRIGGER IF EXISTS set_skillsbridge_account_role ON auth.users;
CREATE TRIGGER set_skillsbridge_account_role
BEFORE INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.set_skillsbridge_account_role();

UPDATE auth.users
SET raw_app_meta_data = jsonb_set(
  COALESCE(raw_app_meta_data, '{}'::jsonb),
  '{role}',
  to_jsonb(
    CASE
      WHEN raw_app_meta_data ->> 'role' IN ('student', 'guardian')
        THEN raw_app_meta_data ->> 'role'
      WHEN raw_user_meta_data ->> 'role' = 'guardian'
        THEN 'guardian'
      ELSE 'student'
    END
  ),
  true
)
WHERE raw_app_meta_data ->> 'role' NOT IN ('student', 'guardian')
   OR raw_app_meta_data ->> 'role' IS NULL;

COMMIT;
