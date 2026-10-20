# Marketing Data Warehouse (dbt + Databricks)

A modular, production-ready dbt project for ingesting, transforming, and unifying cross-platform marketing performance data (**Facebook Ads** and **Snapchat Ads**) into an analytics-ready fact mart on **Databricks Unity Catalog**.

---

## 🏗 Architecture & Data Lineage

```mermaid
flowchart TD
    subgraph Sources["Raw Sources (bronze_production.cdc_staging)"]
        fb_stats["facebook_ads_stats"]
        fb_ads["facebook_new_ads"]
        fb_cam["facebook_campaign"]
        fb_acc["facebook_account"]

        sc_stats["snapchat_ads_stats"]
        sc_ads["snapchat_ads_ad_history"]
        sc_grp["snapchat_ads_adgroup_history"]
        sc_cam["snapchat_ads_campaign_history"]
    end

    subgraph Seeds["Seeds"]
        rates["currency_rates.csv"]
    end

    subgraph Staging["Staging Layer (Views)"]
        stg_fb_stats["stg_facebook_ads_stats"]
        stg_fb_ads["stg_facebook_new_ads"]
        stg_fb_cam["stg_facebook_campaign"]
        stg_fb_acc["stg_facebook_accounts"]

        stg_sc_stats["stg_snapchat_ads_stat"]
        stg_sc_ads["stg_snapchat_new_ads"]
        stg_sc_grp["stg_snapchat_adgroup"]
        stg_sc_cam["stg_snapchat_campaign"]
    end

    subgraph Intermediate["Intermediate Layer (Ephemeral)"]
        int_fb["int_facebook_campaign<br/><i>(Grain: 1 row per FB ad / day)</i>"]
        int_sc["int_snapchat_campaign<br/><i>(Grain: 1 row per Snapchat ad / day / country)</i>"]
        int_ads["int_marketing_ads<br/><i>(Union + Currency Conversion to EUR)</i>"]
    end

    subgraph Mart["Mart Layer (Incremental Table)"]
        fct_spend["fct_marketing_spend<br/><i>(Grain: 1 row per platform / campaign / day)</i>"]
    end

    fb_stats --> stg_fb_stats
    fb_ads --> stg_fb_ads
    fb_cam --> stg_fb_cam
    fb_acc --> stg_fb_acc

    sc_stats --> stg_sc_stats
    sc_ads --> stg_sc_ads
    sc_grp --> stg_sc_grp
    sc_cam --> stg_sc_cam

    stg_fb_stats & stg_fb_ads & stg_fb_cam & stg_fb_acc --> int_fb
    stg_sc_stats & stg_sc_ads & stg_sc_grp & stg_sc_cam --> int_sc

    int_fb & int_sc --> int_ads
    rates --> int_ads

    int_ads --> fct_spend
```

---

## 📁 Project Structure

```text
cde_marketing_project/
├── pyproject.toml                # Python dependencies (dbt-databricks, elementary-data)
├── uv.lock                       # uv lockfile
├── cde_marketing/
│   ├── dbt_project.yml           # Project configurations & model materializations
│   ├── packages.yml              # dbt dependencies (dbt_utils, elementary, dbt_expectations)
│   ├── profiles.yml              # Databricks Unity Catalog connection profile
│   ├── models/
│   │   ├── staging/
│   │   │   ├── _staging.yml      # Schema definitions, documentation & tests
│   │   │   ├── facebook/
│   │   │   │   ├── _facebook__sources.yml
│   │   │   │   ├── stg_facebook_accounts.sql
│   │   │   │   ├── stg_facebook_ads_stats.sql
│   │   │   │   ├── stg_facebook_campaign.sql
│   │   │   │   └── stg_facebook_new_ads.sql
│   │   │   └── snapshat/
│   │   │       ├── _snapchat_sources.yml
│   │   │       ├── stg_snapchat_adgroup.sql
│   │   │       ├── stg_snapchat_ads_stat.sql
│   │   │       ├── stg_snapchat_campaign.sql
│   │   │       └── stg_snapchat_new_ads.sql
│   │   ├── intermediate/
│   │   │   ├── int_facebook_campaign.sql # Ad-level daily performance for Facebook
│   │   │   ├── int_snapchat_campaign.sql # Ad-level daily performance for Snapchat
│   │   │   └── int_marketing_ads.sql     # Unified multi-platform ad performance in EUR
│   │   └── mart/
│   │       └── fct_marketing_spend.sql   # Daily campaign-level spend & performance mart
│   ├── seeds/
│   │   ├── _seed.yml             # Seed documentation & tests
│   │   └── currency_rates.csv    # Static currency conversion rates to EUR
│   └── tests/
│       └── .env.template         # Environment variables template
```

