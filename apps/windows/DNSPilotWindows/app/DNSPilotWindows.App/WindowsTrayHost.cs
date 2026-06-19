using DNSPilotWindows.Core;
using System.Runtime.InteropServices;

namespace DNSPilotWindows.App;

internal sealed class WindowsTrayHost : IDisposable
{
    private const int WmTrayIcon = 0x800 + 47;
    private const int WmRButtonUp = 0x0205;
    private const int WmLButtonDblClk = 0x0203;
    private const int NimAdd = 0x00000000;
    private const int NimDelete = 0x00000002;
    private const int NifMessage = 0x00000001;
    private const int NifIcon = 0x00000002;
    private const int NifTip = 0x00000004;
    private const int TpmReturnCmd = 0x0100;
    private const int TpmNonotify = 0x0080;
    private static readonly IntPtr HwndMessage = new(-3);
    private static readonly IntPtr IdiApplication = new(32512);

    private readonly IReadOnlyList<TrayActionDescriptor> _actions;
    private readonly Dictionary<uint, TrayActionKind> _commandMap = new();
    private readonly WndProcDelegate _wndProc;
    private readonly string _className;
    private readonly IntPtr _hwnd;
    private bool _disposed;

    public WindowsTrayHost(IReadOnlyList<TrayActionDescriptor> actions)
    {
        _actions = actions;
        _wndProc = WndProc;
        _className = "DNSPilotTrayWindow-" + Guid.NewGuid().ToString("N");
        RegisterMessageWindowClass();
        _hwnd = CreateWindowEx(
            0,
            _className,
            "DNS Pilot Tray",
            0,
            0,
            0,
            0,
            0,
            HwndMessage,
            IntPtr.Zero,
            IntPtr.Zero,
            IntPtr.Zero);

        AddIcon();
    }

    public event EventHandler<TrayActionKind>? ActionRequested;

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        var data = NotifyIconData.Create(_hwnd);
        Shell_NotifyIcon(NimDelete, ref data);
        if (_hwnd != IntPtr.Zero)
        {
            DestroyWindow(_hwnd);
        }
        UnregisterClass(_className, IntPtr.Zero);
        _disposed = true;
    }

    private void RegisterMessageWindowClass()
    {
        var windowClass = new WindowClass
        {
            lpfnWndProc = Marshal.GetFunctionPointerForDelegate(_wndProc),
            lpszClassName = _className,
        };
        RegisterClass(ref windowClass);
    }

    private void AddIcon()
    {
        var data = NotifyIconData.Create(_hwnd);
        data.uFlags = NifMessage | NifIcon | NifTip;
        data.uCallbackMessage = WmTrayIcon;
        data.hIcon = LoadIcon(IntPtr.Zero, IdiApplication);
        data.szTip = "DNS Pilot";
        Shell_NotifyIcon(NimAdd, ref data);
    }

    private IntPtr WndProc(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam)
    {
        if (message == WmTrayIcon)
        {
            var trayMessage = lParam.ToInt32();
            if (trayMessage == WmLButtonDblClk)
            {
                ActionRequested?.Invoke(this, TrayActionKind.QuickBenchmark);
                return IntPtr.Zero;
            }

            if (trayMessage == WmRButtonUp)
            {
                ShowMenu();
                return IntPtr.Zero;
            }
        }

        return DefWindowProc(hwnd, message, wParam, lParam);
    }

    private void ShowMenu()
    {
        var menu = CreatePopupMenu();
        _commandMap.Clear();

        uint commandId = 100;
        foreach (var action in _actions)
        {
            _commandMap[commandId] = action.Kind;
            AppendMenu(menu, 0, commandId, action.Label);
            commandId++;
        }

        GetCursorPos(out var point);
        SetForegroundWindow(_hwnd);
        var selected = TrackPopupMenu(menu, TpmReturnCmd | TpmNonotify, point.X, point.Y, 0, _hwnd, IntPtr.Zero);
        DestroyMenu(menu);

        if (selected != 0 && _commandMap.TryGetValue((uint)selected, out var kind))
        {
            ActionRequested?.Invoke(this, kind);
        }
    }

    private delegate IntPtr WndProcDelegate(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WindowClass
    {
        public uint style;
        public IntPtr lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public IntPtr hInstance;
        public IntPtr hIcon;
        public IntPtr hCursor;
        public IntPtr hbrBackground;
        public string? lpszMenuName;
        public string lpszClassName;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NotifyIconData
    {
        public int cbSize;
        public IntPtr hWnd;
        public uint uID;
        public int uFlags;
        public int uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;

        public static NotifyIconData Create(IntPtr hwnd)
        {
            return new NotifyIconData
            {
                cbSize = Marshal.SizeOf<NotifyIconData>(),
                hWnd = hwnd,
                uID = 1,
                szTip = "DNS Pilot",
            };
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point
    {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern ushort RegisterClass(ref WindowClass lpWndClass);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool UnregisterClass(string lpClassName, IntPtr hInstance);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateWindowEx(
        int dwExStyle,
        string lpClassName,
        string lpWindowName,
        int dwStyle,
        int x,
        int y,
        int nWidth,
        int nHeight,
        IntPtr hWndParent,
        IntPtr hMenu,
        IntPtr hInstance,
        IntPtr lpParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    private static extern IntPtr DefWindowProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool Shell_NotifyIcon(int dwMessage, ref NotifyIconData lpData);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr CreatePopupMenu();

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool AppendMenu(IntPtr hMenu, uint uFlags, uint uIDNewItem, string lpNewItem);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyMenu(IntPtr hMenu);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetCursorPos(out Point lpPoint);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int TrackPopupMenu(
        IntPtr hMenu,
        int uFlags,
        int x,
        int y,
        int nReserved,
        IntPtr hWnd,
        IntPtr prcRect);
}
