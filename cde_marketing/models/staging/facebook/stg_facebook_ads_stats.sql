-- Grain: one row per Facebook ad per day.
with source as (
    select * from {{ source('facebook', 'facebook_ads_stats') }}
)

select
    cast(ad_id as string)                as ad_id,
    cast(account_id as string)           as account_id,
    cast(ad_date as date)                as report_date,
    cast(ad_spend as decimal(18, 6))     as spend,
    cast(ad_impressions as bigint)       as impressions,
    cast(ad_clicks as bigint)            as clicks
from source

