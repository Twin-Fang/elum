-- 추가 크레딧 구매 기록 (소모성 상품). 스토어 거래 id 하나당 한 행 = 멱등 키.
-- 환불되면 status 만 REFUNDED 로 바뀌고 행은 남는다.
create table if not exists ai_credit_purchase (
    id             varchar(255) primary key,
    -- APPLE_IAP | GOOGLE_IAP
    store          varchar(20)   not null,
    -- Apple transactionId · Google orderId
    transaction_id varchar(255)  not null,
    account_id     varchar(255)  not null references ai_credit_account (id),
    member_id      varchar(255),
    product_id     varchar(150)  not null,
    credits        integer       not null,
    -- 이 구매로 만든 적립 묶음(ai_credit_grant)
    grant_id       varchar(255),
    -- GRANTED | REFUNDED
    status         varchar(20)   not null,
    refunded_at    timestamp(6),
    created_at     timestamp(6),
    updated_at     timestamp(6),
    constraint uk_ai_credit_purchase_transaction unique (store, transaction_id)
);

create index if not exists idx_ai_credit_purchase_account on ai_credit_purchase (account_id, created_at);
