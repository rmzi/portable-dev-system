use std::collections::HashMap;

use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

use crate::db::{Db, Node, SearchResult};

/// Which view is active.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum View {
    ModuleTree,
    FunctionList,
    Search,
}

impl View {
    pub fn label(&self) -> &'static str {
        match self {
            View::ModuleTree => "Modules",
            View::FunctionList => "Functions",
            View::Search => "Search",
        }
    }

    pub fn next(&self) -> Self {
        match self {
            View::ModuleTree => View::FunctionList,
            View::FunctionList => View::Search,
            View::Search => View::ModuleTree,
        }
    }

    pub fn prev(&self) -> Self {
        match self {
            View::ModuleTree => View::Search,
            View::FunctionList => View::ModuleTree,
            View::Search => View::FunctionList,
        }
    }
}

/// Input mode for search.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputMode {
    Normal,
    Editing,
}

/// Which pane has focus in two-pane layouts.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Focus {
    List,
    Detail,
}

/// Sort column for function list.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FnSortColumn {
    Name,
    File,
    Lines,
    Callers,
    Callees,
    Exported,
}

impl FnSortColumn {
    pub fn next(&self) -> Self {
        match self {
            FnSortColumn::Name => FnSortColumn::File,
            FnSortColumn::File => FnSortColumn::Lines,
            FnSortColumn::Lines => FnSortColumn::Callers,
            FnSortColumn::Callers => FnSortColumn::Callees,
            FnSortColumn::Callees => FnSortColumn::Exported,
            FnSortColumn::Exported => FnSortColumn::Name,
        }
    }

    pub fn prev(&self) -> Self {
        match self {
            FnSortColumn::Name => FnSortColumn::Exported,
            FnSortColumn::File => FnSortColumn::Name,
            FnSortColumn::Lines => FnSortColumn::File,
            FnSortColumn::Callers => FnSortColumn::Lines,
            FnSortColumn::Callees => FnSortColumn::Callers,
            FnSortColumn::Exported => FnSortColumn::Callees,
        }
    }
}

/// A node in the tree with lazily-loaded children.
#[derive(Debug, Clone)]
pub struct TreeNode {
    pub node: Node,
    pub children: Vec<TreeNode>,
    pub expanded: bool,
    pub loaded: bool,
}

impl TreeNode {
    pub fn new(node: Node) -> Self {
        let expanded = node.label == "Project";
        Self {
            node,
            children: Vec::new(),
            expanded,
            loaded: false,
        }
    }
}

/// Core application state.
pub struct App {
    pub view: View,
    pub should_quit: bool,
    pub project_name: String,
    pub db_path: String,

    // Module Tree state
    pub tree_root: TreeNode,
    pub tree_selected: Vec<usize>,
    pub tree_flat_indices: Vec<Vec<usize>>,
    pub tree_cursor: usize,
    pub tree_focus: Focus,
    pub tree_detail_scroll: u16,

    // Function List state
    pub functions: Vec<Node>,
    pub fn_call_counts: HashMap<i64, (i64, i64)>,
    pub fn_sorted: Vec<usize>,
    pub fn_selected: usize,
    pub fn_sort_col: FnSortColumn,
    pub fn_sort_asc: bool,
    pub fn_focus: Focus,
    pub fn_detail_scroll: u16,

    // Search state
    pub search_input: String,
    pub search_results: Vec<SearchResult>,
    pub search_selected: usize,
    pub search_mode: InputMode,
    pub search_focus: Focus,
    pub search_detail_scroll: u16,

    // Stats
    pub node_count: i64,
    pub edge_count: i64,
}

