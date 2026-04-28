# ShopFlow E-Commerce Platform — ERD
**Author:** Thilan Buddhika | **Date:** 2026-04-28

> Generate the visual PNG by pasting the Mermaid block below into https://mermaid.live and exporting.

```mermaid
erDiagram
    users {
        int id PK
        varchar email UK
        varchar password_hash
        varchar first_name
        varchar last_name
        varchar phone
        date date_of_birth
        boolean is_active
        boolean is_verified
        varchar role
        timestamp created_at
        timestamp updated_at
    }

    addresses {
        int id PK
        int user_id FK
        varchar type
        varchar full_name
        varchar phone
        varchar address_line1
        varchar address_line2
        varchar city
        varchar state
        varchar postal_code
        varchar country
        boolean is_default
        timestamp created_at
        timestamp updated_at
    }

    categories {
        int id PK
        int parent_id FK
        varchar name
        varchar slug UK
        text description
        varchar image_url
        int sort_order
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    products {
        int id PK
        int category_id FK
        varchar name
        varchar slug UK
        text description
        varchar short_description
        varchar brand
        varchar sku UK
        decimal base_price
        decimal compare_price
        decimal cost_price
        decimal weight
        boolean is_active
        boolean is_featured
        varchar meta_title
        varchar meta_description
        timestamp created_at
        timestamp updated_at
    }

    product_variants {
        int id PK
        int product_id FK
        varchar sku UK
        varchar name
        varchar size
        varchar color
        varchar material
        decimal price
        decimal compare_price
        decimal weight
        varchar image_url
        boolean is_active
        int sort_order
        timestamp created_at
        timestamp updated_at
    }

    inventory {
        int id PK
        int variant_id FK
        int quantity
        int reserved
        int low_stock_threshold
        varchar warehouse_location
        timestamp last_restocked
        timestamp updated_at
    }

    carts {
        int id PK
        int user_id FK
        varchar session_id
        varchar status
        timestamp expires_at
        timestamp created_at
        timestamp updated_at
    }

    cart_items {
        int id PK
        int cart_id FK
        int variant_id FK
        int quantity
        decimal unit_price
        timestamp added_at
        timestamp updated_at
    }

    promotions {
        int id PK
        varchar code UK
        varchar description
        varchar type
        decimal value
        decimal min_order_amount
        decimal max_discount_amount
        int usage_limit
        int usage_count
        int per_user_limit
        timestamp starts_at
        timestamp expires_at
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    orders {
        int id PK
        int user_id FK
        int promotion_id FK
        int shipping_address_id FK
        int billing_address_id FK
        varchar order_number UK
        varchar status
        decimal subtotal
        decimal discount_amount
        decimal shipping_cost
        decimal tax_amount
        decimal total_amount
        char currency
        varchar payment_status
        varchar payment_method
        varchar tracking_number
        text notes
        timestamp shipped_at
        timestamp delivered_at
        timestamp created_at
        timestamp updated_at
    }

    order_items {
        int id PK
        int order_id FK
        int variant_id FK
        int product_id FK
        varchar product_name
        varchar variant_name
        varchar sku
        int quantity
        decimal unit_price
        decimal total_price
        timestamp created_at
    }

    reviews {
        int id PK
        int product_id FK
        int user_id FK
        int order_id FK
        smallint rating
        varchar title
        text body
        boolean is_verified
        boolean is_approved
        int helpful_count
        timestamp created_at
        timestamp updated_at
    }

    wishlists {
        int id PK
        int user_id FK
        int product_id FK
        int variant_id FK
        timestamp added_at
    }

    %% Relationships
    users         ||--o{ addresses       : "has many"
    users         ||--o{ orders          : "places"
    users         ||--o{ reviews         : "writes"
    users         ||--o{ carts           : "owns"
    users         ||--o{ wishlists       : "saves"

    categories    ||--o{ categories      : "parent of"
    categories    ||--o{ products        : "contains"

    products      ||--o{ product_variants: "has variants"
    products      ||--o{ reviews         : "receives"
    products      ||--o{ wishlists       : "saved in"

    product_variants ||--|| inventory    : "tracked by"
    product_variants ||--o{ cart_items   : "in"
    product_variants ||--o{ order_items  : "sold as"
    product_variants ||--o{ wishlists    : "variant of"

    carts         ||--o{ cart_items      : "contains"

    promotions    ||--o{ orders          : "applied to"

    orders        }o--|| addresses       : "ships to"
    orders        }o--|| addresses       : "billed to"
    orders        ||--o{ order_items     : "contains"
    orders        ||--o{ reviews         : "verified by"
```

---

## Table Descriptions

| Table | Purpose | Key Relationships |
|---|---|---|
| `users` | Customer & admin accounts | Root entity — links to orders, reviews, carts |
| `addresses` | Shipping & billing addresses | Belongs to user; referenced by orders |
| `categories` | Hierarchical product taxonomy | Self-references for parent/child; 1 product → 1 category |
| `products` | Master product catalog | Core entity — links to variants, reviews, wishlists |
| `product_variants` | Size/color/material variations | Each variant has exactly 1 inventory row |
| `inventory` | Real-time stock levels per variant | `quantity - reserved = available` |
| `carts` | Shopping sessions (logged-in or guest) | Supports session-based guest carts |
| `cart_items` | Products in a cart | Unique per (cart, variant) |
| `promotions` | Discount codes and rules | Applied to orders at checkout |
| `orders` | Placed customer orders | Links user, addresses, promo |
| `order_items` | Denormalized line items | Stores product/variant snapshot at order time |
| `reviews` | Product ratings and text reviews | One review per user per product (UNIQUE constraint) |
| `wishlists` | Saved products for later | One entry per user per product |

## Design Decisions

- **`order_items` stores denormalized names/SKU** — preserves historical accuracy if product is later edited or deleted
- **`categories` self-references** — supports unlimited hierarchy depth via recursive CTE queries
- **`inventory.reserved`** — tracks items in pending orders to prevent overselling
- **Guest carts via `session_id`** — allows anonymous shopping; merged into user cart on login
- **Partial indexes on `is_active`** — most queries filter active-only; smaller indexes = faster scans
