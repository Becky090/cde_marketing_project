-- Grain: one row per Snapchat campaign.
-- The raw table has no updated_at column, so versions cannot be ordered here.
-- Uniqueness is protected by a dbt test instead of a silent dedupe.
with source as (
    select * from {{ source('snapchat', 'snapchat_campaign') }}
)

select
    cast(campaign_id as string)  as campaign_id,
    cast(account_id as string)   as account_id,
    campaign_name
from source
