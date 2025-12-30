-- =====================================================
--                  ЗАПРОСЫ К users.user_account
-- =====================================================

-- Посчитать количество пользователей
SELECT COUNT(*) AS user_count
FROM users.user_account;

-- Вставка нового пользователя
INSERT INTO users.user_account (
    user_id,
    email,
    password_hash,
    role,
) VALUES (
    gen_random_uuid(),
    :email,
    :password_hash,
    :role,
)
RETURNING user_id;

-- Получить пользователя по email
SELECT user_id, email, password_hash, role
FROM users.user_account
WHERE email = :email;

-- Получить пользователя по user_id
SELECT user_id, email, password_hash, role
FROM users.user_account
WHERE user_id = :user_id;

-- Получить последние 50 сделок (для admin)
SELECT
    o.order_id,
    u.email,
    o.status,
    o.created_at,
    o.expected_amount_sell,
    o.expected_amount_buy
FROM deals.exchange_order o
JOIN users.user_account u
    ON u.user_id = o.user_id
ORDER BY o.created_at DESC
LIMIT 50;

-- =====================================================
--                  ЗАПРОСЫ К users.kyc
-- =====================================================

-- Вставка KYC данных
INSERT INTO users.kyc (
    user_id,
    personal_data,
    documents
)
VALUES (
    :user_id,
    :personal_data::jsonb,
    :documents::jsonb
);

-- Получить KYC данные пользователя
SELECT *
FROM users.kyc
WHERE user_id = :user_id;

-- =====================================================
--                  ЗАПРОСЫ К users.session
-- =====================================================

-- Вставка новой сессии
INSERT INTO users.session (user_id)
VALUES (:user_id)
RETURNING session_id;

-- Получить роль пользователя по session_id
SELECT s.user_id, u.role
FROM users.session s
JOIN users.user_account u ON s.user_id = u.user_id
WHERE s.session_id = :session_id;

-- =====================================================
--                  ЗАПРОСЫ К currency.currency
-- =====================================================

-- Вставка валюты
INSERT INTO currency.currency (
    currency_code,
    currency_name,
    network,
    token_type,
    contract_address,
    amount,
    limit_min,
    limit_max,
    status,
    type,
    is_active
) VALUES (
    :currency_code,
    :currency_name,
    :network,
    :token_type,
    :contract_address,
    :amount,
    :limit_min,
    :limit_max,
    :status,
    :type,
    :is_active
)
RETURNING currency_id;

-- Получить все валюты
SELECT *
FROM currency.currency;

-- Получить все валюты на покупку (crypto)
SELECT
    currency_id,
    currency_code,
    currency_name,
    amount
FROM currency.currency
WHERE status IN ('for_buy', 'both')
  AND is_active = true
  AND type = 'crypto'
ORDER BY currency_code;

-- Получить все валюты на продажу с банками
SELECT
    c.currency_id,
    c.currency_code,
    c.currency_name,
    b.bank_id,
    b.bank_name
FROM currency.currency c
LEFT JOIN currency.bank_fiat bf
    ON bf.currency_id = c.currency_id
LEFT JOIN currency.bank b
    ON b.bank_id = bf.bank_id
WHERE c.status IN ('for_sale', 'both')
  AND c.is_active = true
ORDER BY c.currency_code, b.bank_name;

-- Получить имя валюты по коду
SELECT currency_name
FROM currency.currency
WHERE currency_code = :currency_code;

-- Получить currency_id по коду
SELECT currency_id
FROM currency.currency
WHERE currency_code = :currency_code;

-- =====================================================
--                  ЗАПРОСЫ К currency.bank
-- =====================================================

-- Вставка банка
INSERT INTO currency.bank (
    bank_name,
    card_format
) VALUES (
    :bank_name,
    :card_format
)
RETURNING bank_id;

-- Получить все банки
SELECT *
FROM currency.bank;

-- Получить конкретный банк
SELECT bank_id, bank_name, card_format
FROM currency.bank
WHERE bank_id = :bank_id;

-- =====================================================
--                  ЗАПРОСЫ К currency.bank_fiat
-- =====================================================

-- Вставка комиссии банка для валюты
INSERT INTO currency.bank_fiat (
    bank_id,
    currency_id,
    fee_percent
) VALUES (
    :bank_id,
    :currency_id,
    :fee_percent
);

-- Получить все комиссии банков
SELECT *
FROM currency.bank_fiat;

-- =====================================================
--                  ЗАПРОСЫ К currency.rate
-- =====================================================

-- Вставка/обновление курса валюты
INSERT INTO currency.rate (
    currency_id,
    rate,
    api_source,
    last_api_source,
    last_updated
)
VALUES (
    :currency_id,
    :rate,
    :api_source,
    :last_api_source,
    :last_updated
)
RETURNING rate_id;

-- Получить текущий курс валюты
SELECT *
FROM currency.rate
WHERE currency_id = :currency_id
ORDER BY last_updated DESC
LIMIT 1;

-- =====================================================
--                  ЗАПРОСЫ К deals.exchange_order
-- =====================================================

