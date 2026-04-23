//! `pds archive` — promote local-hot capture files to S3.
//!
//! Reads `capture.retention.local_hot_days` from config, walks
//! `${XDG_DATA_HOME}/pds/{diary,telemetry,journal,swarm-reports}`, and uploads
//! files older than the threshold to `s3://<bucket>/<stream>/<relpath>`.
//!
//! First cut shells out to the `aws` CLI — avoids the ~15MB binary bloat of
//! aws-sdk-s3 for a feature most users won't enable. If `capture.s3.enabled`
//! is false, the command is a no-op with a helpful message.

use std::path::Path;
use std::time::{Duration, SystemTime};

use anyhow::{Context, Result};
use clap::Args as ClapArgs;

use crate::config::Config;
use crate::paths;

#[derive(ClapArgs, Debug)]
pub struct Args {
    /// Preview promotions without uploading.
    #[arg(long)]
    pub dry_run: bool,
}

pub fn run(args: Args) -> Result<()> {
    let cfg = Config::load(&paths::config_file()?)?;
    if !cfg.capture.s3.enabled {
        println!("pds archive: capture.s3.enabled=false — nothing to do");
        return Ok(());
    }
    let Some(bucket) = cfg.capture.s3.bucket.as_deref() else {
        anyhow::bail!("capture.s3.bucket not set — run `terraform -chdir=terraform/examples/default apply` to provision one");
    };
    let region = cfg.capture.s3.region.clone();

    let cutoff = SystemTime::now()
        .checked_sub(Duration::from_secs(
            cfg.capture.retention.local_hot_days as u64 * 86_400,
        ))
        .context("retention arithmetic underflow")?;

    let data_root = paths::data_root()?;
    let journal_dir = data_root.join("journal");
    let mut promoted = 0_usize;
    if journal_dir.exists() {
        promoted = walk_and_promote(&journal_dir, bucket, &region, "journal", cutoff, args.dry_run)?;
    }
    if promoted == 0 {
        println!("pds archive: nothing older than {} days", cfg.capture.retention.local_hot_days);
    } else {
        println!("pds archive: promoted {} file(s)", promoted);
    }
    Ok(())
}

fn walk_and_promote(
    dir: &Path,
    bucket: &str,
    region: &str,
    stream: &str,
    cutoff: SystemTime,
    dry_run: bool,
) -> Result<usize> {
    let mut count = 0;
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        let meta = entry.metadata()?;
        if meta.is_dir() {
            count += walk_and_promote(&path, bucket, region, stream, cutoff, dry_run)?;
            continue;
        }
        let modified = meta.modified()?;
        if modified >= cutoff {
            continue;
        }
        let rel = path.strip_prefix(dir).unwrap_or(&path).display();
        let key = format!("{}/{}", stream, rel);
        println!("archive: {} -> s3://{}/{}", path.display(), bucket, key);
        count += 1;
        if dry_run {
            continue;
        }
        upload_and_unlink(&path, bucket, region, &key)?;
    }
    Ok(count)
}

fn upload_and_unlink(path: &Path, bucket: &str, region: &str, key: &str) -> Result<()> {
    let status = std::process::Command::new("aws")
        .args([
            "s3",
            "cp",
            path.to_str().context("non-utf8 path")?,
            &format!("s3://{}/{}", bucket, key),
            "--region",
            region,
            "--storage-class",
            "STANDARD",
            "--only-show-errors",
        ])
        .status()
        .context("running `aws s3 cp` — is the aws CLI installed?")?;
    if !status.success() {
        anyhow::bail!("aws s3 cp failed for {}", path.display());
    }
    std::fs::remove_file(path)
        .with_context(|| format!("removing local copy after upload: {}", path.display()))?;
    Ok(())
}
