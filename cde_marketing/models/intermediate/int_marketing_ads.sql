-- Grain: one row per platform, ad, day and country (country is null for Facebook).
-- Both platforms in one shape, with spend converted to the reporting currency (EUR).
with unioned as (
    select * from {{ ref('int_facebook_campaign') }}
    union all
    select * from {{ ref('int_snapchat_campaign') }}
),

rates as (
    select * from {{ ref('currency_rates') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['u.platform', 'u.ad_id', 'u.report_date', 'u.country_code']) }}
                                                    as ad_performance_key,
    u.platform,
    u.report_date,
    u.account_id,
    u.campaign_id,
    u.campaign_name,
    u.ad_id,
    u.country_code,
    u.currency_code,
    u.spend                                         as spend_original,
    cast(u.spend * r.rate_to_eur as decimal(18, 6)) as spend_eur,
    u.impressions,
    u.clicks
from unioned as u
left join rates as r
    on u.currency_code = r.currency_code
