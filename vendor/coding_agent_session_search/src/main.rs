#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load .env early; ignore if missing.
    dotenvy::dotenv().ok();

    match coding_agent_search::run().await {
        Ok(()) => Ok(()),
        Err(err) => {
            // If the message looks like JSON, output it directly (it's a pre-formatted robot error)
            if err.message.trim().starts_with('{') {
                eprintln!("{}", err.message);
            } else {
                // Otherwise wrap structured error
                let payload = serde_json::json!({
                    "error": {
                        "code": err.code,
                        "kind": err.kind,
                        "message": err.message,
                        "hint": err.hint,
                        "retryable": err.retryable,
                    }
                });
                eprintln!("{payload}");
            }
            std::process::exit(err.code);
        }
    }
}