---

## 📐 Data Modeling Layers

### 1. Staging Layer (`models/staging/`)
- **Purpose**: 1-to-1 reflection of raw source tables.
- **Operations**:
  - Cleans and standardizes column naming (e.g. `ad_id`, `report_date`, `spend`, `impressions`, `clicks`).
  - Casts data types safely using `try_cast` to handle raw malformed values (such as `'null'` strings).
  - Deduplicates history tables using `qualify row_number() over (partition by <id> order by updated_at desc) = 1` to ensure only the latest dimension state is preserved.

### 2. Intermediate Layer (`models/intermediate/`)
- **Purpose**: Complex joins, entity stitching, and standardization.
- **Models**:
  - `int_facebook_campaign`: Traverses `ad -> campaign` & `account` dimensions with `LEFT JOIN`s so no spend is dropped.
  - `int_snapchat_campaign`: Traverses `ad -> ad_group -> campaign` hierarchy.
  - `int_marketing_ads`: Unions both platforms into a unified schema, generates a unique surrogate key (`ad_performance_key`), and applies currency conversion rates (`spend_eur = spend * rate_to_eur`).

### 3. Mart Layer (`models/mart/`)
- **Purpose**: Business-facing aggregation for analytics and BI.
- **Model**: `fct_marketing_spend`
  - **Grain**: 1 row per `date`, `platform`, `campaign`.
  - **Strategy**: Incremental table using `merge` on `['date', 'platform', 'campaign']`.
  - **Lookback Window**: Recomputes the last `lookback_days` (default `3` days) on each run via `var('lookback_days', 3)` to capture late-arriving and restated platform metrics.

---

## ⚙️ Setup & Installation

### 1. Environment Requirements
- Python `>= 3.11`
- [`uv`](https://docs.astral.sh/uv/) (recommended) or `pip`

Install dependencies:
```bash
uv sync
```
*(Or `pip install -r pyproject.toml`)*

### 2. Configure Environment Variables
Copy the template and set your Databricks credentials:
```bash
cp cde_marketing/tests/.env.template .env
```

Required variables:
```bash
export DATABRICKS_PAT_TOKEN="<your-databricks-personal-access-token>"
export DEV_HTTP_PATH="<your-databricks-sql-warehouse-http-path>"
export DEV_CATALOG="bronze_production"
export DEV_SCHEMA="cdc_staging"

# Optional overrides:
export BRONZE_CATALOG="bronze_production"
export BRONZE_SCHEMA="cdc_staging"
```

Activate the environment variables:
```bash
source .env
```

---

## 🚀 Running the Project

Navigate into the dbt project folder:
```bash
cd cde_marketing
```

### 1. Install dbt Packages
```bash
dbt deps
```

### 2. Load Seeds (Currency Rates)
```bash
dbt seed
```

### 3. Build Models & Run Tests
Run the entire pipeline (builds seeds, models, and executes tests):
```bash
dbt build
```

Or run targeted commands:
```bash
# Run only staging models
dbt run --select staging

# Run intermediate and marts
dbt run --select intermediate+

# Full refresh of incremental models
dbt run --select fct_marketing_spend --full-refresh

# Run tests
dbt test
```

---

## 🧪 Data Quality & Observability

- **Built-in & dbt-utils tests**:
  - `unique` and `not_null` constraints on primary keys (`ad_id`, `campaign_id`, `ad_group_id`, `account_id`).
  - `dbt_utils.unique_combination_of_columns` to ensure grain uniqueness.
  - `dbt_utils.accepted_range` ensuring non-negative metrics (`spend >= 0`, `impressions >= 0`, `clicks >= 0`).
  - `accepted_values` for currency codes (`['EUR', 'USD']`).
- **Elementary Data Observability**:
  - Monitored by the `elementary` package for automated anomaly detection, schema change tracking, and test reporting.
** Screenshots of Elementary, Dbt docs and databricks view<img width="543" height="823" alt="Screenshot 2026-10-20 at 16 33 02" src="https://github.com/user-attachments/assets/a9a702aa-76b2-4ae0-b982-811628e7d390" />
<img width="1512" height="791" alt="Screenshot 2026-10-20 at 16 32 30" src="https://github.com/user-attachments/assets/a22c929b-feea-42b0-87a9-ad11a345319d" />
<img width="1512" height="791" alt="Screenshot 2026-10-20 at 16 32 09" src="https://github.com/user-attachments/assets/6afeadc2-10e8-4a3e-a95b-7c0d2b925c0e" />