impl App {
    pub fn new(db: &Db, project_name: &str, db_path: &str) -> Self {
        let root = db.root_node().unwrap_or_else(|_| Node {
            id: 0,
            label: "Project".to_string(),
            name: project_name.to_string(),
            qualified_name: String::new(),
            file_path: String::new(),
            start_line: 0,
            end_line: 0,
            properties: Default::default(),
        });

        let mut tree_root = TreeNode::new(root);
        // Eagerly load root children
        if let Ok(children) = db.children(tree_root.node.id) {
            tree_root.children = children.into_iter().map(TreeNode::new).collect();
            tree_root.loaded = true;
            tree_root.expanded = true;
        }

        // Load functions
        let functions = db.all_functions().unwrap_or_default();
        let fn_ids: Vec<i64> = functions.iter().map(|f| f.id).collect();
        let fn_call_counts = db.batch_call_counts(&fn_ids).unwrap_or_default();
        let fn_sorted: Vec<usize> = (0..functions.len()).collect();

        // Build initial flat index
        let mut tree_flat_indices = Vec::new();
        build_flat_indices(&tree_root, &mut Vec::new(), &mut tree_flat_indices);

        // Get stats
        let label_counts = db.label_counts().unwrap_or_default();
        let node_count: i64 = label_counts.iter().map(|(_, c)| c).sum();
        let edge_type_counts = db.edge_type_counts().unwrap_or_default();
        let edge_count: i64 = edge_type_counts.iter().map(|(_, c)| c).sum();

        let mut app = Self {
            view: View::ModuleTree,
            should_quit: false,
            project_name: project_name.to_string(),
            db_path: db_path.to_string(),

            tree_root,
            tree_selected: vec![0],
            tree_flat_indices,
            tree_cursor: 0,
            tree_focus: Focus::List,
            tree_detail_scroll: 0,

            functions,
            fn_call_counts,
            fn_sorted,
            fn_selected: 0,
            fn_sort_col: FnSortColumn::Name,
            fn_sort_asc: true,
            fn_focus: Focus::List,
            fn_detail_scroll: 0,

            search_input: String::new(),
            search_results: Vec::new(),
            search_selected: 0,
            search_mode: InputMode::Normal,
            search_focus: Focus::List,
            search_detail_scroll: 0,

            node_count,
            edge_count,
        };
        app.sort_functions();
        app
    }

    pub fn handle_key(&mut self, key: KeyEvent, db: &Db) {
        // Global keys
        match key.code {
            KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                self.should_quit = true;
                return;
            }
            KeyCode::Char('q') if self.search_mode != InputMode::Editing => {
                self.should_quit = true;
                return;
            }
            KeyCode::Tab if self.search_mode != InputMode::Editing => {
                self.view = self.view.next();
                return;
            }
            KeyCode::BackTab if self.search_mode != InputMode::Editing => {
                self.view = self.view.prev();
                return;
            }
            _ => {}
        }

