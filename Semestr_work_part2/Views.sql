/* ============================================================
   MATERIALIZED VIEW: deals.mv_order_dto
   Назначение:
   Базовое DTO-представление ордера для API.
   Используется для отображения ордера пользователю:
   - валюты
   - ожидаемые суммы
   - основной кошелек
   - сетевые параметры
   ============================================================ */
CREATE MATERIALIZED VIEW deals.mv_order_dto AS
SELECT
    o.order_id,
    o.created_at,

    cs.currency_code               AS currency_give_code,
    cb.currency_code               AS currency_receive_code,

    o.expected_amount_sell         AS amount_give,
    o.expected_amount_buy          AS amount_receive,

    w.wallet_number,

    cs.network,
    cs.token_type,
    cs.contract_address
FROM deals.exchange_order o
JOIN currency.currency cs
    ON cs.currency_id = o.currency_sell_id
JOIN currency.currency cb
    ON cb.currency_id = o.currency_buy_id
LEFT JOIN wallets.deposit_address da
    ON da.order_id = o.order_id
LEFT JOIN wallets.wallet w
    ON w.user_id = o.user_id
   AND w.currency_id = o.currency_sell_id;



/* ============================================================
   MATERIALIZED VIEW: deals.mv_order_dto_full
   Назначение:
   Полное дерево ордера:
   ордер → депозиты → транзакции.
   Используется для:
   - детального просмотра ордера
   - админки
   - дебага платежей
   ============================================================ */
CREATE MATERIALIZED VIEW deals.mv_order_dto_full AS
WITH RECURSIVE order_chain AS (
    -- Базовый уровень: сам ордер и основной кошелек
    SELECT
        o.order_id,
        o.order_external_id,
        o.user_id,
        o.wallet_id,
        o.currency_sell_id,
        o.currency_buy_id,
        o.expected_amount_sell AS amount_give,
        o.expected_amount_buy  AS amount_receive,
        w.wallet_number AS main_wallet_number,
        cs.network,
        cs.token_type,
        cs.contract_address,
        o.status AS order_status,
        0 AS level,
        NULL::INT AS deposit_id,
        NULL::TEXT AS deposit_address,
        NULL::NUMERIC AS deposit_expected_amount,
        NULL::INT AS tx_id,
        NULL::NUMERIC AS tx_amount,
        NULL::TEXT AS tx_status
    FROM deals.exchange_order o
    JOIN wallets.wallet w
        ON w.wallet_id = o.wallet_id
    JOIN currency.currency cs
        ON cs.currency_id = o.currency_sell_id

    UNION ALL

    -- Рекурсивный уровень: депозиты и связанные транзакции
    SELECT
        oc.order_id,
        oc.order_external_id,
        oc.user_id,
        oc.wallet_id,
        oc.currency_sell_id,
        oc.currency_buy_id,
        oc.amount_give,
        oc.amount_receive,
        oc.main_wallet_number,
        oc.network,
        oc.token_type,
        oc.contract_address,
        oc.order_status,
        oc.level + 1 AS level,
        d.deposit_id,
        d.address AS deposit_address,
        d.expected_amount AS deposit_expected_amount,
        t.tx_id,
        t.amount AS tx_amount,
        t.status AS tx_status
    FROM order_chain oc
    LEFT JOIN wallets.deposit_address d
        ON d.order_id = oc.order_id
        AND d.deleted_at IS NULL
    LEFT JOIN deals.transaction t
        ON t.deposit_id = d.deposit_id
)
SELECT *
FROM order_chain
ORDER BY order_id, level, deposit_id, tx_id;



/* ============================================================
   VIEW: deals.v_order_summary
   Назначение:
   Краткая агрегированная информация по ордерам.
   Используется для:
   - списков ордеров
   - админки
   - аналитики
   ============================================================ */
CREATE VIEW deals.v_order_summary AS
SELECT
    o.order_id,
    o.user_id,
    o.created_at,
    o.status,
    cs.currency_code AS sell_currency,
    cb.currency_code AS buy_currency,
    o.expected_amount_sell,
    o.expected_amount_buy,
    COALESCE(SUM(t.amount), 0) AS total_received,
    COUNT(DISTINCT d.deposit_id) AS deposits_count,
    COUNT(DISTINCT t.tx_id) AS transactions_count
FROM deals.exchange_order o
JOIN currency.currency cs
    ON cs.currency_id = o.currency_sell_id
JOIN currency.currency cb
    ON cb.currency_id = o.currency_buy_id
LEFT JOIN wallets.deposit_address d
    ON d.order_id = o.order_id
    AND d.deleted_at IS NULL
LEFT JOIN deals.transaction t
    ON t.deposit_id = d.deposit_id
GROUP BY
    o.order_id,
    o.user_id,
    o.created_at,
    o.status,
    cs.currency_code,
    cb.currency_code,
    o.expected_amount_sell,
    o.expected_amount_buy;



/* ============================================================
   MATERIALIZED VIEW: deals.mv_order_financials
   Назначение:
   Финансовая сводка по ордерам:
   - сколько получено средств
   - полностью ли оплачен ордер
   Используется для отчетов и аналитики.
   ============================================================ */
CREATE MATERIALIZED VIEW deals.mv_order_financials AS
SELECT
    o.order_id,
    o.created_at,
    cs.currency_code AS sell_currency,
    cb.currency_code AS buy_currency,
    o.expected_amount_sell,
    o.expected_amount_buy,
    COALESCE(SUM(t.amount), 0) AS received_amount,
    (COALESCE(SUM(t.amount), 0) >= o.expected_amount_sell) AS fully_paid
