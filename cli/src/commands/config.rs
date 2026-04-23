//! `pds config get <key>` / `pds config set <key> <value>` / `pds config path`.
//!
//! Primary consumer: hook scripts. Today they read `${PDS_HEALTH_SERIOUS_MIN:-180}`;
//! after this lands they read `$(pds config get health.serious_min)`. This is
//! the single biggest DX win of having a CLI — config becomes uniformly
//! queryable instead of "check this env var, then this file, then this default."

use anyhow::{Context, Result};
use clap::{Args as ClapArgs, Subcommand};
use serde_yaml::Value;

use crate::paths;

#[derive(ClapArgs, Debug)]
pub struct Args {
    #[command(subcommand)]
    pub action: Action,
}

#[derive(Subcommand, Debug)]
pub enum Action {
    /// Print the path pds expects the config file at.
    Path,
    /// Read a dotted-path value (e.g. `health.serious_min`). Missing key → default from schema.
    Get { key: String },
    /// Print resolved effective config (all defaults filled in) as YAML.
    Show,
}

pub fn run(args: Args) -> Result<()> {
    match args.action {
        Action::Path => {
            println!("{}", paths::config_file()?.display());
        }
        Action::Get { key } => {
            let cfg = crate::config::Config::load(&paths::config_file()?)?;
            let yaml = serde_yaml::to_value(&cfg)?;
            match lookup(&yaml, &key) {
                Some(v) => print_scalar(&v),
                None => anyhow::bail!("key not found: {}", key),
            }
        }
        Action::Show => {
            let cfg = crate::config::Config::load(&paths::config_file()?)?;
            let yaml = serde_yaml::to_string(&cfg).context("serializing resolved config")?;
            print!("{}", yaml);
        }
    }
    Ok(())
}

fn lookup(root: &Value, key: &str) -> Option<Value> {
    let mut current = root.clone();
    for segment in key.split('.') {
        current = match current {
            Value::Mapping(ref map) => map.get(Value::String(segment.to_string()))?.clone(),
            _ => return None,
        };
    }
    Some(current)
}

fn print_scalar(v: &Value) {
    match v {
        Value::String(s) => println!("{}", s),
        Value::Bool(b) => println!("{}", b),
        Value::Number(n) => println!("{}", n),
        Value::Null => {}
        Value::Sequence(seq) => {
            for item in seq {
                print_scalar(item);
            }
        }
        Value::Mapping(_) | Value::Tagged(_) => {
            let s = serde_yaml::to_string(v).unwrap_or_default();
            print!("{}", s);
        }
    }
}
