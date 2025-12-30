
-- =====================================
-- Schemas
-- =====================================
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS currency;
CREATE SCHEMA IF NOT EXISTS deals;
CREATE SCHEMA IF NOT EXISTS wallets;

-- =====================================
-- Пользователи
-- =====================================
CREATE TABLE users.user_account (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Уникальный идентификатор пользователя
    email VARCHAR(254) NOT NULL UNIQUE,                -- Email пользователя (для входа)
    password_hash TEXT NOT NULL,                       -- Хеш пароля
    role VARCHAR(50) NOT NULL DEFAULT 'user'           -- Роль пользователя: admin, user, moderator
        CHECK (role IN ('admin', 'user', 'moderator')),
    created_at TIMESTAMPTZ DEFAULT now(),              -- Дата создания аккаунта
    last_login TIMESTAMPTZ                             -- Дата последнего входа
);

COMMENT ON TABLE users.user_account IS 'Таблица пользователей';
COMMENT ON COLUMN users.user_account.email IS 'Email пользователя';
COMMENT ON COLUMN users.user_account.role IS 'Роль пользователя';

CREATE INDEX idx_user_account_last_login
ON users.user_account(last_login)
TABLESPACE fast_index;

-- =====================================
-- KYC
-- =====================================
CREATE TABLE users.kyc (
    user_id UUID PRIMARY KEY,                          -- FK на пользователя
    personal_data JSONB NOT NULL,                      -- Личные данные
    documents JSONB NOT NULL,                          -- Загруженные документы
    FOREIGN KEY (user_id)
        REFERENCES users.user_account(user_id)
        ON DELETE CASCADE
);

COMMENT ON TABLE users.kyc IS 'KYC данные пользователей';

-- =====================================
-- Сессии пользователей
-- =====================================
CREATE TABLE users.session (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Уникальный идентификатор сессии
    user_id UUID NOT NULL,                                 -- FK на пользователя
    created_at TIMESTAMPTZ DEFAULT now(),                  -- Дата создания сессии
    last_used TIMESTAMPTZ,                                 -- Дата последнего использования
    FOREIGN KEY (user_id)
        REFERENCES users.user_account(user_id)
        ON DELETE CASCADE
) TABLESPACE fast_ts;

COMMENT ON TABLE users.session IS 'Сессии пользователей';

CREATE INDEX idx_session_user_id
ON users.session(user_id)
TABLESPACE fast_index;

CREATE INDEX idx_session_last_used
ON users.session(last_used)
TABLESPACE fast_index;

-- =====================================
-- Валюты
-- =====================================
CREATE TABLE currency.currency (
    currency_id SERIAL PRIMARY KEY,                      -- PK
    currency_code VARCHAR(50) NOT NULL UNIQUE,           -- Код валюты (BTC, ETH, USDT)
    currency_name VARCHAR(50) NOT NULL,                  -- Название валюты
    network VARCHAR(20) NOT NULL,                        -- Сеть (Bitcoin, Ethereum, Tron)
    token_type VARCHAR(20) NOT NULL                      -- Тип токена: native, ERC20, TRC20, SPL, Jetton
        CHECK (token_type IN ('native','ERC20','TRC20','SPL','Jetton')),
    contract_address TEXT,                               -- Адрес контракта токена
    amount NUMERIC(32,8) NOT NULL DEFAULT 0,             -- Баланс платформы
    limit_min NUMERIC(20,8) DEFAULT 0,                   -- Минимальная сумма обмена
    limit_max NUMERIC(20,8),                             -- Максимальная сумма обмена
    status VARCHAR(50) NOT NULL DEFAULT 'for_sale'       -- Статус валюты: for_sale, for_buy, both, frozen
        CHECK (status IN ('for_sale', 'for_buy', 'both', 'frozen')),
    type VARCHAR(50) NOT NULL CHECK (type IN ('crypto', 'fiat')), -- Тип валюты
    is_active BOOLEAN NOT NULL DEFAULT TRUE              -- Активна ли валюта
);

COMMENT ON TABLE currency.currency IS 'Таблица поддерживаемых валют';

CREATE INDEX idx_currency_network
ON currency.currency(network)
TABLSPACE fast_index;

CREATE INDEX idx_currency_status
ON currency.currency(status)
TABLSPACE fast_index;

