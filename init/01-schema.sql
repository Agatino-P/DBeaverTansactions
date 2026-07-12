CREATE SCHEMA bank;

CREATE TABLE bank.accounts (
    id      integer PRIMARY KEY,
    owner   text NOT NULL,
    balance numeric(12,2) NOT NULL CHECK (balance >= 0)
);

CREATE TABLE bank.transfers (
    id             bigserial PRIMARY KEY,
    from_account   integer NOT NULL REFERENCES bank.accounts (id),
    to_account     integer NOT NULL REFERENCES bank.accounts (id),
    amount         numeric(12,2) NOT NULL CHECK (amount > 0),
    transferred_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO bank.accounts (id, owner, balance) VALUES
    (1, 'Alice', 1000.00),
    (2, 'Bob',   1000.00),
    (3, 'Carol',  500.00);
