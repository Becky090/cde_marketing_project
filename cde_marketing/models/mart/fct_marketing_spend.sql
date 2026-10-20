{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['date', 'platform', 'campaign'],
        on_schema_change='append_new_columns'
    )
}}

-- Grain: one row per platform, campaign and day.
-- Incremental: only the last `lookback_days` days (default 3) are recomputed on each run, so
-- late-arriving or restated platform data is picked up. Whole days are always reprocessed,
-- so a (date, platform, campaign) row is never built from partial data.
with ads as (

    select * from {{ ref('int_marketing_ads') }}
    {% if is_incremental() %}
    where report_date >= (
        select {{ dbt.dateadd('day', -1 * var('lookback_days', 3), 'max(date)') }}
        from {{ this }}
    )
    {% endif %}

)

select
    report_date                                     as date,
    platform,
    campaign_name                                   as campaign,
    cast(sum(spend_eur) as decimal(18, 4))          as spend,
    -- blank impressions/clicks in the source are treated as 0
    sum(coalesce(impressions, 0))                   as impressions,
    sum(coalesce(clicks, 0))                        as clicks
from ads
group by report_date, platform, campaign_name