FROM deals.exchange_order o
JOIN currency.currency cs
    ON cs.currency_id = o.currency_sell_id
JOIN currency.currency cb
    ON cb.currency_id = o.currency_buy_id
LEFT JOIN wallets.deposit_address d
    ON d.order_id = o.order_id
LEFT JOIN deals.transaction t
    ON t.deposit_id = d.deposit_id
GROUP BY
    o.order_id,
    o.created_at,
    cs.currency_code,
    cb.currency_code,
    o.expected_amount_sell,
    o.expected_amount_buy;



/* ============================================================
   MATERIALIZED VIEW: wallets.mv_user_currency_balance
   Назначение:
   Агрегированный баланс пользователя по валютам.
   Используется для:
   - профиля пользователя
   - админки
   ============================================================ */
CREATE MATERIALIZED VIEW wallets.mv_user_currency_balance AS
SELECT
    w.user_id,
    w.currency_id,
    c.currency_code,
    SUM(w.balance) AS total_balance
FROM wallets.wallet w
JOIN currency.currency c
    ON c.currency_id = w.currency_id
GROUP BY
    w.user_id,
    w.currency_id,
    c.currency_code;



/* ============================================================
   VIEW: wallets.v_active_deposits
   Назначение:
   Активные депозиты, ожидающие оплату.
   Используется для мониторинга платежей и воркеров.
   ============================================================ */
CREATE VIEW wallets.v_active_deposits AS
SELECT
    d.deposit_id,
    d.order_id,
    d.address,
    d.expected_amount,
    d.created_at,
    o.status AS order_status,
    cs.currency_code,
    cs.network
FROM wallets.deposit_address d
JOIN deals.exchange_order o
    ON o.order_id = d.order_id
JOIN currency.currency cs
    ON cs.currency_id = o.currency_sell_id
WHERE
    d.deleted_at IS NULL
    AND o.status IN ('created', 'waiting_payment');



/* ============================================================
   VIEW: deals.v_transaction_dto
   Назначение:
   DTO-представление транзакций с бизнес-контекстом.
   Используется сервисами и API.
   ============================================================ */
CREATE VIEW deals.v_transaction_dto AS
SELECT
    t.tx_id,
    t.amount,
    t.status,
    t.created_at,
    d.deposit_id,
    d.address,
    o.order_id, 
    o.user_id,
    cs.currency_code,
    cs.network
FROM deals.transaction t
JOIN wallets.deposit_address d
    ON d.deposit_id = t.deposit_id
JOIN deals.exchange_order o
    ON o.order_id = d.order_id
JOIN currency.currency cs
    ON cs.currency_id = o.currency_sell_id;



/* ============================================================
   VIEW: users.v_user_dto
   Назначение:
   DTO-представление пользователя.
   Используется для API и сервисов.
   ============================================================ */
CREATE VIEW users.v_user_dto AS
SELECT
    u.user_id,
    u.email,
    u.role
FROM users.user_account u;



/* ============================================================
   VIEW: users.v_user_session_dto
   Назначение:
   Пользователь + его роль на основе активных сессий.
   Используется для авторизации.
   ============================================================ */
CREATE VIEW users.v_user_session_dto AS
SELECT DISTINCT
    s.user_id,
    u.role AS user_role
FROM users.session s
JOIN users.user_account u
    ON u.user_id = s.user_id;



/* ============================================================
   VIEW: users.v_user_with_orders
   Назначение:
   Пользователь с количеством активных ордеров.
   Используется для админки.
   ============================================================ */
CREATE VIEW users.v_user_with_orders AS
SELECT
    u.user_id,
    u.email,
    u.role,
    COUNT(o.order_id) AS active_orders_count
FROM users.user_account u
LEFT JOIN deals.exchange_order o
    ON o.user_id = u.user_id
    AND o.status IN ('created', 'waiting_payment', 'processing')
GROUP BY
    u.user_id,
    u.email,
    u.role;



/* ============================================================
   VIEW: currency.v_currency_for_buy
   Назначение:
   Валюты, доступные для покупки.
   Используется при создании ордера.
   ============================================================ */
CREATE VIEW currency.v_currency_for_buy AS
SELECT
    c.currency_id,
    c.currency_code,
    c.currency_name,
    c.amount,
    c.token_type
FROM currency.currency c
WHERE
    c.is_active = true
    AND c.status IN ('for_buy', 'both');



/* ============================================================
   VIEW: currency.v_currency_for_sell
   Назначение:
   Валюты, доступные для продажи.
   Используется при создании ордера.
   ============================================================ */
CREATE VIEW currency.v_currency_for_sell AS
SELECT
    c.currency_id,
    c.currency_code,
    c.currency_name,
    c.token_type,
    b.bank_id,
    b.bank_name
FROM currency.currency c
JOIN currency.bank_fiat bf
    ON bf.currency_id = c.currency_id
JOIN currency.bank b
    ON b.bank_id = bf.bank_id
WHERE
    c.is_active = true
    AND c.status IN ('for_sale', 'both');

-- Обновляем материализованные представления (materialized views)
REFRESH MATERIALIZED VIEW deals.mv_order_dto;
REFRESH MATERIALIZED VIEW deals.mv_order_dto_full;