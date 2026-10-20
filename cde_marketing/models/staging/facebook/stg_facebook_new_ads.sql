with source as (
    select * from {{ source('facebook', 'facebook_new_ads') }}
),

renamed as (
    select
        cast(ad_id as string)            as ad_id,
        cast(campaign_id as string)      as campaign_id,
        cast(account_id as string)       as account_id,
        ad_name,
        ad_status,
        cast(ad_updated_at as timestamp) as updated_at
    from source
)

select * from renamed
qualify row_number() over (partition by ad_id order by updated_at desc) = 1

