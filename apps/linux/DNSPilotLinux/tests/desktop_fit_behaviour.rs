use dnspilot_linux_shell::desktop::{desktop_layout, MIN_WINDOW_HEIGHT, MIN_WINDOW_WIDTH};

#[test]
fn desktop_layout_preserves_a_scrollable_content_column_at_minimum_and_wide_sizes() {
    let minimum = desktop_layout(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);
    let wide = desktop_layout(1440.0, 900.0);

    assert!(minimum.content_width >= 500.0);
    assert!(minimum.content_is_scrollable);
    assert!(wide.content_width > minimum.content_width);
    assert_eq!(minimum.sidebar_width, wide.sidebar_width);
}
