-- Grain: one row per Facebook ad account (latest version only).
with source as (
    select * from {{ source('facebook', 'facebook_account') }}
),

renamed as (
    select
        cast(account_id as string)            as account_id,
        account_name,
        upper(ad_currency_code)               as currency_code,
        cast(account_updated_at as timestamp) as updated_at
    from source
)

select * from renamed
qualify row_number() over (partition by account_id order by updated_at desc) = 1
