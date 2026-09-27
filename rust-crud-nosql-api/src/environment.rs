use std::convert::Infallible;
use std::sync::Arc;

use mongodb::bson::{DateTime, doc};
use mongodb::options::IndexOptions;
use mongodb::{Client, Collection, IndexModel};
use serde::de::DeserializeOwned;
use warp::{Filter, Rejection};

use crate::articles::models::Article;
use crate::auth::Keys;
use crate::users::models::User;

#[derive(Clone)]
pub struct Environment {
    pub users: Collection<User>,
    pub articles: Collection<Article>,
    pub keys: Arc<Keys>,
}

impl Environment {
    pub async fn from_env() -> Self {
        let mongo_url = std::env::var("MONGO_URL").expect("MONGO_URL must be set");
        let mongo_db = std::env::var("MONGO_DB").unwrap_or_else(|_| "demo".to_string());
        let secret = std::env::var("AUTH_SECRET").expect("AUTH_SECRET must be set");

        let client = Client::with_uri_str(&mongo_url)
            .await
            .expect("invalid MONGO_URL");
        let db = client.database(&mongo_db);
        let env = Self {
            users: db.collection("users"),
            articles: db.collection("articles"),
            keys: Arc::new(Keys::new(secret.as_bytes())),
        };

        // Unique indexes keep emails and article urls unique even under concurrent
        // writes. Creating an index that already exists is a no-op.
        env.users
            .create_index(unique_index("email"))
            .await
            .expect("cannot reach MongoDB");
        env.articles
            .create_index(unique_index("url"))
            .await
            .expect("cannot reach MongoDB");
        env
    }
}

fn unique_index(field: &str) -> IndexModel {
    IndexModel::builder()
        .keys(doc! { field: 1 })
        .options(IndexOptions::builder().unique(true).build())
        .build()
}

pub fn with_env(
    env: Environment,
) -> impl Filter<Extract = (Environment,), Error = Infallible> + Clone {
    warp::any().map(move || env.clone())
}

/// A JSON request body of at most 64 KiB.
pub fn json_body<T: DeserializeOwned + Send>()
-> impl Filter<Extract = (T,), Error = Rejection> + Copy {
    warp::body::content_length_limit(64 * 1024).and(warp::body::json())
}

pub fn rfc3339(date: DateTime) -> String {
    date.try_to_rfc3339_string().unwrap_or_default()
}
