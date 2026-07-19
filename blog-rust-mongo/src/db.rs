use mongodb::bson::doc;
use mongodb::error::{Error, ErrorKind, WriteFailure};
use mongodb::options::IndexOptions;
use mongodb::{Client, Collection, IndexModel};

use crate::auth::User;
use crate::posts::Post;

#[derive(Clone)]
pub struct Db {
    pub users: Collection<User>,
    pub posts: Collection<Post>,
}

/// Connects to MongoDB and ensures the indexes the app relies on. Index
/// creation is idempotent, so running it on every startup is safe.
pub async fn connect(url: &str, db_name: &str) -> mongodb::error::Result<Db> {
    let client = Client::with_uri_str(url).await?;
    let database = client.database(db_name);
    let db = Db {
        users: database.collection("users"),
        posts: database.collection("posts"),
    };

    let unique = IndexOptions::builder().unique(true).build();
    db.users
        .create_index(
            IndexModel::builder()
                .keys(doc! { "email": 1 })
                .options(unique.clone())
                .build(),
        )
        .await?;
    db.posts
        .create_index(
            IndexModel::builder()
                .keys(doc! { "slug": 1 })
                .options(unique)
                .build(),
        )
        .await?;
    db.posts
        .create_index(
            IndexModel::builder()
                .keys(doc! { "published": 1, "created_at": -1 })
                .build(),
        )
        .await?;

    Ok(db)
}

/// True when a write hit a unique index (duplicate email or slug).
pub fn is_duplicate_key(err: &Error) -> bool {
    match &*err.kind {
        ErrorKind::Write(WriteFailure::WriteError(write_error)) => write_error.code == 11000,
        ErrorKind::Command(command_error) => command_error.code == 11000,
        _ => false,
    }
}
