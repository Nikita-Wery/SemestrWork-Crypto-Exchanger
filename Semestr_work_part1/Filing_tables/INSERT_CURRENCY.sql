INSERT INTO currency.currency
(currency_code, currency_name, network, token_type, contract_address, amount, limit_min, limit_max, status, type, is_active)
VALUES
-- Bitcoin
('BTC', 'Bitcoin', 'Bitcoin', 'native', NULL, 100, 0.0001, 50, 'both', 'crypto', TRUE),

-- Ethereum
('ETH', 'Ethereum', 'Ethereum', 'native', NULL, 500, 0.001, 100, 'both', 'crypto', TRUE),

-- Solana
('SOL', 'Solana', 'Solana', 'native', NULL, 1000, 0.01, 500, 'both', 'crypto', TRUE),

-- TON
('TON', 'Toncoin', 'TON', 'native', NULL, 1000, 0.01, 500, 'both', 'crypto', TRUE),

-- USDT (ERC-20 на Ethereum)
('USDT', 'Tether', 'Ethereum', 'ERC20', '0xdAC17F958D2ee523a2206206994597C13D831ec7', 1000000, 1, 10000, 'both', 'crypto', TRUE),

('USD', 'US Dollar', 'Fiat', 'native', NULL, 1000000, 10, 100000, 'both', 'fiat', TRUE)
ON CONFLICT (currency_code) DO NOTHING;

-- RUB (фиатная валюта)
INSERT INTO currency.currency
(currency_code, currency_name, network, token_type, contract_address, amount, limit_min, limit_max, status, type, is_active)
VALUES
('RUB', 'Russian Ruble', 'Fiat', 'native', NULL, 1000000, 10, 100000, 'both', 'fiat', TRUE)
ON CONFLICT (currency_code) DO NOTHING;