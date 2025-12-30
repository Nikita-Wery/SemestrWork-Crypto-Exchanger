-- ============================================================
-- СОЗДАНИЕ РОЛЕЙ
-- ============================================================

-- Роль-владелец БД и схем (используется для миграций)
CREATE ROLE app_owner
LOGIN
PASSWORD 'strong_password';

-- Роль backend-приложения (API)
CREATE ROLE app_backend
LOGIN
PASSWORD 'backend_password';

-- Роль только для чтения (аналитика, отчёты)
CREATE ROLE app_readonly
LOGIN
PASSWORD 'readonly_password';

-- Разрешаем подключение к БД
GRANT CONNECT ON DATABASE crypto_exchange
TO app_owner, app_backend, app_readonly;


-- app_owner становится владельцем всех схем и может
-- выполнять CREATE / ALTER / DROP
ALTER SCHEMA users    OWNER TO app_owner;
ALTER SCHEMA deals    OWNER TO app_owner;
ALTER SCHEMA currency OWNER TO app_owner;
ALTER SCHEMA wallets  OWNER TO app_owner;


-- USAGE позволяет обращаться к объектам схем,
-- но не создавать новые
GRANT USAGE ON SCHEMA users, deals, currency, wallets
TO app_backend, app_readonly;


-- Явно запрещаем CREATE (защита от ошибок приложения) 
REVOKE CREATE ON SCHEMA users, deals, currency, wallets
FROM app_backend, app_readonly;


-- Backend имеет полный CRUD доступ
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA users, deals, currency, wallets
TO app_backend;

-- Readonly может только читать данные
GRANT SELECT
ON ALL TABLES IN SCHEMA users, deals, currency, wallets
TO app_readonly;

-- Backend может использовать sequence для INSERT
GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA users, deals, currency, wallets
TO app_backend;


-- Автоматически выдаёт права на новые таблицы,
-- созданные app_owner
-- Backend: полный CRUD
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
IN SCHEMA users, deals, currency, wallets
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_backend;

-- Readonly: только SELECT
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
IN SCHEMA users, deals, currency, wallets
GRANT SELECT ON TABLES TO app_readonly;

-- Backend сможет использовать новые sequence автоматически
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner
IN SCHEMA users, deals, currency, wallets
GRANT USAGE, SELECT ON SEQUENCES TO app_backend;
