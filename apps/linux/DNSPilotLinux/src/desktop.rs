pub const MIN_WINDOW_WIDTH: f32 = 760.0;
pub const MIN_WINDOW_HEIGHT: f32 = 560.0;
pub const DEFAULT_WINDOW_WIDTH: f32 = 1040.0;
pub const DEFAULT_WINDOW_HEIGHT: f32 = 720.0;
pub const SIDEBAR_WIDTH: f32 = 210.0;
const CHROME_WIDTH: f32 = 30.0;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DesktopLayout {
    pub sidebar_width: f32,
    pub content_width: f32,
    pub content_is_scrollable: bool,
}

pub fn desktop_layout(window_width: f32, _window_height: f32) -> DesktopLayout {
    DesktopLayout {
        sidebar_width: SIDEBAR_WIDTH,
        content_width: (window_width - SIDEBAR_WIDTH - CHROME_WIDTH).max(0.0),
        content_is_scrollable: true,
    }
}
