mod db;
mod tui;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use std::path::PathBuf;

use db::{discover_databases, Db, Project};

#[derive(Parser)]
#[command(name = "cg", version, about = "Code Graph Browser — explore codebase-memory-mcp indexes")]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,

    /// Project name to open (auto-detected from cwd if omitted)
    #[arg(short, long, global = true)]
    project: Option<String>,

    /// Path to a specific .db file
    #[arg(short, long, global = true)]
    db: Option<PathBuf>,
}

#[derive(Subcommand)]
enum Command {
    /// List all indexed projects with stats
    List,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Some(Command::List) => cmd_list(&cli),
        None => cmd_browse(&cli),
    }
}

/// `cg list` — show all indexed projects
fn cmd_list(cli: &Cli) -> Result<()> {
    if let Some(db_path) = &cli.db {
        return list_single_db(db_path);
    }

    let db_files = discover_databases().context("Failed to discover databases")?;
    if db_files.is_empty() {
        println!("No databases found in ~/.cache/codebase-memory-mcp/");
        println!("Run codebase-memory-mcp to index a project first.");
        return Ok(());
    }

    let mut total_projects = 0;
    for db_path in &db_files {
        if let Err(e) = list_single_db(db_path) {
            eprintln!("  error reading {}: {}", db_path.display(), e);
        } else {
            total_projects += 1;
        }
    }

    if total_projects == 0 {
        println!("Found database files but no indexed projects.");
    }

    Ok(())
}

fn list_single_db(db_path: &PathBuf) -> Result<()> {
    let projects = Db::list_projects(db_path)?;
    for project in &projects {
        let db = Db::open(db_path, &project.name)?;
        let label_counts = db.label_counts().unwrap_or_default();
        let edge_counts = db.edge_type_counts().unwrap_or_default();
        let total_nodes: i64 = label_counts.iter().map(|(_, c)| c).sum();
        let total_edges: i64 = edge_counts.iter().map(|(_, c)| c).sum();

        println!("{}", project.root_path);
        println!(
            "  {} nodes, {} edges  (indexed {})",
            total_nodes, total_edges, project.indexed_at
        );

        // Node breakdown
        let breakdown: Vec<String> = label_counts
            .iter()
            .filter(|(label, _)| label != "Project")
            .map(|(label, count)| format!("{count} {label}"))
            .collect();
        if !breakdown.is_empty() {
            println!("  {}", breakdown.join(", "));
        }

        // DB file size
        if let Ok(meta) = std::fs::metadata(db_path) {
            let size_mb = meta.len() as f64 / (1024.0 * 1024.0);
            println!("  db: {} ({:.1} MB)", db_path.display(), size_mb);
        }

        println!();
    }
    Ok(())
}

/// Default: launch TUI browser
fn cmd_browse(cli: &Cli) -> Result<()> {
    // If explicit db path given, use it
    if let Some(db_path) = &cli.db {
        let projects = Db::list_projects(db_path)?;
        let project = match &cli.project {
            Some(name) => projects
                .iter()
                .find(|p| p.name == *name)
                .with_context(|| format!("Project '{}' not found in {}", name, db_path.display()))?,
            None => projects
                .first()
                .with_context(|| format!("No projects in {}", db_path.display()))?,
        };
        return tui::run(db_path, &project.name);
    }

    // Discover databases
    let db_files = discover_databases().context("Failed to discover databases")?;
    if db_files.is_empty() {
        bail!(
            "No databases found in ~/.cache/codebase-memory-mcp/\n\
             Run codebase-memory-mcp to index a project first.\n\
             Hint: use `cg list` to see indexed projects."
        );
    }

    // Collect all projects from all databases
    let mut all_projects: Vec<(PathBuf, Project)> = Vec::new();
    for db_path in &db_files {
        if let Ok(projects) = Db::list_projects(db_path) {
            for project in projects {
                all_projects.push((db_path.clone(), project));
            }
        }
    }

    if all_projects.is_empty() {
        bail!("Found database files but no indexed projects.");
    }

    // If --project specified, find it
    if let Some(name) = &cli.project {
        let found = all_projects
            .iter()
            .find(|(_, p)| p.name == *name || p.root_path.ends_with(name));
        match found {
            Some((db_path, project)) => return tui::run(db_path, &project.name),
            None => {
                eprintln!("Project '{}' not found. Use `cg list` to see indexed projects.", name);
                bail!("Project not found");
            }
        }
    }

    // Try auto-detect from cwd
    let cwd = std::env::current_dir().context("Failed to get current directory")?;
    let cwd_str = cwd.to_string_lossy();
    if let Some((db_path, project)) = all_projects
        .iter()
        .find(|(_, p)| cwd_str.starts_with(&p.root_path))
    {
        return tui::run(db_path, &project.name);
    }

    // Single project — just use it
    if all_projects.len() == 1 {
        let (db_path, project) = &all_projects[0];
        return tui::run(db_path, &project.name);
    }

    // Multiple projects, no match — show picker
    eprintln!("Multiple projects found. Use --project to select one:\n");
    for (i, (_, project)) in all_projects.iter().enumerate() {
        eprintln!("  {}. {} ({})", i + 1, project.name, project.root_path);
    }
    eprintln!("\nOr run `cg list` for full details.");
    bail!("No project auto-detected from cwd");
}
