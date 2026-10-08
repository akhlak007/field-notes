CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE customers (
    id UUID PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id),
    name VARCHAR(255) NOT NULL,
    contact_info TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_customers_user_updated ON customers (user_id, updated_at);
CREATE INDEX idx_customers_user ON customers (user_id);

CREATE TABLE sites (
    id UUID PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id),
    customer_id UUID NOT NULL REFERENCES customers (id),
    site_name VARCHAR(255) NOT NULL,
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_sites_user_updated ON sites (user_id, updated_at);
CREATE INDEX idx_sites_customer ON sites (customer_id);
CREATE INDEX idx_sites_user ON sites (user_id);

CREATE TABLE field_notes (
    id UUID PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id),
    site_id UUID NOT NULL REFERENCES sites (id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    noted_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(32) NOT NULL,
    photo_url TEXT,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT field_notes_status_check CHECK (status IN ('OPEN', 'IN_PROGRESS', 'COMPLETED'))
);
CREATE INDEX idx_notes_user_updated ON field_notes (user_id, updated_at);
CREATE INDEX idx_notes_site ON field_notes (site_id);
CREATE INDEX idx_notes_user ON field_notes (user_id);