-- =====================================
-- Банки и фиат
-- =====================================
CREATE TABLE currency.bank (
    bank_id SERIAL PRIMARY KEY,
    bank_name VARCHAR(50) NOT NULL UNIQUE,
    card_format TEXT NOT NULL
);

COMMENT ON TABLE currency.bank IS 'Банки для фиатных платежей';

CREATE TABLE currency.bank_fiat (
    bank_id INT NOT NULL,
    currency_id INT NOT NULL,
    fee_percent NUMERIC(5,2) DEFAULT 0,
    PRIMARY KEY (bank_id, currency_id),
    FOREIGN KEY (bank_id)
        REFERENCES currency.bank(bank_id)
        ON DELETE CASCADE,
    FOREIGN KEY (currency_id)
        REFERENCES currency.currency(currency_id)
        ON DELETE CASCADE
);

COMMENT ON TABLE currency.bank_fiat IS 'Комиссии банков для каждой валюты';

-- =====================================
-- Курсы валют
-- =====================================
CREATE TABLE currency.rate (
    rate_id SERIAL PRIMARY KEY,
    currency_id INT NOT NULL,
    rate NUMERIC(32,8) NOT NULL,
    api_source TEXT,
    last_api_source TEXT,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_currencyrates_currency
        FOREIGN KEY (currency_id)
        REFERENCES currency.currency(currency_id)
        ON DELETE CASCADE
) TABLESPACE fast_ts;

COMMENT ON TABLE currency.rate IS 'Таблица текущих курсов валют';

CREATE INDEX idx_rate_currency_id
ON currency.rate(currency_id)
TABLESPACE fast_index;

CREATE INDEX idx_rate_last_updated
ON currency.rate(last_updated)
TABLESPACE fast_index;

-- =====================================
-- Ордеры обмена
-- =====================================
CREATE TABLE deals.exchange_order (
    order_id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users.user_account(user_id) ON DELETE CASCADE,
    currency_sell_id INT REFERENCES currency.currency(currency_id),
    currency_buy_id INT REFERENCES currency.currency(currency_id),
    expected_amount_sell NUMERIC(32,8) NOT NULL,
    expected_amount_buy  NUMERIC(32,8) NOT NULL,
    actual_amount_sell   NUMERIC(32,8),
    status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','waiting_payment','processing','completed','cancelled','failed')),
    created_at TIMESTAMPTZ DEFAULT now(),
    expire_at TIMESTAMPTZ
);

COMMENT ON TABLE deals.exchange_order IS 'Обменные ордера пользователей';

CREATE INDEX idx_exchange_order_user_id
ON deals.exchange_order(user_id)
TABLESPACE fast_index;

CREATE INDEX idx_exchange_order_actual_amount_sell
ON deals.exchange_order(actual_amount_sell)
TABLESPACE fast_index;

CREATE INDEX idx_exchange_order_status
ON deals.exchange_order(status)
TABLESPACE fast_index;

