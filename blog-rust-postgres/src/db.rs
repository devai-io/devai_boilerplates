use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

/// Connects to Postgres and applies `schema.sql`. The schema only uses
/// `CREATE ... IF NOT EXISTS`, so running it on every startup is safe.
pub async fn connect(url: &str) -> Result<PgPool, sqlx::Error> {
    let pool = PgPoolOptions::new().max_connections(5).connect(url).await?;
    sqlx::raw_sql(include_str!("../schema.sql"))
        .execute(&pool)
        .await?;
    Ok(pool)
}
