-- Grain: one row per Snapchat ad group (latest version only).
-- The raw history table contains several versions for some ad groups; joining it
-- directly would multiply spend, so only the most recent version is kept.
with source as (
    select * from {{ source('snapchat', 'snapchat_adgroup') }}
),

renamed as (
    select
        cast(ad_group_id as string)             as ad_group_id,
        cast(campaign_id as string)             as campaign_id,
        ad_group_name,
        cast(ad_group_updated_at as timestamp)  as updated_at
    from source
)

select * from renamed
qualify row_number() over (partition by ad_group_id order by updated_at desc) = 1