-- Вставка нового ордера
INSERT INTO deals.exchange_order (
    user_id,
    currency_sell_id,
    currency_buy_id,
    expected_amount_sell,
    expected_amount_buy,
    status,
    created_at,
    expire_at
) VALUES (
    :user_id,
    :currency_sell_id,
    :currency_buy_id,
    :expected_amount_sell,
    :expected_amount_buy,
    :status,
    :created_at,
    :expire_at
)
RETURNING order_id;

-- Получить все сделки клиента
SELECT
    o.order_id,
    o.order_external_id,
    o.created_at,
    cs.currency_code AS currency_give_code,
    cb.currency_code AS currency_receive_code,
    o.expected_amount_sell AS amount_give,
    o.expected_amount_buy  AS amount_receive,
    w.wallet_number,
    cs.network,
    cs.token_type,
    cs.contract_address,
    o.status
FROM deals.exchange_order o
JOIN wallets.wallet w
    ON w.wallet_id = o.wallet_id
JOIN currency.currency cs
    ON cs.currency_id = o.currency_sell_id
JOIN currency.currency cb
    ON cb.currency_id = o.currency_buy_id
WHERE o.user_id = :user_id
ORDER BY o.created_at DESC;

-- Получить конкретный order по внешнему id
SELECT *
FROM deals.mv_order_dto
WHERE order_external_id = :order_external_id;

-- =====================================================
--                  ЗАПРОСЫ К wallets.wallet
-- =====================================================

-- Вставка/обновление кошелька пользователя
INSERT INTO wallets.wallet (
    user_id,
    currency_id,
    label,
    wallet_number,
    balance
)
VALUES (
    :user_id,
    :currency_id,
    :label,
    :wallet_number,
    :balance
)
ON CONFLICT (user_id, currency_id, wallet_number)
DO UPDATE SET
    balance = wallets.wallet.balance + EXCLUDED.balance
RETURNING wallet_id, created_at;

-- Получить DTO's wallet по user_id и currency_id
SELECT
    w.wallet_id,
    c.currency_code,
    w.balance,
    w.wallet_number,
    w.created_at
FROM wallets.wallet w
JOIN currency.currency c
    ON c.currency_id = w.currency_id
WHERE w.user_id = :user_id
ORDER BY w.created_at;

-- =====================================================
--                  ЗАПРОСЫ К wallets.owner_wallet
-- =====================================================

-- Вставка кошелька платформы
INSERT INTO wallets.owner_wallet (
    currency_id,
    network,
    wallet_type,
    public_key,
    encrypted_private_key,
    xpub,
    address,
    created_at
)
VALUES (
    :currency_id,
    :network,
    :wallet_type,
    :public_key,
    :encrypted_private_key,
    :xpub,
    :address,
    :created_at
)
RETURNING owner_wallet_id;

-- Получить все кошельки платформы
SELECT *
FROM wallets.owner_wallet;

-- Получить кошелек по адресу
SELECT *
FROM wallets.owner_wallet
WHERE address = :address;

-- =====================================================
--                  ЗАПРОСЫ К wallets.deposit_address
-- =====================================================

-- Вставка адреса для депозита
INSERT INTO wallets.deposit_address (
    order_id,
    user_id,
    currency_id,
    owner_wallet_id,
    address,
    derivation_index,
    expected_amount,
    status,
    created_at,
    deleted_at
)
VALUES (
    :order_id,
    :user_id,
    :currency_id,
    :owner_wallet_id,
    :address,
    :derivation_index,
    :expected_amount,
    :status,
    :created_at,
    :deleted_at
)
RETURNING deposit_id;

-- Получить все адреса для одного ордера
SELECT
    d.address,
    d.expected_amount,
    d.status,
    d.created_at
FROM wallets.deposit_address d
WHERE d.order_id = :order_id
  AND d.deleted_at IS NULL;

-- Объединить адреса по ордерам
SELECT
    order_id,
    COUNT(*) AS deposits_count,
    SUM(expected_amount) AS total_expected,
    SUM(CASE WHEN status = 'paid' THEN expected_amount ELSE 0 END) AS total_paid
FROM wallets.deposit_address
GROUP BY order_id
ORDER BY order_id;

-- =====================================================
--                  ЗАПРОСЫ К deals.transaction
-- =====================================================

-- Вставка транзакции
INSERT INTO deals.transaction (
    order_id,
    deposit_id,
    tx_hash,
    network,
    token_type,
    contract_address,
    from_address,
    to_address,
    amount,
    block_number,
    confirmations,
    tx_type,
    status,
    detected_at,
    confirmed_at
)
VALUES (
    :order_id,
    :deposit_id,
    :tx_hash,
    :network,
    :token_type,
    :contract_address,
    :from_address,
    :to_address,
    :amount,
    :block_number,
    :confirmations,
    :tx_type,
    :status,
    :detected_at,
    :confirmed_at
)
RETURNING tx_id;

-- Получить транзакции по order_id
SELECT *
FROM deals.transaction
WHERE order_id = :order_id
ORDER BY detected_at DESC;

-- Получить транзакции по депозиту
SELECT *
FROM deals.transaction
WHERE deposit_id = :deposit_id;

-- Получить транзакции по кошельку (from_address/to_address)
SELECT *
FROM deals.transaction
WHERE from_address = :wallet_address
   OR to_address = :wallet_address
ORDER BY detected_at DESC;