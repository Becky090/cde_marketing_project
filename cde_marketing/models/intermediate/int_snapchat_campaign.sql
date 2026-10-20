{{ config(materialized='table') }}

-- Grain: one row per Snapchat ad per day per country.
-- Path to the campaign is ad -> ad group -> campaign (Facebook has a direct ad -> campaign link).
-- LEFT joins on purpose: a missing dimension must never silently drop spend.
select
    'snapchat'                          as platform,
    s.report_date,
    s.ad_id,
    s.country_code,
    c.account_id,
    g.campaign_id,
    c.campaign_name,
    s.currency_code,
    s.spend,
    s.impressions,
    s.clicks
from {{ ref('stg_snapchat_ads_stat') }} as s
left join {{ ref('stg_snapchat_new_ads') }} as a
    on s.ad_id = a.ad_id
left join {{ ref('stg_snapchat_adgroup') }} as g
    on a.ad_group_id = g.ad_group_id
left join {{ ref('stg_snapchat_campaign') }} as c
    on g.campaign_id = c.campaign_id
