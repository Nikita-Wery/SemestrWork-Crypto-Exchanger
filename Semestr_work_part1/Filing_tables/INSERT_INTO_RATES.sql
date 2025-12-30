INSERT INTO currency.rate (currency_id, rate, api_source, last_api_source)
VALUES
    ((SELECT currency_id FROM currency.currency WHERE currency_code = 'BTC'), 88000, 'static', 'manual_update'),
    ((SELECT currency_id FROM currency.currency WHERE currency_code = 'ETH'), 2970, 'static', 'manual_update'),
    ((SELECT currency_id FROM currency.currency WHERE currency_code = 'SOL'), 125, 'static', 'manual_update'),
    ((SELECT currency_id FROM currency.currency WHERE currency_code = 'TON'), 1.48, 'static', 'manual_update'),
    ((SELECT currency_id FROM currency.currency WHERE currency_code = 'USDT'), 1.00, 'static', 'manual_update');