        match self.view {
            View::ModuleTree => self.handle_tree_key(key, db),
            View::FunctionList => self.handle_fn_key(key, db),
            View::Search => self.handle_search_key(key, db),
        }
    }

    fn handle_tree_key(&mut self, key: KeyEvent, db: &Db) {
        match self.tree_focus {
            Focus::List => match key.code {
                KeyCode::Down | KeyCode::Char('j') => self.tree_move_down(),
                KeyCode::Up | KeyCode::Char('k') => self.tree_move_up(),
                KeyCode::Enter | KeyCode::Right | KeyCode::Char('l') => self.tree_toggle_expand(db),
                KeyCode::Left | KeyCode::Char('h') => self.tree_collapse_or_parent(),
                KeyCode::Char('L') => {
                    self.tree_focus = Focus::Detail;
                }
                KeyCode::Home | KeyCode::Char('g') => {
                    self.tree_cursor = 0;
                    self.update_tree_selected();
                    self.tree_detail_scroll = 0;
                }
                KeyCode::End | KeyCode::Char('G') => {
                    if !self.tree_flat_indices.is_empty() {
                        self.tree_cursor = self.tree_flat_indices.len() - 1;
                        self.update_tree_selected();
                        self.tree_detail_scroll = 0;
                    }
                }
                _ => {}
            },
            Focus::Detail => match key.code {
                KeyCode::Down | KeyCode::Char('j') => {
                    self.tree_detail_scroll = self.tree_detail_scroll.saturating_add(1);
                }
                KeyCode::Up | KeyCode::Char('k') => {
                    self.tree_detail_scroll = self.tree_detail_scroll.saturating_sub(1);
                }
                KeyCode::Left | KeyCode::Char('h') | KeyCode::Char('H') | KeyCode::Esc => {
                    self.tree_focus = Focus::List;
                }
                _ => {}
            },
        }
    }

    fn handle_fn_key(&mut self, key: KeyEvent, _db: &Db) {
        match self.fn_focus {
            Focus::List => match key.code {
                KeyCode::Down | KeyCode::Char('j') => {
                    if !self.fn_sorted.is_empty() && self.fn_selected < self.fn_sorted.len() - 1 {
                        self.fn_selected += 1;
                        self.fn_detail_scroll = 0;
                    }
                }
                KeyCode::Up | KeyCode::Char('k') => {
                    if self.fn_selected > 0 {
                        self.fn_selected -= 1;
                        self.fn_detail_scroll = 0;
                    }
                }
                KeyCode::Right | KeyCode::Char('l') | KeyCode::Char('L') => {
                    self.fn_focus = Focus::Detail;
                }
                KeyCode::Char('s') | KeyCode::Char('>') => {
                    self.fn_sort_col = self.fn_sort_col.next();
                    self.sort_functions();
                }
                KeyCode::Char('S') | KeyCode::Char('<') => {
                    self.fn_sort_col = self.fn_sort_col.prev();
                    self.sort_functions();
                }
                KeyCode::Char('r') => {
                    self.fn_sort_asc = !self.fn_sort_asc;
                    self.sort_functions();
                }
                KeyCode::Home | KeyCode::Char('g') => {
                    self.fn_selected = 0;
                    self.fn_detail_scroll = 0;
                }
                KeyCode::End | KeyCode::Char('G') => {
                    if !self.fn_sorted.is_empty() {
                        self.fn_selected = self.fn_sorted.len() - 1;
                        self.fn_detail_scroll = 0;
                    }
                }
                _ => {}
            },
            Focus::Detail => match key.code {
                KeyCode::Down | KeyCode::Char('j') => {
                    self.fn_detail_scroll = self.fn_detail_scroll.saturating_add(1);
                }
                KeyCode::Up | KeyCode::Char('k') => {
                    self.fn_detail_scroll = self.fn_detail_scroll.saturating_sub(1);
                }
                KeyCode::Left | KeyCode::Char('h') | KeyCode::Char('H') | KeyCode::Esc => {
                    self.fn_focus = Focus::List;
                }
                _ => {}
            },
        }
    }

    fn handle_search_key(&mut self, key: KeyEvent, db: &Db) {
        match self.search_mode {
            InputMode::Editing => match key.code {
                KeyCode::Enter => {
                    self.search_mode = InputMode::Normal;
                    self.run_search(db);
                }
                KeyCode::Esc => {
                    self.search_mode = InputMode::Normal;
                }
                KeyCode::Char(c) => {
                    self.search_input.push(c);
                    self.run_search(db);
                }
                KeyCode::Backspace => {
                    self.search_input.pop();
                    self.run_search(db);
                }
                _ => {}
            },
            InputMode::Normal => match self.search_focus {
                Focus::List => match key.code {
                    KeyCode::Char('/') | KeyCode::Char('i') => {
                        self.search_mode = InputMode::Editing;
                    }
                    KeyCode::Down | KeyCode::Char('j') => {
                        if !self.search_results.is_empty()
                            && self.search_selected < self.search_results.len() - 1
                        {
                            self.search_selected += 1;
                            self.search_detail_scroll = 0;
                        }
                    }
                    KeyCode::Up | KeyCode::Char('k') => {
                        if self.search_selected > 0 {
                            self.search_selected -= 1;
                            self.search_detail_scroll = 0;
                        }
                    }
                    KeyCode::Right | KeyCode::Char('l') | KeyCode::Char('L') => {
                        self.search_focus = Focus::Detail;
                    }
                    _ => {}
                },
                Focus::Detail => match key.code {
                    KeyCode::Down | KeyCode::Char('j') => {
                        self.search_detail_scroll = self.search_detail_scroll.saturating_add(1);
                    }
                    KeyCode::Up | KeyCode::Char('k') => {
                        self.search_detail_scroll = self.search_detail_scroll.saturating_sub(1);
                    }
                    KeyCode::Left | KeyCode::Char('h') | KeyCode::Char('H') | KeyCode::Esc => {
                        self.search_focus = Focus::List;
                    }
                    _ => {}
                },
            },
        }
    }

    fn tree_move_down(&mut self) {
        if self.tree_cursor < self.tree_flat_indices.len().saturating_sub(1) {
            self.tree_cursor += 1;
            self.update_tree_selected();
            self.tree_detail_scroll = 0;
        }
    }

    fn tree_move_up(&mut self) {
        if self.tree_cursor > 0 {
            self.tree_cursor -= 1;
            self.update_tree_selected();
            self.tree_detail_scroll = 0;
        }
    }

    fn tree_toggle_expand(&mut self, db: &Db) {
        if let Some(path) = self.tree_flat_indices.get(self.tree_cursor).cloned() {
            let node = get_tree_node_mut(&mut self.tree_root, &path);
            if let Some(node) = node {
                if node.node.label == "Folder" || node.node.label == "Project" || node.node.label == "File" {
                    if !node.loaded {
                        if let Ok(children) = db.children(node.node.id) {
                            node.children = children.into_iter().map(TreeNode::new).collect();
                            node.loaded = true;
                        }
                    }
                    node.expanded = !node.expanded;
                    self.rebuild_flat_indices();
                }
            }
        }
    }

    fn tree_collapse_or_parent(&mut self) {
        if let Some(path) = self.tree_flat_indices.get(self.tree_cursor).cloned() {
            let node = get_tree_node(&self.tree_root, &path);
            if let Some(node) = node {
                if node.expanded {
                    // Collapse current node
                    let node = get_tree_node_mut(&mut self.tree_root, &path);
                    if let Some(node) = node {
                        node.expanded = false;
                        self.rebuild_flat_indices();
                    }
                } else if path.len() > 1 {
                    // Move to parent
                    let parent_path = &path[..path.len() - 1];
                    // Find cursor position of parent
                    for (i, p) in self.tree_flat_indices.iter().enumerate() {
                        if p == parent_path {
                            self.tree_cursor = i;
                            self.update_tree_selected();
                            self.tree_detail_scroll = 0;
                            break;
                        }
                    }
                }
            }
        }
    }

    fn update_tree_selected(&mut self) {
        if let Some(path) = self.tree_flat_indices.get(self.tree_cursor) {
            self.tree_selected = path.clone();
        }
    }

    pub fn rebuild_flat_indices(&mut self) {
        self.tree_flat_indices.clear();
        build_flat_indices(&self.tree_root, &mut Vec::new(), &mut self.tree_flat_indices);
        // Clamp cursor
        if self.tree_cursor >= self.tree_flat_indices.len() && !self.tree_flat_indices.is_empty() {
            self.tree_cursor = self.tree_flat_indices.len() - 1;
        }
        self.update_tree_selected();
    }

    fn sort_functions(&mut self) {
        let fns = &self.functions;
        let counts = &self.fn_call_counts;
        let col = self.fn_sort_col;
        let asc = self.fn_sort_asc;

        self.fn_sorted.sort_by(|&a, &b| {
            let cmp = match col {
                FnSortColumn::Name => fns[a].name.to_lowercase().cmp(&fns[b].name.to_lowercase()),
                FnSortColumn::File => fns[a].file_path.cmp(&fns[b].file_path),
                FnSortColumn::Lines => fns[a].properties.lines.cmp(&fns[b].properties.lines),
                FnSortColumn::Callers => {
                    let ca = counts.get(&fns[a].id).map_or(0, |c| c.0);
                    let cb = counts.get(&fns[b].id).map_or(0, |c| c.0);
                    ca.cmp(&cb)
                }
                FnSortColumn::Callees => {
                    let ca = counts.get(&fns[a].id).map_or(0, |c| c.1);
                    let cb = counts.get(&fns[b].id).map_or(0, |c| c.1);
                    ca.cmp(&cb)
                }
                FnSortColumn::Exported => fns[a]
                    .properties
                    .is_exported
                    .cmp(&fns[b].properties.is_exported),
            };
            if asc { cmp } else { cmp.reverse() }
        });
    }

    fn run_search(&mut self, db: &Db) {
        self.search_results = db.search(&self.search_input).unwrap_or_default();
        self.search_selected = 0;
        self.search_detail_scroll = 0;
    }

    /// Get the currently selected tree node.
    pub fn selected_tree_node(&self) -> Option<&TreeNode> {
        if let Some(path) = self.tree_flat_indices.get(self.tree_cursor) {
            get_tree_node(&self.tree_root, path)
        } else {
            None
        }
    }

    /// Get the currently selected function.
    pub fn selected_function(&self) -> Option<&Node> {
        self.fn_sorted
            .get(self.fn_selected)
            .and_then(|&idx| self.functions.get(idx))
    }

    /// Get the currently selected search result.
    pub fn selected_search_result(&self) -> Option<&SearchResult> {
        self.search_results.get(self.search_selected)
    }
}

/// Build a flat list of tree paths for cursor navigation.
fn build_flat_indices(node: &TreeNode, current_path: &mut Vec<usize>, out: &mut Vec<Vec<usize>>) {
    out.push(current_path.clone());
    if node.expanded {
        for (i, child) in node.children.iter().enumerate() {
            current_path.push(i);
            build_flat_indices(child, current_path, out);
            current_path.pop();
        }
    }
}

/// Navigate the tree to get a reference to a node at the given path.
fn get_tree_node<'a>(root: &'a TreeNode, path: &[usize]) -> Option<&'a TreeNode> {
    let mut current = root;
    for &idx in path {
        current = current.children.get(idx)?;
    }
    Some(current)
}

/// Navigate the tree to get a mutable reference to a node at the given path.
fn get_tree_node_mut<'a>(root: &'a mut TreeNode, path: &[usize]) -> Option<&'a mut TreeNode> {
    let mut current = root;
    for &idx in path {
        current = current.children.get_mut(idx)?;
    }
    Some(current)
}
