-- Grain: one row per Snapchat ad per day per country.
with source as (
    select * from {{ source('snapchat', 'snapchat_ads_stat') }}
)

select
    cast(ad_detail_id as string)                                      as ad_id,
    upper(ad_currency_code)                                           as currency_code,
    upper(ad_country)                                                 as country_code,
    cast(ad_date as date)                                             as report_date,
    try_cast(ad_spend as decimal(18, 6))  as spend,
    try_cast(ad_impressions as bigint)   as impressions,
    try_cast(ad_clicks as bigint)        as clicks
from source

