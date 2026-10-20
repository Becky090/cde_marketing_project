{{ config(materialized='table') }}

-- Grain: one row per Facebook ad per day.
-- LEFT joins on purpose: a missing dimension must never silently drop spend.
-- Orphans surface as nulls and are caught by tests on int_marketing_ads.
select
    'facebook'                          as platform,
    s.report_date,
    s.ad_id,
    cast(null as string)                as country_code,
    s.account_id,
    a.campaign_id,
    c.campaign_name,
    acc.currency_code,
    s.spend,
    s.impressions,
    s.clicks
from {{ ref('stg_facebook_ads_stats') }} as s
left join {{ ref('stg_facebook_new_ads') }} as a
    on s.ad_id = a.ad_id
left join {{ ref('stg_facebook_campaign') }} as c
    on a.campaign_id = c.campaign_id
left join {{ ref('stg_facebook_accounts') }} as acc
    on s.account_id = acc.account_id