-- =====================================
-- Кошельки платформы
-- =====================================
CREATE TABLE wallets.owner_wallet (
    owner_wallet_id SERIAL PRIMARY KEY,
    currency_id INT NOT NULL
    network VARCHAR(20) NOT NULL,                        -- Сеть кошелька
    wallet_type VARCHAR(20) NOT NULL CHECK (
        wallet_type IN ('eoa','xpub','private_key','mnemonic')
    ),
    public_key TEXT,
    encrypted_private_key TEXT,
    xpub TEXT,
    address TEXT,                                        -- Адрес кошелька
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE wallets.owner_wallet IS 'Кошельки платформы (для депонирования средств)';

CREATE INDEX idx_owner_wallet_currency_id
ON wallets.owner_wallet(currency_id)
TABLESPACE fast_index;

CREATE INDEX idx_owner_wallet_network
ON wallets.owner_wallet(network)
TABLESPACE fast_index;

CREATE INDEX idx_owner_wallet_address
ON wallets.owner_wallet(address);
TABLESPACE fast_index;

-- =====================================
-- Кошельки пользователей
-- =====================================
CREATE TABLE wallets.wallet (
    wallet_id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    currency_id INT NOT NULL,
    label TEXT DEFAULT 'User wallet',                    -- Метка/описание кошелька
    wallet_number TEXT NOT NULL,                         -- Адрес кошелька
    balance NUMERIC(32,8) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    FOREIGN KEY (user_id)
        REFERENCES users.user_account(user_id)
        ON DELETE CASCADE,
    FOREIGN KEY (currency_id)
        REFERENCES currency.currency(currency_id)
        ON DELETE RESTRICT
);

COMMENT ON TABLE wallets.wallet IS 'Кошельки пользователей';
COMMENT ON COLUMN wallets.wallet.wallet_number IS 'Адрес кошелька (BTC, ETH, TRC20 и т.д.)';

CREATE INDEX idx_wallet_user_id
ON wallets.wallet(user_id)
TABLESPACE fast_index;

CREATE INDEX idx_wallet_currency_id
ON wallets.wallet(currency_id)
TABLESPACE fast_index;

CREATE INDEX idx_wallet_number
ON wallets.wallet(wallet_number)
TABLESPACE fast_index;

CREATE INDEX idx_wallet_creation_time
ON wallets.wallet(created_at)
TABLESPACE fast_index;

CREATE UNIQUE INDEX idx_wallet_user_currency_walletnumber
ON wallets.wallet(user_id, currency_id, wallet_number)
TABLESPACE fast_index;

-- =====================================
-- Депозитные адреса
-- =====================================
CREATE TABLE wallets.deposit_address (
    deposit_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES deals.exchange_order(order_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users.user_account(user_id) ON DELETE CASCADE,
    currency_id INT REFERENCES currency.currency(currency_id),
    owner_wallet_id INT REFERENCES wallets.owner_wallet(owner_wallet_id),
    address TEXT NOT NULL,                               -- Адрес для депозита
    derivation_index INT,                                -- Индекс для HD-кошельков
    expected_amount NUMERIC(32,8),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','paid','partial','expired')),
    created_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE wallets.deposit_address IS 'Адреса для депозита по ордерам';

CREATE INDEX idx_deposit_address_user_id
ON wallets.deposit_address(user_id)
TABLESPACE fast_index;

CREATE INDEX idx_deposit_address_order_id
ON wallets.deposit_address(order_id)
TABLESPACE fast_index;

CREATE INDEX idx_deposit_address_currency_id
ON wallets.deposit_address(currency_id)
TABLESPACE fast_index;

CREATE INDEX idx_deposit_address_expected_amount
ON wallets.deposit_address(expected_amount)
TABLESPACE fast_index;

CREATE UNIQUE INDEX idx_deposit_address_address_currency
ON wallets.deposit_address(address, currency_id)
TABLESPACE fast_index;

-- =====================================
-- Транзакции
-- =====================================
CREATE TABLE deals.transaction (
    tx_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES deals.exchange_order(order_id),
    deposit_id INT REFERENCES wallets.deposit_address(deposit_id),
    tx_hash TEXT NOT NULL,
    network VARCHAR(20) NOT NULL,
    token_type VARCHAR(20) NOT NULL,
    contract_address TEXT,
    from_address TEXT,
    to_address TEXT,
    amount NUMERIC(32,8) NOT NULL,
    block_number BIGINT,
    confirmations INT DEFAULT 0,
    tx_type VARCHAR(20) NOT NULL CHECK (
        tx_type IN ('deposit','withdraw','internal')
    ),
    status VARCHAR(20) NOT NULL DEFAULT 'detected'
        CHECK (status IN ('detected','pending','confirmed','failed')),
    detected_at TIMESTAMPTZ DEFAULT now(),
    confirmed_at TIMESTAMPTZ
) TABLESPACE fast_ts;

COMMENT ON TABLE deals.transaction IS 'Таблица транзакций (депозиты, выводы, внутренние переводы)';

CREATE INDEX idx_transaction_tx_hash
ON deals.transaction(tx_hash)
TABLESPACE fast_index;

CREATE INDEX idx_transaction_order_id
ON deals.transaction(order_id)
TABLESPACE fast_index;

CREATE INDEX idx_transaction_deposit_id
ON deals.transaction(deposit_id)
TABLESPACE fast_index;

CREATE INDEX idx_transaction_from_address
ON deals.transaction(from_address)
TABLESPACE fast_index;

CREATE INDEX idx_transaction_to_address
ON deals.transaction(to_address)
TABLESPACE fast_index;

CREATE INDEX idx_transaction_network
ON deals.transaction(network)
TABLESPACE fast_index;
